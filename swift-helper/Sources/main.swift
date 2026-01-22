import Foundation
import AppKit

// Main entry point for SequencerHelper
// Using top-level code pattern for async main

// Initialize NSApplication for later UI work (recorder overlay, magnifier)
// This is needed even for command-line apps that will show windows
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon, no menu bar

// Start IPC handler
let handler = IPCHandler()

// Run the async IPC loop
Task {
    await handler.run()
    // Clean exit after IPC loop ends
    exit(0)
}

// Start the run loop (required for async and UI)
RunLoop.main.run()
