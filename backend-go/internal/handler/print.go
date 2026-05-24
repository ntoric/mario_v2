package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"cafe-backend/internal/middleware"
	"cafe-backend/internal/models"
	"cafe-backend/internal/printer"
)

// PrintInvoice handles POST /api/print/invoice
func (h *Handler) PrintInvoice(w http.ResponseWriter, r *http.Request) {
	var req models.PrintInvoiceRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	// 1. Fetch order details
	order, err := h.Repo.Order.GetByID(r.Context(), req.OrderID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if order == nil {
		h.writeError(w, http.StatusNotFound, "Order not found")
		return
	}

	// 2. Fetch store details
	store, err := h.Repo.Store.GetByID(r.Context(), order.StoreID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "Failed to load store: "+err.Error())
		return
	}
	if store == nil {
		h.writeError(w, http.StatusNotFound, "Store not found")
		return
	}

	// 3. Format items
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

	for _, item := range order.Items {
		amount := item.UnitPrice * float64(item.Quantity)
		taxable += amount
		cgst += (amount * item.TaxPercent / 100.0 / 2.0)
		sgst += (amount * item.TaxPercent / 100.0 / 2.0)

		printItems = append(printItems, PrintItem{
			Name:       item.Item.Name,
			HSN:        item.Item.Description, // Fallback or standard HSN Code
			Qty:        item.Quantity,
			Unit:       "PCS",
			Rate:       item.UnitPrice,
			TaxPercent: item.TaxPercent,
			Amount:     amount,
		})
	}

	grandTotal := taxable + cgst + sgst

	invoiceNo := req.InvoiceNo
	if invoiceNo == "" {
		invoiceNo = fmt.Sprintf("INV-%d", time.Now().UnixMilli())
	}

	now := time.Now()
	dateStr := now.Format("02-01-2006 15:04")

	customerName := req.CustomerName
	if customerName == "" {
		customerName = "Walk-in Customer"
	}

	paymentMethod := req.PaymentMethod
	if paymentMethod == "" {
		paymentMethod = "cash"
	}

	// 4. Construct Printer Configuration
	pConfig := req.PrinterConfig
	if pConfig == nil {
		pConfig = &models.PrintJobPrinterConfig{
			Type:       "usb",
			Name:       store.PrinterName,
			VendorID:   store.PrinterVendorID,
			ProductID:  store.PrinterProductID,
			PaperWidth: store.InvoiceSize,
		}
	}
	if pConfig.Name == "" {
		pConfig.Name = "Thermal Printer"
	}
	if pConfig.VendorID == "" {
		pConfig.VendorID = "0x0fe6"
	}
	if pConfig.ProductID == "" {
		pConfig.ProductID = "0x811e"
	}
	if pConfig.PaperWidth == "" {
		pConfig.PaperWidth = "3inch"
	}

	// Build nested print job payload matching Express print.js
	printJob := map[string]interface{}{
		"type":    "invoice",
		"printer": pConfig,
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
			"date":       dateStr,
			"items":      printItems,
			"summary": map[string]interface{}{
				"sub_total":   taxable,
				"discount":    0,
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

	// Add QR Code if UPI ID is present
	if req.UPIID != "" {
		qrVal := fmt.Sprintf("upi://pay?pa=%s&pn=%s&am=%.2f", req.UPIID, url.QueryEscape(store.Name), grandTotal)
		printJob["invoice"].(map[string]interface{})["qr"] = map[string]interface{}{
			"description": "Scan to Pay via UPI",
			"value":       qrVal,
			"size":        8,
		}
	}

	payloadBytes, err := json.Marshal(printJob)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "Failed to marshal print job: "+err.Error())
		return
	}

	var job printer.PrintJob
	if err := json.Unmarshal(payloadBytes, &job); err != nil {
		fmt.Printf("[Printer Service Error] Failed to unmarshal to printer.PrintJob: %v\n", err)
		h.writeError(w, http.StatusInternalServerError, "Failed to parse print job: "+err.Error())
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		err = printer.Print(job)
		if err != nil {
			fmt.Printf("[Printer Service Error] Direct printing failed: %v\n", err)
			return
		}

		// 6. Mark bill as printed
		_ = h.Repo.Bill.MarkAsPrintedByOrderID(ctx, req.OrderID)
	}()

	h.writeJSON(w, http.StatusOK, map[string]interface{}{"success": true, "message": "Printed successfully"})
}

