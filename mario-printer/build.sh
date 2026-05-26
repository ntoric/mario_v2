#!/bin/bash

# Build script for mario-printer to generate cross-platform binaries
# Usage: ./build.sh

set -e

echo "Building mario-printer binaries..."

# Create build directory
mkdir -p build

# Build for macOS ARM64 (Apple Silicon)
echo "Building for macOS ARM64..."
GOOS=darwin GOARCH=arm64 go build -o build/mario-printer-darwin-arm64 .

# Build for macOS AMD64 (Intel)
echo "Building for macOS AMD64..."
GOOS=darwin GOARCH=amd64 go build -o build/mario-printer-darwin-amd64 .

# Build for Windows AMD64
echo "Building for Windows AMD64..."
GOOS=windows GOARCH=amd64 go build -o build/mario-printer-windows-amd64.exe .

# Build for Linux AMD64 (optional, for future use)
echo "Building for Linux AMD64..."
GOOS=linux GOARCH=amd64 go build -o build/mario-printer-linux-amd64 .

echo "Build complete! Binaries are in the build/ directory:"
ls -lh build/
