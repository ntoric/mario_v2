#!/bin/bash

# Build script for printer service
# Creates binaries for all supported platforms

set -e

echo "Building Printer Service..."

VERSION=${VERSION:-"1.0.0"}
BUILD_DIR="build"

# Clean previous builds
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# Build for macOS ARM64 (Apple Silicon)
echo "Building for macOS ARM64..."
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o $BUILD_DIR/printer-service-darwin-arm64 .

# Build for macOS AMD64 (Intel)
echo "Building for macOS AMD64..."
GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o $BUILD_DIR/printer-service-darwin-amd64 .

# Build for Windows AMD64
echo "Building for Windows AMD64..."
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o $BUILD_DIR/printer-service-windows-amd64.exe .

# Build for Linux AMD64
echo "Building for Linux AMD64..."
GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $BUILD_DIR/printer-service-linux-amd64 .

# Build for Linux ARM64
echo "Building for Linux ARM64..."
GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o $BUILD_DIR/printer-service-linux-arm64 .

echo ""
echo "Build complete! Binaries created in $BUILD_DIR/"
ls -la $BUILD_DIR/

# Copy current platform binary to root
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [ "$PLATFORM" = "darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        cp $BUILD_DIR/printer-service-darwin-arm64 printer-service
    else
        cp $BUILD_DIR/printer-service-darwin-amd64 printer-service
    fi
elif [ "$PLATFORM" = "linux" ]; then
    if [ "$ARCH" = "aarch64" ]; then
        cp $BUILD_DIR/printer-service-linux-arm64 printer-service
    else
        cp $BUILD_DIR/printer-service-linux-amd64 printer-service
    fi
fi

echo ""
echo "Current platform binary copied to printer-service"

# Make binaries executable (Unix only)
if [ "$PLATFORM" != "mingw" ] && [ "$PLATFORM" != "msys" ]; then
    chmod +x $BUILD_DIR/*
    chmod +x printer-service 2>/dev/null || true
fi

echo ""
echo "Done! All binaries are ready."
