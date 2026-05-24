package queue

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"cafe-backend/internal/config"
	"cafe-backend/internal/printer"

	"github.com/google/uuid"
)

// BillData matches the JSON payload structure of enqueued bill data
type BillData struct {
	OrderID       string  `json:"orderId"`
	TableNumber   int     `json:"tableNumber"`
	InvoiceNo     string  `json:"invoiceNo"`
	Subtotal      float64 `json:"subtotal"`
	TaxTotal      float64 `json:"taxTotal"`
	Discount      float64 `json:"discount"`
	Total         float64 `json:"total"`
	PaymentMethod string  `json:"paymentMethod"`
	CustomerName  string  `json:"customerName"`
	GeneratedBy   string  `json:"generatedBy"`
}

// QueueItem represents a row in the bill_queue table
type QueueItem struct {
	ID        string
	StoreID   string
	OrderID   string
	BillData  []byte
	Status    string
	CreatedAt time.Time
}

// StartProcessor initializes and starts the background 2-second ticker for processing bills
func StartProcessor(db *sql.DB, cfg *config.Config) {
	log.Println("[Bill Queue] Background Go processor started (Checking every 2 seconds)")
	
	ticker := time.NewTicker(2 * time.Second)
	go func() {
		for range ticker.C {
			processPendingQueues(db, cfg)
		}
	}()
}

func processPendingQueues(db *sql.DB, cfg *config.Config) {
	// Reject/expire pending requests older than 1 minute
	_, err := db.Exec("UPDATE bill_queue SET status = 'failed', error_message = 'Rejected: Request expired (older than 1 minute)', updated_at = CURRENT_TIMESTAMP WHERE status = 'pending' AND created_at < NOW() - INTERVAL '1 minute'")
	if err != nil {
		log.Printf("[Bill Queue Error] Failed to expire old requests: %v", err)
	}

	// 1. Get all stores that have pending bill requests
	rows, err := db.Query("SELECT DISTINCT store_id FROM bill_queue WHERE status = 'pending'")
	if err != nil {
		log.Printf("[Bill Queue Error] Failed to query pending stores: %v", err)
		return
	}
	defer rows.Close()

	var storeIDs []string
	for rows.Next() {
		var storeID string
		if err := rows.Scan(&storeID); err == nil {
			storeIDs = append(storeIDs, storeID)
		}
	}

	if len(storeIDs) == 0 {
		return
	}

	// 2. Process each store sequentially
	for _, storeID := range storeIDs {
		// Check if a bill is already being generated/processed for this store
		var exists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM bill_queue WHERE store_id = $1 AND status = 'processing')", storeID).Scan(&exists)
		if err != nil {
			log.Printf("[Bill Queue Error] Store status check failed: %v", err)
			continue
		}

		if exists {
			// Skip store if an active bill is processing
			continue
		}

		// Fetch the oldest pending request for this store
		var item QueueItem
		err = db.QueryRow(
			"SELECT id, store_id, order_id, bill_data, status, created_at FROM bill_queue WHERE store_id = $1 AND status = 'pending' ORDER BY created_at ASC LIMIT 1",
			storeID,
		).Scan(&item.ID, &item.StoreID, &item.OrderID, &item.BillData, &item.Status, &item.CreatedAt)

		if err != nil {
			if err != sql.ErrNoRows {
				log.Printf("[Bill Queue Error] Failed to fetch next queue item: %v", err)
			}
			continue
		}

		// Process the queue item in a separate goroutine
		go func(qItem QueueItem) {
			if err := handleQueueItem(db, cfg, qItem); err != nil {
				log.Printf("[Bill Queue Error] Failed to process queue item %s: %v", qItem.ID, err)
			}
		}(item)
	}
}