// PrintKOT handles POST /api/print/kot
func (h *Handler) PrintKOT(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		h.writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req models.PrintKOTRequest
	if err := h.readJSON(r, &req); err != nil {
		h.writeError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	// 1. Fetch order details
	order, err := h.Repo.Order.GetByID(r.Context(), req.OrderID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if order == nil {
		h.writeError(w, http.StatusNotFound, "Order not found")
		return
	}

	// 2. Fetch store details
	store, err := h.Repo.Store.GetByID(r.Context(), order.StoreID)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "Failed to load store: "+err.Error())
		return
	}
	if store == nil {
		h.writeError(w, http.StatusNotFound, "Store not found")
		return
	}

	// 3. Format items
	type KOTItem struct {
		Name   string  `json:"name"`
		Qty    int     `json:"qty"`
		Amount float64 `json:"amount"`
	}

	var kotItems []KOTItem
	for _, item := range order.Items {
		kotItems = append(kotItems, KOTItem{
			Name:   item.Item.Name,
			Qty:    item.Quantity,
			Amount: item.UnitPrice * float64(item.Quantity),
		})
	}

	now := time.Now()
	dateStr := now.Format("02-01-2006 15:04")

	waiterName := claims.Username
	if waiterName == "" {
		waiterName = "Staff"
	}

	// 4. Construct Printer Configuration
	pConfig := req.PrinterConfig
	if pConfig == nil {
		pConfig = &models.PrintJobPrinterConfig{
			Type:       "usb",
			Name:       store.PrinterName,
			VendorID:   store.PrinterVendorID,
			ProductID:  store.PrinterProductID,
			PaperWidth: store.InvoiceSize,
		}
	}
	if pConfig.Name == "" {
		pConfig.Name = "Thermal Printer"
	}
	if pConfig.VendorID == "" {
		pConfig.VendorID = "0x0fe6"
	}
	if pConfig.ProductID == "" {
		pConfig.ProductID = "0x811e"
	}
	if pConfig.PaperWidth == "" {
		pConfig.PaperWidth = "3inch"
	}

	// Build KOT payload
	printJob := map[string]interface{}{
		"type":    "kot",
		"printer": pConfig,
		"kot": map[string]interface{}{
			"order_id":        parseOrderIDToUint(order.ID),
			"table_number":    strconv.Itoa(order.TableNumber),
			"waiter_name":     waiterName,
			"date":            dateStr,
			"items":           kotItems,
			"notes":           "",
			"order_type":      "DINE_IN",
			"customer_name":   "Walk-in Customer",
			"customer_mobile": "",
		},
	}

	payloadBytes, err := json.Marshal(printJob)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "Failed to marshal KOT print job: "+err.Error())
		return
	}

	var job printer.PrintJob
	if err := json.Unmarshal(payloadBytes, &job); err != nil {
		fmt.Printf("[Printer Service Error] Failed to unmarshal to printer.PrintJob: %v\n", err)
		h.writeError(w, http.StatusInternalServerError, "Failed to parse KOT print job: "+err.Error())
		return
	}

	go func() {
		err = printer.Print(job)
		if err != nil {
			fmt.Printf("[Printer Service Error] Direct KOT printing failed: %v\n", err)
			return
		}
	}()

	h.writeJSON(w, http.StatusOK, map[string]interface{}{"success": true, "message": "KOT printed successfully"})
}

// GetPrinters handles GET /api/print/printers
func (h *Handler) GetPrinters(w http.ResponseWriter, r *http.Request) {
	devices, err := printer.DetectPrinters()
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "Failed to detect printers: "+err.Error())
		return
	}

	h.writeJSON(w, http.StatusOK, devices)
}

func ternary(cond bool, tVal, fVal float64) float64 {
	if cond {
		return tVal
	}
	return fVal
}

func parseOrderIDToUint(orderID string) uint {
	var val uint = 0
	parsedAny := false
	for i := 0; i < len(orderID); i++ {
		c := orderID[i]
		if c >= '0' && c <= '9' {
			val = val*10 + uint(c-'0')
			parsedAny = true
		} else {
			if parsedAny {
				break
			}
			return hashUUIDToUint(orderID)
		}
	}
	if !parsedAny {
		return hashUUIDToUint(orderID)
	}
	return val
}

func hashUUIDToUint(s string) uint {
	var h uint = 0
	for i := 0; i < len(s); i++ {
		h = h*31 + uint(s[i])
	}
	return h % 100000
}
