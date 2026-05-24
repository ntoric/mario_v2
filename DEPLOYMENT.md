# Deployment Guide - Cafe Manager macOS ARM64

## Build Output

The optimized Electron app has been built for macOS ARM64 (Apple Silicon) with **embedded environment variables**.

### Files Generated

| File | Size | Description |
|------|------|-------------|
| `Cafe Manager-1.0.0-arm64.dmg` | ~104MB | Disk image for easy installation |
| `Cafe Manager-1.0.0-arm64-mac.zip` | ~4MB | Compressed zip archive |

## Installation

### For End Users

1. Download `Cafe Manager-1.0.0-arm64.dmg`
2. Double-click to mount the DMG
3. Drag "Cafe Manager" to the Applications folder
4. Launch from Applications

**No additional configuration needed** - All environment variables are embedded at build time!

## Environment Configuration (For Developers)

Environment variables are **embedded at build time** from `.env.production`. To change configuration:

1. Edit `.env.production` in the project root
2. Rebuild the app: `./build-mac-arm64.sh`

### Example `.env.production`:

```env
# Remote Database Configuration
DB_HOST=your-remote-db-host.com
DB_PORT=5432
DB_NAME=cafe_db
DB_USER=your_db_user
DB_PASSWORD=your_secure_password

# Security (change to a strong random string!)
JWT_SECRET=your-super-secret-production-key-min-32-chars

# Server
PORT=3001
NODE_ENV=production

# Super Admin (change default credentials!)
SUPERADMIN_USERNAME=superadmin
SUPERADMIN_PASSWORD=your_secure_admin_password
SUPERADMIN_NAME=Super Administrator

# Printer Service
PRINTER_SERVICE_URL=http://localhost:8085
DISABLE_PRINTER_SERVICE=false
```

## What's Bundled

The app includes:
- ✅ Frontend (React + Vite optimized build)
- ✅ Backend (Compiled to standalone binary with Node.js embedded)
- ✅ Printer Service (Go binary for macOS ARM64)
- ✅ Environment variables (embedded at build time)
- ⚠️ **Database** - Connects to remote PostgreSQL (not included)

## Architecture

```
┌─────────────────────────────────────────────┐
│          Cafe Manager.app                   │
│  ┌───────────────────────────────────────┐  │
│  │  Electron Main Process                │  │
│  │  - Embedded env from env-config.js    │  │
│  │  - Spawns backend binary (port 3001)  │  │
│  │  - Spawns printer service (port 8085) │  │
│  └───────────────────────────────────────┘  │
│                     │                        │
│  ┌───────────────────────────────────────┐  │
│  │  Renderer Process (Chromium)          │  │
│  │  - React Frontend UI                  │  │
│  └───────────────────────────────────────┘  │
│                     │                        │
│  ┌───────────────────────────────────────┐  │
│  │  Bundled Resources                    │  │
│  │  - backend-darwin-arm64 (49MB)        │  │
│  │  - printer-service-darwin-arm64 (20MB)│  │
│  │  - .env (embedded config)             │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
           │
           ▼
    Remote PostgreSQL Database
    (configured at build time)
```

## Rebuilding

To rebuild the app with new configuration:

```bash
# Method 1: Use the build script
./build-mac-arm64.sh

# Method 2: Manual steps
npm run prepare:env      # Generate env-config.js from .env.production
npm run build            # Build frontend
npm run build:backend:binary   # Compile backend to binary
npm run build:printer:mac      # Build printer service
npx electron-builder --mac --arm64  # Package app
```

## Build Process

1. **`prepare:env`** - Reads `.env.production` and generates:
   - `electron/env-config.js` - Embedded env for main process
   - `backend/build/.env` - For backend binary compilation

2. **`build:backend:binary`** - Uses `pkg` to compile Node.js backend to standalone executable

3. **`build:printer:mac`** - Compiles Go printer service for macOS ARM64

4. **`electron-builder`** - Packages everything into the final .app bundle

## Troubleshooting

### App won't start
- Check Console.app for crash logs
- Verify the database server is accessible from the build machine
- Check that all env variables are set in `.env.production`

### Database connection fails
- Verify DB_HOST, DB_PORT, DB_USER, DB_PASSWORD in `.env.production`
- Test connection: `psql -h DB_HOST -U DB_USER -d DB_NAME`
- Rebuild after fixing: `./build-mac-arm64.sh`

### "Backend binary not found"
- Run `npm run build:backend:binary` to compile the backend
- Check `backend/build/backend-darwin-arm64` exists

### Printer not working
- Check printer service logs in Console.app
- Verify USB printer is connected
- Set `DISABLE_PRINTER_SERVICE=true` in `.env.production` to disable

## File Locations

| Component | Location |
|-----------|----------|
| App | `/Applications/Cafe Manager.app` |
| Logs | `~/Library/Logs/Cafe Manager/` |
| Data | Remote PostgreSQL database |

## Key Differences from Previous Version

✅ **Environment variables embedded at build time** - No need for user configuration
✅ **Standalone backend binary** - No Node.js installation required
✅ **Health check on startup** - App waits for backend to be ready
✅ **Smaller footprint** - Optimized compression and packaging

## Security Notes

- JWT_SECRET should be a strong random string (min 32 characters)
- Database credentials are embedded in the binary - distribute carefully
- For production use, consider code signing with Apple Developer ID