func handleQueueItem(db *sql.DB, cfg *config.Config, item QueueItem) error {
	ctx := context.Background()

	// 1. Mark status as processing
	_, err := db.ExecContext(ctx, "UPDATE bill_queue SET status = 'processing', updated_at = CURRENT_TIMESTAMP WHERE id = $1", item.ID)
	if err != nil {
		return fmt.Errorf("failed to mark queue item as processing: %w", err)
	}
	log.Printf("[Bill Queue] Processing item %s for store %s", item.ID, item.StoreID)

	// 2. Parse bill data
	var data BillData
	if err := json.Unmarshal(item.BillData, &data); err != nil {
		markFailed(db, item.ID, "JSON parse failure: "+err.Error())
		return fmt.Errorf("JSON unmarshal error: %w", err)
	}

	// 3. Start a database transaction to generate the bill and complete the order
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		markFailed(db, item.ID, "Transaction creation failed: "+err.Error())
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// 4. Create the bill
	billID := uuid.New().String()
	_, err = tx.ExecContext(ctx,
		`INSERT INTO bills (id, store_id, order_id, table_number, invoice_no, subtotal, tax_total, discount, total, payment_method, customer_name, generated_by)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		billID, item.StoreID, item.OrderID, data.TableNumber, data.InvoiceNo, data.Subtotal, data.TaxTotal, data.Discount, data.Total, data.PaymentMethod, data.CustomerName, data.GeneratedBy,
	)
	if err != nil {
		markFailed(db, item.ID, "Bill DB insert failed: "+err.Error())
		return fmt.Errorf("failed to create bill: %w", err)
	}

	// 5. Complete the order
	_, err = tx.ExecContext(ctx,
		"UPDATE orders SET status = 'completed', payment_method = $1, payment_status = 'paid', updated_at = CURRENT_TIMESTAMP WHERE id = $2",
		data.PaymentMethod, item.OrderID,
	)
	if err != nil {
		markFailed(db, item.ID, "Order complete DB update failed: "+err.Error())
		return fmt.Errorf("failed to complete order: %w", err)
	}

	// Commit database transaction
	if err := tx.Commit(); err != nil {
		markFailed(db, item.ID, "Transaction commit failed: "+err.Error())
		return fmt.Errorf("transaction commit failed: %w", err)
	}

	// 6. Standalone Bill Printing Logic (completely separate from main print endpoints)
	err = printQueueInvoice(db, cfg, item.StoreID, item.OrderID, data.InvoiceNo, data.CustomerName, data.PaymentMethod)
	if err != nil {
		markFailed(db, item.ID, "Printing failed: "+err.Error())
		return fmt.Errorf("printing error: %w", err)
	}

	// 7. Mark queue item as completed
	_, err = db.ExecContext(ctx, "UPDATE bill_queue SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = $1", item.ID)
	if err != nil {
		log.Printf("[Bill Queue Warning] Failed to update queue status to completed: %v", err)
	}

	log.Printf("[Bill Queue] Successfully completed queue item %s", item.ID)
	return nil
}

func markFailed(db *sql.DB, id string, errMsg string) {
	_, err := db.Exec("UPDATE bill_queue SET status = 'failed', error_message = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", errMsg, id)
	if err != nil {
		log.Printf("[Bill Queue Error] Failed to update queue status to failed: %v", err)
	}
}

// printQueueInvoice implements standalone printing logic using built-in printer service
func printQueueInvoice(db *sql.DB, cfg *config.Config, storeID string, orderID string, invoiceNo string, customerName string, paymentMethod string) error {
	ctx := context.Background()

	// 1. Fetch store config
	var store struct {
		Name             string
		Branch           string
		Location         string
		GSTIN            string
		FSSAINo          string
		Phone            string
		PrinterName      string
		PrinterVendorID  string
		PrinterProductID string
		InvoiceSize      string
	}

	err := db.QueryRowContext(ctx,
		"SELECT name, COALESCE(branch, ''), COALESCE(location, ''), COALESCE(gstin, ''), COALESCE(fssai_no, ''), COALESCE(phone, ''), COALESCE(printer_name, ''), COALESCE(printer_vendor_id, ''), COALESCE(printer_product_id, ''), COALESCE(invoice_size, '3inch') FROM stores WHERE id = $1",
		storeID,
	).Scan(&store.Name, &store.Branch, &store.Location, &store.GSTIN, &store.FSSAINo, &store.Phone, &store.PrinterName, &store.PrinterVendorID, &store.PrinterProductID, &store.InvoiceSize)

	if err != nil {
		return fmt.Errorf("failed to fetch store: %w", err)
	}

	// 2. Fetch order items
	rows, err := db.QueryContext(ctx,
		`SELECT oi.quantity, oi.unit_price, oi.tax_percent, i.name, COALESCE(i.description, '')
		 FROM order_items oi
		 JOIN items i ON oi.item_id = i.id
		 WHERE oi.order_id = $1`,
		orderID,
	)
	if err != nil {
		return fmt.Errorf("failed to fetch order items: %w", err)
	}
	defer rows.Close()

	type PrintItem struct {
		Name       string  `json:"name"`
		HSN        string  `json:"hsn"`
		Qty        int     `json:"qty"`
		Unit       string  `json:"unit"`
		Rate       float64 `json:"rate"`
		TaxPercent float64 `json:"tax_percent"`
		Amount     float64 `json:"amount"`
	}

	var printItems []PrintItem
	taxable := 0.0
	cgst := 0.0
	sgst := 0.0

	for rows.Next() {
		var qty int
		var unitPrice, taxPercent float64
		var name, desc string

		if err := rows.Scan(&qty, &unitPrice, &taxPercent, &name, &desc); err != nil {
			return fmt.Errorf("failed to scan item: %w", err)
		}

		amount := unitPrice * float64(qty)
		taxable += amount
		cgst += (amount * taxPercent / 100.0 / 2.0)
		sgst += (amount * taxPercent / 100.0 / 2.0)

		printItems = append(printItems, PrintItem{
			Name:       name,
			HSN:        desc,
			Qty:        qty,
			Unit:       "PCS",
			Rate:       unitPrice,
			TaxPercent: taxPercent,
			Amount:     amount,
		})
	}

	grandTotal := taxable + cgst + sgst

	if customerName == "" {
		customerName = "Walk-in Customer"
	}
	if paymentMethod == "" {
		paymentMethod = "cash"
	}

	// 3. Assemble PrintJob matching the thermal printer specification
	printerName := store.PrinterName
	if printerName == "" {
		printerName = "Thermal Printer"
	}
	vendorID := store.PrinterVendorID
	if vendorID == "" {
		vendorID = "0x0fe6"
	}
	productID := store.PrinterProductID
	if productID == "" {
		productID = "0x811e"
	}
	paperWidth := store.InvoiceSize
	if paperWidth == "" {
		paperWidth = "3inch"
	}

	printJob := map[string]interface{}{
		"type": "invoice",
		"printer": map[string]interface{}{
			"type":        "usb",
			"name":        printerName,
			"vendor_id":   vendorID,
			"product_id":  productID,
			"paper_width": paperWidth,
		},
		"invoice": map[string]interface{}{
			"store": map[string]interface{}{
				"name":         store.Name,
				"branch":       store.Branch,
				"location":     store.Location,
				"gst_number":   store.GSTIN,
				"fssai_lic_no": store.FSSAINo,
				"phone":        store.Phone,
				"address":      store.Location,
			},
			"customer": map[string]interface{}{
				"name":   customerName,
				"mobile": "",
			},
			"invoice_no": invoiceNo,
			"bill_no":    invoiceNo,
			"date":       time.Now().Format("02-01-2006 15:04"),
			"items":      printItems,
			"summary": map[string]interface{}{
				"sub_total":   taxable,
				"discount":    0.0,
				"taxable":     taxable,
				"cgst":        cgst,
				"sgst":        sgst,
				"grand_total": grandTotal,
			},
			"payment": map[string]interface{}{
				"cash":    ternary(paymentMethod == "cash", grandTotal, 0.0),
				"card":    ternary(paymentMethod == "card", grandTotal, 0.0),
				"upi":     ternary(paymentMethod == "upi", grandTotal, 0.0),
				"balance": 0.0,
			},
			"payment_mode": paymentMethod,
			"dr_ref":       "",
			"footer": []string{
				"Thank You Visit Again",
			},
		},
	}

	// 4. Marshal and send to built-in printer service
	payloadBytes, err := json.Marshal(printJob)
	if err != nil {
		return fmt.Errorf("failed to marshal print job payload: %w", err)
	}

	var job printer.PrintJob
	if err := json.Unmarshal(payloadBytes, &job); err != nil {
		return fmt.Errorf("failed to unmarshal to printer.PrintJob: %w", err)
	}

	// Run printing in background with timeout
	go func() {
		printCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := printer.Print(job); err != nil {
			log.Printf("[Bill Queue Error] Direct printing failed: %v", err)
			return
		}

		// 5. Update invoice printed flag in database
		_, err := db.ExecContext(printCtx, "UPDATE bills SET is_printed = true WHERE order_id = $1", orderID)
		if err != nil {
			log.Printf("[Bill Queue Warning] Failed to mark bill as printed in DB: %v", err)
		}
	}()

	return nil
}

func ternary(cond bool, tVal, fVal float64) float64 {
	if cond {
		return tVal
	}
	return fVal
}
