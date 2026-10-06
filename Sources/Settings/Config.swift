import Foundation

/// The four keys held to emulate the right stick (bound in the emulator's
/// input configuration). Defaults are the arrow keys (virtual key codes
/// kVK_UpArrow 126, kVK_DownArrow 125, kVK_LeftArrow 123, kVK_RightArrow 124).
public struct DirectionKeys: Codable, Equatable {
    public var up: UInt16
    public var down: UInt16
    public var left: UInt16
    public var right: UInt16

    public init(up: UInt16, down: UInt16, left: UInt16, right: UInt16) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    public static let arrows = DirectionKeys(up: 126, down: 125, left: 123, right: 124)
}

public struct Config: Codable, Equatable {
    /// Window title or app name to track (e.g. "Ryujinx").
    public var targetName: String
    /// px (after sensitivity) the cursor must move from center before input starts.
    public var deadzone: Double
    /// 0.1 … 3.0 multiplier applied to mouse deltas.
    public var sensitivity: Double
    /// px offsets shifting the pin center from the window center.
    public var offsetX: Double
    public var offsetY: Double
    public var invertY: Bool
    public var hideCursor: Bool
    public var directions: DirectionKeys
    /// Mouse button index (0 = left, 1 = right, 2 = middle, 3/4 = back/forward)
    /// → virtual key code held while that button is pressed.
    public var bindings: [Int: UInt16]

    public init(
        targetName: String = "Ryujinx",
        deadzone: Double = 12,
        sensitivity: Double = 1.0,
        offsetX: Double = 0,
        offsetY: Double = 0,
        invertY: Bool = false,
        hideCursor: Bool = true,
        directions: DirectionKeys = .arrows,
        bindings: [Int: UInt16] = [:]
    ) {
        self.targetName = targetName
        self.deadzone = deadzone
        self.sensitivity = sensitivity
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.invertY = invertY
        self.hideCursor = hideCursor
        self.directions = directions
        self.bindings = bindings
    }

    public static let `default` = Config()

    private enum CodingKeys: String, CodingKey {
        case targetName, deadzone, sensitivity, offsetX, offsetY, invertY, hideCursor, directions, bindings
    }

    /// Lenient decoding: unknown or missing fields fall back to defaults so
    /// older config files keep working across versions.
    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetName = try container.decodeIfPresent(String.self, forKey: .targetName) ?? targetName
        deadzone = try container.decodeIfPresent(Double.self, forKey: .deadzone) ?? deadzone
        sensitivity = try container.decodeIfPresent(Double.self, forKey: .sensitivity) ?? sensitivity
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? offsetX
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? offsetY
        invertY = try container.decodeIfPresent(Bool.self, forKey: .invertY) ?? invertY
        hideCursor = try container.decodeIfPresent(Bool.self, forKey: .hideCursor) ?? hideCursor
        directions = try container.decodeIfPresent(DirectionKeys.self, forKey: .directions) ?? directions
        bindings = try container.decodeIfPresent([Int: UInt16].self, forKey: .bindings) ?? bindings
    }
}

/// Loads/saves `Config` as JSON in ~/Library/Application Support/RMB/config.json.
public final class ConfigStore {
    public let url: URL

    public init(url: URL = ConfigStore.defaultURL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("RMB/config.json")
    }

    /// Returns the saved config, or `.default` when the file is missing/unreadable.
    public func load() -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return .default }
        return config
    }

    public func save(_ config: Config) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
