#!/bin/bash

# Sentinel 360 Mobile - Setup Script
# This script sets up the project and creates placeholder icons

echo "=========================================="
echo "  Sentinel 360 Mobile - Setup Script"
echo "=========================================="
echo ""

# Check if node is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed."
    echo "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

# Check node version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "Warning: Node.js version $NODE_VERSION detected."
    echo "This project requires Node.js 18+."
    echo "Please upgrade: https://nodejs.org/"
fi

echo "Step 1: Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "Trying with legacy peer deps..."
    npm install --legacy-peer-deps
fi

echo ""
echo "Step 2: Creating placeholder app icons..."
mkdir -p assets

# Create a simple 1x1 blue pixel PNG (base64 encoded)
# This is the smallest valid PNG - 67 bytes
BLUE_PIXEL="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg=="

# Check if base64 command supports -d (Linux) or -D (macOS)
if base64 --help 2>&1 | grep -q "\\-d"; then
    DECODE_FLAG="-d"
else
    DECODE_FLAG="-D"
fi

# Create placeholder icons
echo "$BLUE_PIXEL" | base64 $DECODE_FLAG > assets/icon.png 2>/dev/null || echo "Could not create icon.png"
cp assets/icon.png assets/adaptive-icon.png 2>/dev/null
cp assets/icon.png assets/splash-icon.png 2>/dev/null
cp assets/icon.png assets/favicon.png 2>/dev/null

# Check if icons were created
if [ -f "assets/icon.png" ]; then
    echo "Placeholder icons created successfully!"
else
    echo "Note: Could not create placeholder icons."
    echo "The app will still run - you'll just see a warning."
    echo "See assets/README.md for how to create proper icons."
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "To start the app, run:"
echo ""
echo "  npx expo start -c"
echo ""
echo "Then scan the QR code with:"
echo "  - iOS: Camera app"
echo "  - Android: Expo Go app"
echo ""
echo "For more help, see:"
echo "  - START_HERE.md (quick start)"
echo "  - README.md (full documentation)"
echo "  - TROUBLESHOOTING.md (common issues)"
echo ""
