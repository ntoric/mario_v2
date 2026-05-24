# Building Cafe Manager POS

This document explains how to build the Electron application using Makefiles.

## Prerequisites

Before building, ensure you have:

1. **Node.js 18+** - [Download](https://nodejs.org/)
2. **Go 1.21+** - [Download](https://go.dev/dl/)
3. **npm** (comes with Node.js)

Verify installation:
```bash
node --version    # v18.x or higher
npm --version     # v9.x or higher
go version        # go1.21 or higher
```

## Quick Start

### Option 1: Simple Makefile (Recommended for most users)

```bash
# Build for current platform only (fastest)
make

# Build for all platforms (production release)
make release

# Quick development build
make quick

# Clean and start fresh
make clean && make
```

### Option 2: Advanced Makefile (CI/CD, parallel builds)

```bash
# Use the advanced makefile
make -f Makefile.advanced

# Full release with all platforms
make -f Makefile.advanced release

# CI/CD optimized build
make -f Makefile.advanced release-ci
```

## Build Targets

### Main Targets

| Command | Description | Time |
|---------|-------------|------|
| `make` | Build for current platform | ~2-3 min |
| `make release` | Build for all platforms | ~5-8 min |
| `make quick` | Fast dev build (current platform) | ~1-2 min |
| `make clean` | Remove all build artifacts | <1 sec |

### Platform-Specific

```bash
# macOS only
make electron-mac

# Windows only
make electron-win

# Linux only
make electron-linux

# All platforms
make electron-all
```

### Individual Components

```bash
# Build frontend only
make frontend

# Build printer service for current platform
make printer-service-quick

# Build printer service for all platforms
make printer-service
```

## Output Files

After building, installers will be in the `release/` directory:

### macOS
- `Cafe Manager-1.0.0.dmg` - Disk image for distribution
- `Cafe Manager-1.0.0-arm64.dmg` - Apple Silicon (M1/M2)
- `Cafe Manager-1.0.0-x64.dmg` - Intel Macs

### Windows
- `Cafe Manager Setup 1.0.0.exe` - NSIS installer
- `Cafe Manager 1.0.0.exe` - Portable version

### Linux
- `Cafe Manager-1.0.0.AppImage` - Universal Linux package
- `cafe-manager_1.0.0_amd64.deb` - Debian/Ubuntu package
- `cafe-manager-1.0.0.x86_64.rpm` - RedHat/Fedora package

## Build Process Explained

The build process consists of:

```
1. Clean          → Remove old builds
2. Dependencies   → npm install
3. Frontend       → TypeScript + Vite build
4. Backend        → Copy backend files
5. Printer        → Build Go binaries for all platforms
6. Package        → Electron-builder creates installers
```

## Troubleshooting

### Build fails with "electron-builder not found"
```bash
npm install
```

### Printer service build fails
```bash
# Check Go installation
go version

# Build manually
cd printer_service && go build -o printer-service .
```

### Frontend build errors
```bash
# Skip TypeScript checking (some errors are pre-existing)
npx vite build
```

### Out of memory during build
```bash
# Build one platform at a time
make electron-mac
make electron-win
make electron-linux
```

## Makefile Comparison

| Feature | Makefile | Makefile.advanced |
|---------|----------|-------------------|
| Simplicity | ✅ Simple | More complex |
| Parallel builds | ❌ No | ✅ Yes |
| Platform detection | ❌ No | ✅ Yes |
| CI/CD optimized | ❌ No | ✅ Yes |
| Progress output | Basic | Detailed |
| Cross-compile | Yes | Yes (optimized) |

**Recommendation**: Use `Makefile` for local development, `Makefile.advanced` for CI/CD pipelines.

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Build Release
        run: make -f Makefile.advanced release-ci
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: installers
          path: release/*
```

### Local Release Script

```bash
#!/bin/bash
# release.sh

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh 1.0.0"
    exit 1
fi

# Update version
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" package.json

# Build
make clean
make release

# Create release notes
echo "# Release $VERSION" > release/RELEASE_NOTES.md
echo "" >> release/RELEASE_NOTES.md
echo "## Files" >> release/RELEASE_NOTES.md
ls -lh release/*.{dmg,exe,AppImage} 2>/dev/null >> release/RELEASE_NOTES.md

echo "Release $VERSION built successfully!"
```

## Platform-Specific Notes

### macOS
- **Code signing**: Required for distribution outside App Store
- **Notarization**: Required for macOS 10.15+
- **Architecture**: Supports both Intel (x64) and Apple Silicon (arm64)

### Windows
- **Code signing**: Recommended to avoid SmartScreen warnings
- **Antivirus**: May flag unsigned executables
- **Dependencies**: No runtime dependencies needed

### Linux
- **Dependencies**: No additional dependencies for AppImage
- **Permissions**: May need to make AppImage executable: `chmod +x *.AppImage`
- **Desktop integration**: AppImage supports desktop shortcuts

## File Structure After Build

```
release/
├── Cafe Manager-1.0.0.dmg          # macOS (universal)
├── Cafe Manager-1.0.0-arm64.dmg    # macOS (Apple Silicon)
├── Cafe Manager-1.0.0-x64.dmg      # macOS (Intel)
├── Cafe Manager Setup 1.0.0.exe    # Windows installer
├── Cafe Manager 1.0.0.exe          # Windows portable
├── Cafe Manager-1.0.0.AppImage     # Linux AppImage
├── cafe-manager_1.0.0_amd64.deb    # Linux DEB
└── cafe-manager-1.0.0.x86_64.rpm   # Linux RPM

printer_service/build/
├── printer-service-darwin-arm64    # macOS ARM64
├── printer-service-darwin-amd64    # macOS Intel
├── printer-service-windows-amd64.exe # Windows
├── printer-service-linux-amd64     # Linux x64
└── printer-service-linux-arm64     # Linux ARM64
```

## Next Steps

After building:

1. **Test installers** on target platforms
2. **Sign executables** (especially for macOS and Windows)
3. **Upload to distribution** (website, GitHub Releases, etc.)
4. **Update auto-updater** configuration if applicable

For deployment options, see [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md).
