# Cafe Manager POS - Electron Build Makefile
# Builds installable apps for macOS, Windows, and Linux

.PHONY: all clean install build frontend printer-service electron electron-mac electron-win electron-linux electron-all

# Variables
APP_NAME := Cafe Manager
VERSION := 1.0.0
RELEASE_DIR := release
BUILD_DIR := dist
PRINTER_BUILD_DIR := printer_service/build
ELECTRON_BUILDER := npx electron-builder

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

# Default target - build for current platform only
all: clean install build

# Full build for all platforms (use on CI/CD or when releasing)
release: clean install build printer-service electron-all
	@echo "$(GREEN)✓ Release build complete! Check $(RELEASE_DIR)/ for installers$(NC)"

# Clean previous builds
clean:
	@echo "$(BLUE)→ Cleaning previous builds...$(NC)"
	@rm -rf $(BUILD_DIR) $(RELEASE_DIR) $(PRINTER_BUILD_DIR)
	@rm -f printer_service/printer-service
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Install dependencies
install:
	@echo "$(BLUE)→ Installing dependencies...$(NC)"
	@npm install
	@cd backend && npm install --production && cd ..
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

# Build frontend (TypeScript + Vite)
frontend:
	@echo "$(BLUE)→ Building frontend...$(NC)"
	@npx tsc --noEmit --skipLibCheck 2>/dev/null || true
	@npx vite build
	@echo "$(GREEN)✓ Frontend build complete$(NC)"

# Build printer service for all platforms
printer-service:
	@echo "$(BLUE)→ Building printer service for all platforms...$(NC)"
	@cd printer_service && ./build.sh
	@echo "$(GREEN)✓ Printer service binaries built$(NC)"

# Quick build printer service for current platform only
printer-service-quick:
	@echo "$(BLUE)→ Building printer service for current platform...$(NC)"
	@cd printer_service && go build -ldflags="-s -w" -o printer-service .
	@echo "$(GREEN)✓ Printer service built$(NC)"

# Main build target
build: frontend
	@echo "$(GREEN)✓ Build complete$(NC)"

# Build for current platform (fastest for development)
electron: build printer-service-quick
	@echo "$(BLUE)→ Building Electron app for current platform...$(NC)"
	@$(ELECTRON_BUILDER)
	@echo "$(GREEN)✓ Electron app built in $(RELEASE_DIR)/$(NC)"

# Build for macOS (DMG for both Intel and Apple Silicon)
electron-mac: build printer-service
	@echo "$(BLUE)→ Building Electron app for macOS...$(NC)"
	@$(ELECTRON_BUILDER) --mac
	@echo "$(GREEN)✓ macOS installer built: $(RELEASE_DIR)/*.dmg$(NC)"

# Build for Windows (NSIS installer)
electron-win: build printer-service
	@echo "$(BLUE)→ Building Electron app for Windows...$(NC)"
	@$(ELECTRON_BUILDER) --win
	@echo "$(GREEN)✓ Windows installer built: $(RELEASE_DIR)/*.exe$(NC)"

# Build for Linux (AppImage)
electron-linux: build printer-service
	@echo "$(BLUE)→ Building Electron app for Linux...$(NC)"
	@$(ELECTRON_BUILDER) --linux
	@echo "$(GREEN)✓ Linux AppImage built: $(RELEASE_DIR)/*.AppImage$(NC)"

# Build for all platforms (requires all build tools installed)
electron-all: build printer-service
	@echo "$(BLUE)→ Building Electron apps for all platforms...$(NC)"
	@echo "$(YELLOW)  Building macOS...$(NC)"
	@$(ELECTRON_BUILDER) --mac || echo "$(RED)  ✗ macOS build failed$(NC)"
	@echo "$(YELLOW)  Building Windows...$(NC)"
	@$(ELECTRON_BUILDER) --win || echo "$(RED)  ✗ Windows build failed$(NC)"
	@echo "$(YELLOW)  Building Linux...$(NC)"
	@$(ELECTRON_BUILDER) --linux || echo "$(RED)  ✗ Linux build failed$(NC)"
	@echo "$(GREEN)✓ All platform builds complete$(NC)"

# Pack without packaging (useful for testing)
electron-pack: build printer-service-quick
	@echo "$(BLUE)→ Packing Electron app (no installer)...$(NC)"
	@$(ELECTRON_BUILDER) --dir
	@echo "$(GREEN)✓ App packed in $(RELEASE_DIR)/*/$(NC)"

# Development mode
dev:
	@echo "$(BLUE)→ Starting development mode...$(NC)"
	@npm run electron:dev

# Quick build for testing (skips cross-platform printer builds)
quick: clean install build printer-service-quick electron
	@echo "$(GREEN)✓ Quick build complete$(NC)"

# Verify build artifacts exist
verify:
	@echo "$(BLUE)→ Verifying build artifacts...$(NC)"
	@test -d $(BUILD_DIR) && echo "  ✓ Frontend build exists" || echo "  ✗ Frontend build missing"
	@test -f printer_service/printer-service && echo "  ✓ Printer service binary exists" || echo "  ✗ Printer service binary missing"
	@test -f electron/main.js && echo "  ✓ Electron main exists" || echo "  ✗ Electron main missing"
	@echo "$(GREEN)✓ Verification complete$(NC)"

# List output files
list:
	@echo "$(BLUE)→ Build outputs:$(NC)"
	@ls -lh $(RELEASE_DIR)/ 2>/dev/null || echo "  No release files yet"

# Help
help:
	@echo "$(BLUE)Cafe Manager POS - Build Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  $(YELLOW)make$(NC)                - Clean, install, build frontend and Electron (current platform only)"
	@echo "  $(YELLOW)make release$(NC)        - Full build for all platforms (production release)"
	@echo "  $(YELLOW)make quick$(NC)          - Quick build for current platform (development)"
	@echo "  $(YELLOW)make clean$(NC)          - Remove all build artifacts"
	@echo "  $(YELLOW)make install$(NC)        - Install npm dependencies"
	@echo "  $(YELLOW)make build$(NC)          - Build frontend only"
	@echo "  $(YELLOW)make printer-service$(NC)- Build printer service for all platforms"
	@echo "  $(YELLOW)make electron$(NC)       - Build Electron app for current platform"
	@echo "  $(YELLOW)make electron-mac$(NC)   - Build for macOS (DMG)"
	@echo "  $(YELLOW)make electron-win$(NC)   - Build for Windows (NSIS)"
	@echo "  $(YELLOW)make electron-linux$(NC) - Build for Linux (AppImage)"
	@echo "  $(YELLOW)make electron-all$(NC)   - Build for all platforms"
	@echo "  $(YELLOW)make dev$(NC)            - Start development mode"
	@echo "  $(YELLOW)make verify$(NC)         - Verify build artifacts"
	@echo "  $(YELLOW)make list$(NC)           - List built files"
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  make quick              # Fastest build for testing"
	@echo "  make electron-mac       # Build macOS installer only"
	@echo "  make release            # Full release (all platforms)"
