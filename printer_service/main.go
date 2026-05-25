package main

import (
	"encoding/base64"
	"fmt"
	"net/http"

	"printer-service/printer"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// Enable CORS for Mario POS
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Health check
	r.GET("/status", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "online",
			"system": "Mario Printer Service",
		})
	})

	// Detect connected USB printers
	r.GET("/printers", func(c *gin.Context) {
		devices, err := printer.DetectPrinters()
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, devices)
	})

	// Print raw data (ESC/POS) or PrintJob JSON
	r.POST("/print", func(c *gin.Context) {
		// Try to bind as PrintJob first (this is what the modern frontend sends)
		var job printer.PrintJob
		if err := c.ShouldBindJSON(&job); err == nil && job.Type != "" {
			fmt.Printf("Received PrintJob for %s, type: %s\n", job.Printer.Name, job.Type)
			err = printer.Print(job)
			if err != nil {
				fmt.Printf("Printing failed: %v\n", err)
				c.JSON(500, gin.H{"error": "Printing failed: " + err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"message": "Printed successfully"})
			return
		} else if err != nil {
			fmt.Printf("Failed to bind PrintJob: %v\n", err)
		}

		// Fallback to RawPrintRequest for backward compatibility or direct ESC/POS printing
		var req printer.RawPrintRequest
		if err := c.ShouldBindBodyWithJSON(&req); err == nil && req.PrinterName != "" {
			// Decode base64 data
			data, err := base64.StdEncoding.DecodeString(req.Data)
			if err != nil {
				c.JSON(400, gin.H{"error": "Failed to decode base64 data: " + err.Error()})
				return
			}

			fmt.Printf("Received raw print job for %s, length: %d\n", req.PrinterName, len(data))

			// Get the appropriate printer service based on OS
			svc := printer.GetPrinterService()
			err = svc.Print(req.PrinterName, data)
			if err != nil {
				fmt.Printf("Printing failed: %v\n", err)
				c.JSON(500, gin.H{"error": "Printing failed: " + err.Error()})
				return
			}

			c.JSON(http.StatusOK, gin.H{"message": "Printed successfully"})
			return
		}

		c.JSON(400, gin.H{"error": "Invalid request format. Expected PrintJob or RawPrintRequest JSON."})
	})

	fmt.Println("Mario Printer Service starting on :8085...")
	r.Run(":8085")
}
