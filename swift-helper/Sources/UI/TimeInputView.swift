import SwiftUI
import AppKit

/// Popup view for entering a delay time in milliseconds.
/// Shows a text field and common preset buttons.
struct TimeInputView: View {
    let onComplete: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    // Common delay presets
    private let presets: [(label: String, ms: Double)] = [
        ("100ms", 100),
        ("250ms", 250),
        ("500ms", 500),
        ("1s", 1000),
        ("2s", 2000),
        ("5s", 5000)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Enter Delay")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            // Input field
            inputField
            
            // Preset buttons
            presetButtons
            
            // Action buttons
            actionButtons
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            // Focus input field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onExitCommand {
            onCancel()
        }
    }
    
    // MARK: - Input Field
    
    private var inputField: some View {
        HStack(spacing: 8) {
            TextField("", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onSubmit {
                    submitValue()
                }
                .frame(width: 100)
            
            Text("ms")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Preset Buttons
    
    private var presetButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(presets.prefix(3), id: \.ms) { preset in
                    presetButton(preset.label, value: preset.ms)
                }
            }
            HStack(spacing: 6) {
                ForEach(presets.suffix(3), id: \.ms) { preset in
                    presetButton(preset.label, value: preset.ms)
                }
            }
        }
    }
    
    private func presetButton(_ label: String, value: Double) -> some View {
        Button(action: {
            inputText = String(Int(value))
            submitValue()
        }) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 55, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 80, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button(action: submitValue) {
                Text("OK")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(!isValidInput)
        }
    }
    
    // MARK: - Helpers
    
    private var isValidInput: Bool {
        guard let value = Double(inputText) else { return false }
        return value > 0 && value <= 3600000 // Max 1 hour
    }
    
    private func submitValue() {
        guard let value = Double(inputText), value > 0 else {
            // Invalid input - shake or show error
            return
        }
        onComplete(value)
    }
}

// MARK: - Preview

#if DEBUG
struct TimeInputView_Previews: PreviewProvider {
    static var previews: some View {
        TimeInputView(
            onComplete: { _ in },
            onCancel: {}
        )
        .frame(width: 250, height: 200)
        .background(Color.gray)
    }
}
#endif
