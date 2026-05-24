# Printer Service

A cross-platform thermal printer service for cafe/restaurant POS systems.

## Features

- **Multi-OS Support:**
  - Windows: Native Winspool API printing
  - macOS: CUPS (lp command) + direct USB fallback
  - Linux: CUPS (lp command) + direct USB fallback

- **Print Types:**
  - **Invoice:** Full retail invoice with GST, FSSAI, items table
  - **KOT:** Kitchen Order Ticket for kitchen printing
  - **Raw ESC/POS:** Direct byte printing for custom formats

- **Paper Widths:** 2-inch (58mm) and 3-inch (80mm) support

- **Printer Detection:**
  - USB thermal printers
  - System printer queues (CUPS/Winspool)

## API Endpoints

### GET /status
Health check endpoint.

```json
{
  "status": "online",
  "system": "Mario Printer Service"
}
```

### GET /printers
List available printers.

```json
[
  {
    "name": "USB Thermal Printer",
    "type": "USB",
    "vendor_id": "0x0fe6",
    "product_id": "0x811e"
  }
]
```

### POST /print
Print invoice or KOT.

**Request Body (Invoice):**
```json
{
  "type": "invoice",
  "printer": {
    "type": "usb",
    "name": "USB Printer",
    "paper_width": "3inch"
  },
  "invoice": {
    "store": {
      "name": "My Cafe",
      "branch": "Main Branch",
      "location": "123 Street",
      "gst_number": "32AAIFJ6501F1ZS",
      "fssai_lic_no": "12345678901234",
      "phone": "9876543210"
    },
    "customer": {
      "name": "John Doe",
      "mobile": "9876543210"
    },
    "invoice_no": "INV-001",
    "bill_no": "BILL-001",
    "date": "2025-05-22 14:30",
    "payment_mode": "Cash",
    "items": [
      {
        "name": "Coffee",
        "qty": 2,
        "rate": 50.00,
        "amount": 100.00
      }
    ],
    "summary": {
      "sub_total": 100.00,
      "cgst": 9.00,
      "sgst": 9.00,
      "grand_total": 118.00
    },
    "footer": ["Thank you!", "Visit again!"]
  }
}
```

**Request Body (KOT):**
```json
{
  "type": "kot",
  "printer": {
    "type": "usb",
    "name": "Kitchen Printer",
    "paper_width": "3inch"
  },
  "kot": {
    "order_id": 123,
    "table_number": "T-5",
    "date": "2025-05-22 14:30",
    "items": [
      {"name": "Burger", "qty": 1}
    ],
    "notes": "No onions",
    "order_type": "DINE_IN"
  }
}
```

**Request Body (Raw ESC/POS):**
```json
{
  "printerName": "USB Printer",
  "data": "Base64EncodedBytes..."
}
```

## Running

```bash
# Development
go run .

# Build
./printer-service

# Windows
./printer-service.exe
```

Service runs on port `:8085`.

## Finding Printer IDs

### macOS/Linux
```bash
# USB devices
lsusb

# System printers
lpstat -a
```

### Windows
```powershell
# PowerShell
Get-Printer | Select-Object Name, PortName
```

## Environment Variables

- `PRINTER_SERVICE_URL` - URL for backend to connect (default: `http://localhost:8085`)
