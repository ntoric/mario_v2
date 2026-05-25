#!/bin/bash

# Build script for macOS ARM64 Electron app with embedded env variables
# This creates a standalone app bundle with backend

set -e

echo "=========================================="
echo "Building Cafe Manager for macOS ARM64"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf dist/
rm -rf release/
rm -rf backend/build/

# Step 1: Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install

# Step 2: Prepare environment (generates electron/env-config.js)
echo -e "${YELLOW}Preparing environment configuration...${NC}"
node scripts/prepare-env.js

# Step 3: Build frontend
echo -e "${YELLOW}Building frontend...${NC}"
npx vite build

# Step 4: Build Go backend for macOS ARM64
echo -e "${YELLOW}Building Go backend for macOS ARM64...${NC}"
cd backend
mkdir -p build
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o build/cafe-backend-darwin-arm64 cmd/server/main.go
cd ..

# Step 5: Build Electron app
echo -e "${YELLOW}Building Electron app...${NC}"
npx electron-builder --mac --arm64

echo -e "${GREEN}=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Output location: release/"
echo ""
echo "Files created:"
ls -lh release/ | grep -E "dmg|zip"
echo ""
echo -e "${YELLOW}Environment variables are embedded from .env.production${NC}"
echo -e "${YELLOW}To change configuration, edit .env.production and rebuild${NC}"
echo ""
echo -e "${GREEN}Done!${NC}"
