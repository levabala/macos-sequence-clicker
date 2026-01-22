import Foundation

// MARK: - Primitives

struct Point: Codable, Equatable {
    let x: Double
    let y: Double
}

struct RGB: Codable, Equatable {
    let r: Int
    let g: Int
    let b: Int
}

struct Rect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Steps

/// A step in a scenario - can be an action, transition, or scenario reference
enum Step: Codable, Equatable {
    case click(ClickAction)
    case keypress(KeypressAction)
    case delay(DelayTransition)
    case pixelState(PixelStateTransition)
    case pixelZone(PixelZoneTransition)
    case scenarioRef(ScenarioRef)
    
    var type: String {
        switch self {
        case .click: return "click"
        case .keypress: return "keypress"
        case .delay: return "delay"
        case .pixelState: return "pixel-state"
        case .pixelZone: return "pixel-zone"
        case .scenarioRef: return "scenario-ref"
        }
    }
    
    // Custom coding to handle discriminated union
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "click":
            self = .click(try ClickAction(from: decoder))
        case "keypress":
            self = .keypress(try KeypressAction(from: decoder))
        case "delay":
            self = .delay(try DelayTransition(from: decoder))
        case "pixel-state":
            self = .pixelState(try PixelStateTransition(from: decoder))
        case "pixel-zone":
            self = .pixelZone(try PixelZoneTransition(from: decoder))
        case "scenario-ref":
            self = .scenarioRef(try ScenarioRef(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown step type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .click(let action):
            try action.encode(to: encoder)
        case .keypress(let action):
            try action.encode(to: encoder)
        case .delay(let transition):
            try transition.encode(to: encoder)
        case .pixelState(let transition):
            try transition.encode(to: encoder)
        case .pixelZone(let transition):
            try transition.encode(to: encoder)
        case .scenarioRef(let ref):
            try ref.encode(to: encoder)
        }
    }
}

// MARK: - Actions

struct ClickAction: Codable, Equatable {
    let type: String
    let position: Point
    let button: String  // "left" or "right"
    
    init(type: String = "click", position: Point, button: String) {
        self.type = type
        self.position = position
        self.button = button
    }
}

struct KeypressAction: Codable, Equatable {
    let type: String
    let key: String
    let modifiers: [String]
    
    init(type: String = "keypress", key: String, modifiers: [String]) {
        self.type = type
        self.key = key
        self.modifiers = modifiers
    }
}

// MARK: - Transitions

struct DelayTransition: Codable, Equatable {
    let type: String
    let ms: Double
    
    init(type: String = "delay", ms: Double) {
        self.type = type
        self.ms = ms
    }
}

struct PixelStateTransition: Codable, Equatable {
    let type: String
    let position: Point
    let color: RGB
    let threshold: Double
    
    init(type: String = "pixel-state", position: Point, color: RGB, threshold: Double) {
        self.type = type
        self.position = position
        self.color = color
        self.threshold = threshold
    }
}

struct PixelZoneTransition: Codable, Equatable {
    let type: String
    let rect: Rect
    let color: RGB
    let threshold: Double
    
    init(type: String = "pixel-zone", rect: Rect, color: RGB, threshold: Double) {
        self.type = type
        self.rect = rect
        self.color = color
        self.threshold = threshold
    }
}

struct ScenarioRef: Codable, Equatable {
    let type: String
    let scenarioId: String
    
    init(type: String = "scenario-ref", scenarioId: String) {
        self.type = type
        self.scenarioId = scenarioId
    }
}

// MARK: - Scenario

struct Scenario: Codable, Equatable {
    let id: String
    let name: String
    let steps: [Step]
    let createdAt: Double
    let lastUsedAt: Double
    
    init(id: String, name: String, steps: [Step], createdAt: Double, lastUsedAt: Double) {
        self.id = id
        self.name = name
        self.steps = steps
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

// MARK: - Settings

struct Settings: Codable {
    var lastOverlayPosition: Point?
    var defaultThreshold: Double
    var pollIntervalMs: Double
    
    init(
        lastOverlayPosition: Point? = nil,
        defaultThreshold: Double = 15,
        pollIntervalMs: Double = 50
    ) {
        self.lastOverlayPosition = lastOverlayPosition
        self.defaultThreshold = defaultThreshold
        self.pollIntervalMs = pollIntervalMs
    }
}
