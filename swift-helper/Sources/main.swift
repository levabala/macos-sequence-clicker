import Foundation
import AppKit

// Main entry point for SequencerHelper
// Using top-level code pattern for async main

// Clear log file on each start for clean debugging
Logger.clear()
Logger.log("Main", "SequencerHelper starting")

// Initialize NSApplication for later UI work (recorder overlay, magnifier)
// This is needed even for command-line apps that will show windows
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon, no menu bar
Logger.log("Main", "NSApplication initialized with accessory policy")

// Start IPC handler
let handler = IPCHandler()
Logger.log("Main", "IPCHandler created")

// Run the async IPC loop
Task {
    Logger.log("Main", "Starting IPC loop task")
    await handler.run()
    // Clean exit after IPC loop ends
    Logger.log("Main", "IPC loop ended, exiting")
    exit(0)
}

Logger.log("Main", "Starting RunLoop.main")
// Start the run loop (required for async and UI)
RunLoop.main.run()
