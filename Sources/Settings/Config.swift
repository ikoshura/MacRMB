import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The four keys held to emulate the right stick (bound in the emulator's
/// input configuration). Field order mirrors the engine's
/// `RIGHT_STICK_KEYS[4]` layout: [left, right, up, down].
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

    /// Upstream default — J/L/I/K, the common right-stick mapping
    /// (Ryujinx: RStick Left=J, Right=L, Up=I, Down=K).
    public static let ijkl = DirectionKeys(
        up: UInt16(kVK_ANSI_I),
        down: UInt16(kVK_ANSI_K),
        left: UInt16(kVK_ANSI_J),
        right: UInt16(kVK_ANSI_L)
    )

    /// Engine order: [0]=left, [1]=right, [2]=up, [3]=down.
    public var engineArray: [Int] {
        [Int(left), Int(right), Int(up), Int(down)]
    }
}

public struct Config: Codable, Equatable {
    public static let `default` = Config()

    /// Config format version. Files without the key decode as 0 (legacy).
    /// v1 = first Swift release (px deadzone), v2 = upstream engine semantics.
    public var version: Int = 2

    /// Window title or app name substring to track (e.g. "Ryujinx").
    public var targetName: String

    // Upstream analog parameters (see NpadController::SanatizeAxes).
    public var sensitivity: Double   // 1…30, default 10 (engine ×0.0044 scale)
    public var deadzone: Double      // 0…0.9 radial deadzone, default 0.15
    public var range: Double         // 0.5…1.5, default 0.95
    public var threshold: Double     // 0…1 axis press threshold, default 0.5
    public var stickOffsetX: Double  // -0.75…0.75 stick-axis bias
    public var stickOffsetY: Double

    // Behavior toggles (engine Config flags).
    public var hideCursor: Bool
    public var autoFocus: Bool
    public var bindMouseButtons: Bool
    public var persistentKeyPress: Bool
    /// Check for app updates automatically (Sparkle).
    public var checkForUpdatesAutomatically: Bool

    // Input mapping (CGKeyCode values).
    public var directions: DirectionKeys
    /// Mouse button index (0 = left, 1 = right, 2 = middle) → key held while pressed.
    public var bindings: [Int: UInt16]

    // Global toggle hotkey (Carbon: virtual key code + Carbon modifier mask).
    public var hotkeyKey: UInt16
    public var hotkeyModifiers: Int

    public init(
        targetName: String = "Ryujinx",
        sensitivity: Double = 10,
        deadzone: Double = 0.15,
        range: Double = 0.95,
        threshold: Double = 0.5,
        stickOffsetX: Double = 0,
        stickOffsetY: Double = 0,
        hideCursor: Bool = true,
        autoFocus: Bool = true,
        bindMouseButtons: Bool = true,
        persistentKeyPress: Bool = false,
        checkForUpdatesAutomatically: Bool = true,
        directions: DirectionKeys = .ijkl,
        bindings: [Int: UInt16] = [:],
        hotkeyKey: UInt16 = UInt16(kVK_ANSI_P),
        hotkeyModifiers: Int = cmdKey | optionKey
    ) {
        self.targetName = targetName
        self.sensitivity = sensitivity
        self.deadzone = deadzone
        self.range = range
        self.threshold = threshold
        self.stickOffsetX = stickOffsetX
        self.stickOffsetY = stickOffsetY
        self.hideCursor = hideCursor
        self.autoFocus = autoFocus
        self.bindMouseButtons = bindMouseButtons
        self.persistentKeyPress = persistentKeyPress
        self.checkForUpdatesAutomatically = checkForUpdatesAutomatically
        self.directions = directions
        self.bindings = bindings
        self.hotkeyKey = hotkeyKey
        self.hotkeyModifiers = hotkeyModifiers
    }

    private enum CodingKeys: String, CodingKey {
        case version, targetName, sensitivity, deadzone, range, threshold
        case stickOffsetX, stickOffsetY, hideCursor, autoFocus
        case bindMouseButtons, persistentKeyPress, checkForUpdatesAutomatically
        case directions, bindings, hotkeyKey, hotkeyModifiers
    }

    /// Lenient decoding: unknown or missing fields fall back to defaults so
    /// older config files keep working across versions.
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        targetName = try c.decodeIfPresent(String.self, forKey: .targetName) ?? targetName
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? sensitivity
        deadzone = try c.decodeIfPresent(Double.self, forKey: .deadzone) ?? deadzone
        range = try c.decodeIfPresent(Double.self, forKey: .range) ?? range
        threshold = try c.decodeIfPresent(Double.self, forKey: .threshold) ?? threshold
        stickOffsetX = try c.decodeIfPresent(Double.self, forKey: .stickOffsetX) ?? stickOffsetX
        stickOffsetY = try c.decodeIfPresent(Double.self, forKey: .stickOffsetY) ?? stickOffsetY
        hideCursor = try c.decodeIfPresent(Bool.self, forKey: .hideCursor) ?? hideCursor
        autoFocus = try c.decodeIfPresent(Bool.self, forKey: .autoFocus) ?? autoFocus
        bindMouseButtons = try c.decodeIfPresent(Bool.self, forKey: .bindMouseButtons) ?? bindMouseButtons
        persistentKeyPress = try c.decodeIfPresent(Bool.self, forKey: .persistentKeyPress) ?? persistentKeyPress
        checkForUpdatesAutomatically = try c.decodeIfPresent(Bool.self, forKey: .checkForUpdatesAutomatically) ?? checkForUpdatesAutomatically
        directions = try c.decodeIfPresent(DirectionKeys.self, forKey: .directions) ?? directions
        bindings = try c.decodeIfPresent([Int: UInt16].self, forKey: .bindings) ?? bindings
        hotkeyKey = try c.decodeIfPresent(UInt16.self, forKey: .hotkeyKey) ?? hotkeyKey
        hotkeyModifiers = try c.decodeIfPresent(Int.self, forKey: .hotkeyModifiers) ?? hotkeyModifiers
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

    /// Returns the saved config (after migration), or `.default` when the
    /// file is missing/unreadable.
    public func load() -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return .default }
        return ConfigStore.migrate(config)
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

    /// One-time migrations for configs written by older releases.
    static func migrate(_ config: Config) -> Config {
        var config = config
        if config.version < 2 {
            // v1 used px deadzone/sensitivity semantics; adopt the upstream
            // engine's normalized parameters and defaults. (Pin offsets and
            // everything user-facing were already carried over at decode time.)
            config.sensitivity = Config.default.sensitivity
            config.deadzone = Config.default.deadzone
            config.range = Config.default.range
            config.threshold = Config.default.threshold
            config.stickOffsetX = 0
            config.stickOffsetY = 0
            config.autoFocus = true
            config.bindMouseButtons = true
            config.persistentKeyPress = false
            config.version = 2
        }
        return config
    }
}

