import Foundation
import CoreGraphics

/// Controller for screen capture and pixel color detection
actor ScreenCapture {
    
    enum ScreenError: Error, LocalizedError {
        case failedToCapture
        case failedToGetPixelData
        case positionOutOfBounds(Point)
        case timeout
        case noMatchingPixelInZone
        
        var errorDescription: String? {
            switch self {
            case .failedToCapture:
                return "Failed to capture screen (check Screen Recording permission)"
            case .failedToGetPixelData:
                return "Failed to extract pixel data from image"
            case .positionOutOfBounds(let point):
                return "Position (\(point.x), \(point.y)) is out of screen bounds"
            case .timeout:
                return "Timed out waiting for pixel condition"
            case .noMatchingPixelInZone:
                return "No matching pixel found in the specified zone"
            }
        }
    }
    
    /// Default polling interval for wait operations (milliseconds)
    private let defaultPollingInterval: UInt64 = 50
    
    /// Default timeout for wait operations (milliseconds)
    private let defaultTimeout: Double = 30000
    
    // MARK: - Public API
    
    /// Get the color of a single pixel at the specified position
    /// - Parameter point: Screen coordinates (top-left origin)
    /// - Returns: RGB color values
    func getPixelColor(at point: Point) throws -> RGB {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        
        // Capture a 1x1 region at the point
        let rect = CGRect(x: cgPoint.x, y: cgPoint.y, width: 1, height: 1)
        
        guard let image = CGDisplayCreateImage(CGMainDisplayID(), rect: rect) else {
            throw ScreenError.failedToCapture
        }
        
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            throw ScreenError.failedToGetPixelData
        }
        
        // Extract RGB from first pixel
        // Note: CGImage pixel data is typically BGRA or RGBA depending on format
        if image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first || image.alphaInfo == .noneSkipFirst {
            // ARGB or XRGB format
            return RGB(r: Int(bytes[1]), g: Int(bytes[2]), b: Int(bytes[3]))
        } else {
            // RGBA, RGBX, or RGB format
            return RGB(r: Int(bytes[0]), g: Int(bytes[1]), b: Int(bytes[2]))
        }
    }
    
    /// Check if a pixel matches the expected color within threshold
    /// - Parameters:
    ///   - point: Screen coordinates
    ///   - expectedColor: Target RGB color
    ///   - threshold: Maximum Euclidean distance (0 = exact match, ~441 = max)
    /// - Returns: true if the pixel color is within threshold of expected
    func checkPixelState(at point: Point, expectedColor: RGB, threshold: Double) throws -> Bool {
        let actualColor = try getPixelColor(at: point)
        let distance = colorDistance(actualColor, expectedColor)
        return distance <= threshold
    }
    
    /// Check if any pixel in a rectangle matches the expected color
    /// - Parameters:
    ///   - rect: Rectangle to scan (top-left origin)
    ///   - expectedColor: Target RGB color
    ///   - threshold: Maximum Euclidean distance
    /// - Returns: true if any pixel in the zone matches
    func checkPixelZone(rect: Rect, expectedColor: RGB, threshold: Double) throws -> Bool {
        let cgRect = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        
        guard let image = CGDisplayCreateImage(CGMainDisplayID(), rect: cgRect) else {
            throw ScreenError.failedToCapture
        }
        
        return try scanImageForColor(image, expectedColor: expectedColor, threshold: threshold)
    }
    
    /// Wait until a pixel matches the expected color
    /// - Parameters:
    ///   - point: Screen coordinates
    ///   - expectedColor: Target RGB color
    ///   - threshold: Maximum Euclidean distance
    ///   - timeoutMs: Maximum wait time in milliseconds (nil = default 30s)
    /// - Returns: true if condition was met, false if timed out
    func waitForPixelState(
        at point: Point,
        expectedColor: RGB,
        threshold: Double,
        timeoutMs: Double?
    ) async throws -> Bool {
        let timeout = timeoutMs ?? defaultTimeout
        let startTime = Date()
        
        while true {
            // Check condition
            if try checkPixelState(at: point, expectedColor: expectedColor, threshold: threshold) {
                return true
            }
            
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if elapsed >= timeout {
                return false
            }
            
            // Wait before next check
            try await Task.sleep(nanoseconds: defaultPollingInterval * 1_000_000)
        }
    }
    
    /// Wait until any pixel in a zone matches the expected color
    /// - Parameters:
    ///   - rect: Rectangle to scan
    ///   - expectedColor: Target RGB color
    ///   - threshold: Maximum Euclidean distance
    ///   - timeoutMs: Maximum wait time in milliseconds (nil = default 30s)
    /// - Returns: true if condition was met, false if timed out
    func waitForPixelZone(
        rect: Rect,
        expectedColor: RGB,
        threshold: Double,
        timeoutMs: Double?
    ) async throws -> Bool {
        let timeout = timeoutMs ?? defaultTimeout
        let startTime = Date()
        
        while true {
            // Check condition
            if try checkPixelZone(rect: rect, expectedColor: expectedColor, threshold: threshold) {
                return true
            }
            
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if elapsed >= timeout {
                return false
            }
            
            // Wait before next check
            try await Task.sleep(nanoseconds: defaultPollingInterval * 1_000_000)
        }
    }
    
    /// Capture a region around a point (for magnifier preview)
    /// - Parameters:
    ///   - point: Center point
    ///   - radius: Radius in pixels
    /// - Returns: CGImage of the captured region
    func captureRegion(around point: Point, radius: Int) throws -> CGImage {
        let rect = CGRect(
            x: point.x - Double(radius),
            y: point.y - Double(radius),
            width: Double(radius * 2 + 1),
            height: Double(radius * 2 + 1)
        )
        
        guard let image = CGDisplayCreateImage(CGMainDisplayID(), rect: rect) else {
            throw ScreenError.failedToCapture
        }
        
        return image
    }
    
    // MARK: - Private Helpers
    
    /// Calculate Euclidean RGB distance between two colors
    /// Range: 0 (exact match) to ~441 (black to white)
    private func colorDistance(_ a: RGB, _ b: RGB) -> Double {
        let dr = Double(a.r - b.r)
        let dg = Double(a.g - b.g)
        let db = Double(a.b - b.b)
        return sqrt(dr * dr + dg * dg + db * db)
    }
    
    /// Scan an image for a pixel matching the expected color
    private func scanImageForColor(_ image: CGImage, expectedColor: RGB, threshold: Double) throws -> Bool {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            throw ScreenError.failedToGetPixelData
        }
        
        let width = image.width
        let height = image.height
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
        let isAlphaFirst = image.alphaInfo == .premultipliedFirst || 
                           image.alphaInfo == .first || 
                           image.alphaInfo == .noneSkipFirst
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                let color: RGB
                if isAlphaFirst {
                    color = RGB(r: Int(bytes[offset + 1]), g: Int(bytes[offset + 2]), b: Int(bytes[offset + 3]))
                } else {
                    color = RGB(r: Int(bytes[offset]), g: Int(bytes[offset + 1]), b: Int(bytes[offset + 2]))
                }
                
                if colorDistance(color, expectedColor) <= threshold {
                    return true
                }
            }
        }
        
        return false
    }
}
