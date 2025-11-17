#!/bin/bash
cd "$(dirname "$0")"

echo "Building MOVE..."
xcodebuild -project MOVE.xcodeproj -scheme MOVE -configuration Debug build

if [ $? -eq 0 ]; then
    echo "Build succeeded. Running MOVE with logs..."
    # Find the app, excluding Index.noindex directories
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "MOVE.app" -path "*/Build/Products/Debug/*" ! -path "*/Index.noindex/*" | head -n 1)
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo "Error: MOVE.app not found in DerivedData"
        echo "Searched in: ~/Library/Developer/Xcode/DerivedData"
        exit 1
    fi
    
    # Verify the executable exists
    if [ ! -f "$APP_PATH/Contents/MacOS/MOVE" ]; then
        echo "Error: MOVE executable not found at $APP_PATH/Contents/MacOS/MOVE"
        exit 1
    fi
    echo "Found app at: $APP_PATH"
    echo "Opening app..."
    echo ""
    echo "Streaming MOVE application logs (filtered to show only your app's output)..."
    echo "NOTE: This includes your Swift print() statements and app-specific system logs."
    echo "      HotkeyManager debug prints and other app logs will appear here!"
    echo "Press Ctrl+C to stop."
    echo "---"

    # Open the app as GUI app in background
    open "$APP_PATH"

    # Give the app a moment to start
    sleep 2

    # Stream unified logs - show our debug prints and app-specific logs
    # Allow ViewController and HOTKEY debug messages through
    log stream \
        --predicate '(process == "MOVE" || senderImagePath CONTAINS "MOVE")' \
        --level=info \
        --style=compact \
        --color=always 2>&1 | \
    grep -E "(ViewController|HOTKEY|HotkeyManager)" | \
    tee /tmp/move.log
else
    echo "Build failed!"
    exit 1
fi

