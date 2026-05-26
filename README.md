# Cafe Manager - Multi-Store Order Management System

A complete desktop application for managing cafe orders across multiple stores. Built with React, Express, PostgreSQL, and Electron for a native desktop experience.

## Features

- **Multi-Store Support**: Manage multiple cafe locations from a single dashboard
- **Role-Based Access Control**: 4 user roles - Super Admin, Business Owner, Business Admin, and Staff
- **Table Management**: Visual table layout with real-time order status
- **Menu Management**: Categories and items with tax configuration
- **Order Management**: Place orders, modify existing orders, generate bills
- **Store-Specific Configuration**: GSTIN, FSSAI, printer settings per store
- **Printer Integration**: Built-in thermal printer support via Go printer service
- **Desktop Application**: Native feel with Electron

## Technology Stack

- **Frontend**: React 18, TypeScript, Zustand (state management), React Router
- **Backend**: Node.js, Express, PostgreSQL
- **Desktop**: Electron
- **Printer Service**: Go (Golang)
- **Theme**: Metronics - Dark Orange (#ff6b35) & White

## Quick Start

### Prerequisites

- Node.js 18+
- PostgreSQL 14+
- Go 1.21+ (for printer service)

### Installation

1. **Clone and install dependencies:**
```bash
# Install frontend dependencies
npm install

# Install backend dependencies
cd backend && npm install && cd ..
```

2. **Set up environment variables:**
```bash
cp backend/.env.example backend/.env
```

Edit `backend/.env` with your configuration:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=cafe_db
DB_USER=postgres
DB_PASSWORD=yourpassword

JWT_SECRET=your-super-secret-key
SUPERADMIN_USERNAME=superadmin
SUPERADMIN_PASSWORD=superadmin123
```

3. **Start PostgreSQL and create database:**
```bash
createdb cafe_db
```

4. **Build and run:**

Development mode:
```bash
# Terminal 1 - Backend
cd backend && npm run dev

# Terminal 2 - Frontend
npm run dev

# Terminal 3 - Printer Service (optional)
cd mario-printer && go run main.go
```

Desktop app:
```bash
npm run electron:dev
```

### Building for Production

1. **Build the backend:**
```bash
cd backend && npm run build
```

2. **Build the printer service:**
```bash
cd mario-printer
go build -o mario-printer main.go
# On Windows: go build -o mario-printer.exe main.go
# On Mac: go build -o mario-printer_mac main.go
# On Linux: go build -o mario-printer_linux main.go
```

3. **Build the Electron app:**
```bash
npm run electron:build
```

This will create installers in the `release/` directory.

## Docker Deployment

```bash
docker-compose up -d
```

This will start:
- Frontend (Nginx on port 80)
- Backend API (port 3001)
- PostgreSQL (port 5432)
- Printer Service (port 8085)

## User Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| **Super Admin** | Full system access | Manage all users, stores, settings |
| **Business Owner** | Manage assigned stores | Manage stores, users, view reports |
| **Business Admin** | Store administrator | Manage single store operations |
| **Staff** | Regular employee | Place orders, view items |

## Default Credentials

- **Username**: `superadmin`
- **Password**: `superadmin123` (or from env: `SUPERADMIN_PASSWORD`)

The superadmin is automatically created on first startup if it doesn't exist.

## Store Configuration

Each store can be configured with:
- Store name and branch
- Location address
- GSTIN (tax number)
- FSSAI Number (food license)
- Contact phone
- Printer settings (Vendor ID, Product ID)
- Invoice size (2 inch / 3 inch)

## Printer Integration

The application includes a Go-based printer service that:
- Connects to USB thermal printers
- Supports ESC/POS commands
- Prints invoices with store branding
- Kitchen display system support

Default printer configuration:
- Vendor ID: `0x0fe6` (NYEAR)
- Product ID: `0x811e` (58mm printer)

To find your printer's VID/PID:
```bash
# macOS
system_profiler SPUSBDataType

# Linux
lsusb

# Windows (PowerShell)
Get-PnpDevice -Class USB | Where-Object { $_.FriendlyName -like "*printer*" }
```

## API Endpoints

### Auth
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Stores
- `GET /api/stores` - List stores
- `POST /api/stores` - Create store
- `PUT /api/stores/:id` - Update store
- `POST /api/stores/switch` - Switch current store

### Users
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `PUT /api/users/:id` - Update user
- `POST /api/users/:id/change-password` - Change password

### Categories & Items
- `GET /api/categories` - List categories
- `POST /api/categories` - Create category
- `GET /api/items` - List items
- `POST /api/items` - Create item

### Tables & Orders
- `GET /api/tables` - List tables
- `GET /api/orders` - List orders
- `POST /api/orders` - Create order
- `PATCH /api/orders/:id/complete` - Complete order
- `GET /api/bills` - List bills
- `POST /api/bills` - Create bill

### Print
- `POST /api/print/invoice` - Print invoice
- `GET /api/print/printers` - List printers

## Project Structure

```
cafe-order-management/
├── src/                    # React frontend
│   ├── components/         # UI components
│   ├── stores/            # Zustand stores
│   ├── services/          # API services
│   └── types/             # TypeScript types
├── backend/               # Express backend
│   └── src/
│       ├── db/            # Database setup
│       ├── middleware/    # Auth middleware
│       └── routes/        # API routes
├── mario-printer/         # Go printer service
│   ├── main.go           # Printer service code
│   └── postman_collection.json
├── electron/              # Electron main process
│   ├── main.js           # Main process
│   └── preload.js        # Preload script
└── docker-compose.yml     # Docker orchestration
```

## Development Commands

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Run Electron in development
npm run electron:dev

# Build Electron app
npm run electron:build

# Build and package Electron (unpacked)
npm run electron:pack
```

## License

MIT License
