#!/bin/bash
set -e

echo "=== Building macOS Smart Sequencer ==="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "1/3 Building schema types..."
cd schema
bun install --frozen-lockfile 2>/dev/null || bun install
bun run generate
cd ..

echo ""
echo "2/3 Building Swift helper..."
cd swift-helper
swift build -c release
echo "    Signing binary for accessibility permissions..."
codesign -s - -f .build/release/SequencerHelper 2>/dev/null
cd ..

echo ""
echo "3/3 Installing controller dependencies..."
cd controller
bun install --frozen-lockfile 2>/dev/null || bun install
cd ..

echo ""
echo "=== Build complete! ==="
echo "Run ./run.sh to start the app"
