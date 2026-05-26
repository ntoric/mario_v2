# Cafe Manager POS - Deployment Guide

This guide covers different strategies for deploying your Cafe Manager POS application as a native installable app using Electron.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Deployment Options](#deployment-options)
   - [Option 1: Standalone Mode (Everything Bundled)](#option-1-standalone-mode-everything-bundled)
   - [Option 2: Client-Server Mode (Backend Hosted)](#option-2-client-server-mode-backend-hosted)
   - [Option 3: Hybrid Mode (Bundled Backend + Remote DB)](#option-3-hybrid-mode-bundled-backend--remote-db)
3. [Quick Comparison](#quick-comparison)
4. [Step-by-Step Build Instructions](#step-by-step-build-instructions)
5. [Database Considerations](#database-considerations)

---

## Architecture Overview

Your Cafe Manager POS consists of four components:

```
┌─────────────────┐
│   Electron App  │  (Frontend UI - React)
│   (Bundled)     │
└────────┬────────┘
         │
    HTTP Requests (localhost:3001)
         │
┌────────▼────────┐
│  Backend API    │  (Node.js/Express)
│  (Bundled or    │
│   Remote)       │
└────────┬────────┘
         │
    SQL Queries
         │
┌────────▼────────┐
│   PostgreSQL    │  (Database)
│   (Bundled or   │
│    Remote)      │
└─────────────────┘
         │
    (Optional)
         │
┌────────▼────────┐
│ Printer Service │  (Go binary - thermal printer)
│  (Bundled)      │
└─────────────────┘
```

---

## Deployment Options

### Option 1: Standalone Mode (Everything Bundled)

**Best for:** Single-computer setups (one POS terminal)

**How it works:**
- PostgreSQL runs locally on the computer
- Backend API runs as a child process of Electron
- Printer service runs as a child process
- Everything is contained within the single computer

**Pros:**
- ✅ Works offline (no internet required)
- ✅ No server hosting costs
- ✅ Simple setup - just install and run
- ✅ Fast local database access

**Cons:**
- ❌ Not suitable for multiple terminals
- ❌ Data only exists on that one computer (backup critical!)
- ❌ Must install PostgreSQL on each computer
- ❌ Cannot access from other devices

**Setup Steps:**

1. **Install PostgreSQL locally** on the target computer
   ```bash
   # macOS
   brew install postgresql@16
   brew services start postgresql@16
   
   # Windows
   # Download installer from https://www.postgresql.org/download/windows/
   
   # Linux (Ubuntu/Debian)
   sudo apt-get install postgresql-16
   sudo systemctl start postgresql
   ```

2. **Create the database:**
   ```bash
   createdb cafe_db
   ```

3. **Build the application:**
   ```bash
   npm run electron:build
   ```

4. **Install the packaged app** from the `release/` folder

---

### Option 2: Client-Server Mode (Backend Hosted)

**Best for:** Multiple POS terminals in the same location/network

**How it works:**
- Backend API runs on a central server (cloud or local server)
- PostgreSQL runs on the same server or separate database server
- Electron apps on each terminal connect to the hosted backend
- Each terminal only needs the frontend + printer service

**Pros:**
- ✅ Multiple terminals can share data
- ✅ Centralized database - easier backups
- ✅ Can work across different locations (with internet)
- ✅ Can use managed database services (AWS RDS, etc.)

**Cons:**
- ❌ Requires internet/network connection
- ❌ Server hosting costs
- ❌ More complex initial setup
- ❌ Single point of failure if server goes down

**Setup Steps:**

#### Part A: Deploy Backend to Server

1. **Prepare a server** (AWS, DigitalOcean, etc. or local server)

2. **Install Node.js and PostgreSQL on the server**

3. **Clone and build the backend:**
   ```bash
   # On the server
   git clone <your-repo>
   cd cafe-order-management/backend
   npm install
   npm run build  # If you have a build script, or just copy src
   ```

4. **Set environment variables:**
   ```bash
   export DB_HOST=localhost
   export DB_PORT=5432
   export DB_NAME=cafe_db
   export DB_USER=postgres
   export DB_PASSWORD=your_secure_password
   export PORT=3001
   export JWT_SECRET=your_jwt_secret_key
   ```

5. **Start the backend as a service** (using PM2 or systemd):
   ```bash
   # Install PM2
   npm install -g pm2
   
   # Start backend
   pm2 start src/index.js --name "cafe-backend"
   pm2 startup
   pm2 save
   ```

6. **Note your server's IP/URL:** `http://your-server-ip:3001`

#### Part B: Modify Electron App for Client Mode

1. **Update the API configuration** in `src/services/api.ts`:
   ```typescript
   // Change from relative URL to your server URL
   const API_URL = process.env.NODE_ENV === 'development' 
     ? 'http://localhost:3001/api'
     : 'http://YOUR_SERVER_IP:3001/api';  // <-- Update this
   ```

2. **Modify `electron/main.js`** - remove backend startup:
   ```javascript
   // Comment out or remove these lines:
   // startBackend();
   
   // Keep only printer service if needed locally
   startPrinterService();
   ```

3. **Update `package.json`** - remove backend from extraResources:
   ```json
   "extraResources": [
     {
       "from": "mario-printer/build",
       "to": "mario-printer",
       "filter": ["**/*"]
     }
   ]
   ```

4. **Build the Electron app:**
   ```bash
   npm run electron:build
   ```

5. **Install on each terminal** - they will connect to your hosted backend

---

### Option 3: Hybrid Mode (Bundled Backend + Remote DB)

**Best for:** Single terminal with cloud database backup

**How it works:**
- Backend runs locally (bundled with Electron)
- PostgreSQL runs on a remote server (cloud database)
- Combines offline capability with centralized data

**Pros:**
- ✅ Works offline temporarily (with local caching if implemented)
- ✅ Data stored safely in cloud
- ✅ No need to install PostgreSQL locally
- ✅ Can access data from elsewhere (with separate client)

**Cons:**
- ❌ Requires internet for database access
- ❌ Database hosting costs
- ❌ Slightly slower than local DB
- ❌ More complex error handling for network issues

**Setup Steps:**

1. **Set up a cloud PostgreSQL database**:
   - AWS RDS PostgreSQL
   - Google Cloud SQL
   - Azure Database for PostgreSQL
   - Supabase (free tier available)
   - Neon (free tier available)

2. **Get connection details** from your cloud provider:
   - Host/Endpoint
   - Port (usually 5432)
   - Database name
   - Username
   - Password

3. **Configure environment variables** for the backend:
   Create a `.env` file in the project root that will be bundled:
   ```
   DB_HOST=your-db-host.amazonaws.com
   DB_PORT=5432
   DB_NAME=cafe_db
   DB_USER=postgres
   DB_PASSWORD=your_secure_password
   ```

4. **Update `electron/main.js`** to load the env file:
   ```javascript
   // Ensure dotenv is used
   const dotenv = require('dotenv');
   const envPath = isDev 
     ? path.join(__dirname, '..', '.env')
     : path.join(process.resourcesPath, '.env');
   dotenv.config({ path: envPath });
   ```

5. **Build and package**:
   ```bash
   npm run electron:build
   ```

---

## Quick Comparison

| Feature | Option 1: Standalone | Option 2: Client-Server | Option 3: Hybrid |
|---------|---------------------|------------------------|------------------|
| **Internet Required** | No | Yes | Yes |
| **Multiple Terminals** | No | Yes | No |
| **Local PostgreSQL** | Required | Not needed | Not needed |
| **Hosting Cost** | None | Server + DB | DB only |
| **Setup Complexity** | Low | High | Medium |
| **Data Backup** | Manual | Automatic | Automatic |
| **Offline Work** | Yes | No | No |
| **Best For** | Single terminal | Multiple terminals | Single terminal with cloud backup |

---

## Step-by-Step Build Instructions

### Prerequisites

Before building, ensure you have:

1. **Node.js 18+** installed
2. **Go 1.21+** installed (for printer service)
3. **PostgreSQL** installed locally (for Option 1)
4. **All dependencies installed:**
   ```bash
   npm install
   cd backend && npm install && cd ..
   ```

### Build Process

1. **Build the frontend:**
   ```bash
   npm run build
   ```
   This creates `dist/` with the React app.

2. **Build the printer service:**
   ```bash
   npm run build:printer
   ```
   Or manually:
   ```bash
   cd mario-printer && ./build.sh
   ```
   This creates binaries in `mario-printer/build/`.

3. **Prepare backend** (for bundling):
   ```bash
   # Ensure backend dependencies are installed
   cd backend
   npm install --production
   cd ..
   ```

4. **Build Electron app:**
   ```bash
   # For all platforms
   npm run electron:build
   
   # Or specific platform
   npx electron-builder --mac
   npx electron-builder --win
   npx electron-builder --linux
   ```

5. **Find your installers** in the `release/` folder:
   - macOS: `Cafe Manager-1.0.0.dmg`
   - Windows: `Cafe Manager Setup 1.0.0.exe`
   - Linux: `Cafe Manager-1.0.0.AppImage`

### Platform-Specific Notes

**macOS:**
- May need to sign the app for distribution
- Users may need to allow the app in Security & Privacy settings
- Printer service binary needs executable permissions

**Windows:**
- No signing needed for basic distribution
- Printer service `.exe` must be included
- May trigger Windows Defender warnings (add exception)

**Linux:**
- AppImage format is self-contained
- May need to make executable: `chmod +x Cafe\ Manager-1.0.0.AppImage`

---

## Database Considerations

### For Standalone Mode (Local PostgreSQL)

**Backup Strategy (CRITICAL):**
Since all data is on one computer, implement automatic backups:

```bash
# Create backup script
#!/bin/bash
pg_dump cafe_db > "/backups/cafe_db_$(date +%Y%m%d_%H%M%S).sql"
```

**Options:**
1. External hard drive backups
2. Cloud sync (Dropbox, Google Drive) of backup files
3. Network NAS storage

### For Client-Server Mode

**Database Setup:**
```sql
-- Create database
CREATE DATABASE cafe_db;

-- Create user (recommended over using postgres superuser)
CREATE USER cafe_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE cafe_db TO cafe_user;
```

**Security:**
- Use SSL connections: `sslmode=require`
- Restrict database access by IP
- Regular automated backups via provider

### For Hybrid Mode

**Connection Pooling:**
Since backend runs locally but DB is remote, connection pooling is important:

```javascript
// backend/src/db/index.js
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },  // For cloud DBs
  max: 20,  // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

---

## Recommendation

For a typical restaurant POS setup:

- **Single terminal restaurant** → Use **Option 1 (Standalone)** with regular backups
- **Multiple terminals in same location** → Use **Option 2 (Client-Server)**
- **Single terminal with owner wanting cloud access** → Use **Option 3 (Hybrid)**

The current Electron configuration defaults to **Option 1 (Standalone)** where everything is bundled together.

---

## Troubleshooting

### Backend won't start in production
- Check that `backend/dist/index.js` exists
- Verify Node.js is installed on target machine
- Check environment variables are set

### Printer service not found
- Ensure printer binaries are built: `npm run build:printer`
- Check binaries are in `mario-printer/build/`
- Verify executable permissions (Linux/Mac)

### Database connection fails
- Verify PostgreSQL is running
- Check credentials in environment variables
- Test connection: `psql -h localhost -U postgres -d cafe_db`

### Frontend shows blank screen in production
- Check console for errors
- Verify API_URL is correct for your deployment mode
- Ensure `dist/index.html` exists
