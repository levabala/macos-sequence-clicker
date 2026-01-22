#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if build has been run
if [ ! -d "swift-helper/.build/release" ]; then
    echo "Swift helper not built. Run ./build.sh first."
    exit 1
fi

if [ ! -d "controller/node_modules" ]; then
    echo "Controller dependencies not installed. Run ./build.sh first."
    exit 1
fi

cd controller
exec bun run start
