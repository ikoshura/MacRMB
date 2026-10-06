import Carbon.HIToolbox
import CoreGraphics
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

    /// Legacy default (arrow keys) — kept for migration detection only.
    public static let arrows = DirectionKeys(up: 126, down: 125, left: 123, right: 124)
    /// I/K/J/L — matches the common right-stick keyboard mapping
    /// (Ryujinx: RStick Up=I, Down=K, Left=J, Right=L).
    public static let rightStick = DirectionKeys(
        up: UInt16(kVK_ANSI_I),
        down: UInt16(kVK_ANSI_K),
        left: UInt16(kVK_ANSI_J),
        right: UInt16(kVK_ANSI_L)
    )
}

/// Where inside the target window the cursor is pinned while panning.
/// Corners are inset from the window edge so the cursor doesn't sit on
/// border/titlebar hover zones.
public enum AnchorPreset: String, Codable, CaseIterable, Equatable {
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var label: String {
        switch self {
        case .center: return "Window center"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }

    /// Pin point in CG global coordinates (origin top-left). Corners are
    /// inset by `inset` px, clamped so the point always stays inside `frame`.
    public func point(in frame: CGRect, inset: CGFloat = 80) -> CGPoint {
        func corner(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: min(max(x, frame.minX), frame.maxX),
                y: min(max(y, frame.minY), frame.maxY)
            )
        }
        switch self {
        case .center:
            return CGPoint(x: frame.midX, y: frame.midY)
        case .topLeft:
            return corner(frame.minX + inset, frame.minY + inset)
        case .topRight:
            return corner(frame.maxX - inset, frame.minY + inset)
        case .bottomLeft:
            return corner(frame.minX + inset, frame.maxY - inset)
        case .bottomRight:
            return corner(frame.maxX - inset, frame.maxY - inset)
        }
    }
}

public struct Config: Codable, Equatable {
    /// Window title or app name to track (e.g. "Ryujinx").
    public var targetName: String
    /// px (after sensitivity) the cursor must move from center before input starts.
    public var deadzone: Double
    /// 0.1 … 3.0 multiplier applied to mouse deltas.
    public var sensitivity: Double
    /// px offsets shifting the pin point from the chosen anchor.
    public var offsetX: Double
    public var offsetY: Double
    /// Where the cursor is pinned inside the target window.
    public var anchor: AnchorPreset
    public var invertY: Bool
    public var hideCursor: Bool
    public var directions: DirectionKeys
    /// Mouse button index (0 = left, 1 = right, 2 = middle, 3/4 = back/forward)
    /// → virtual key code held while that button is pressed.
    public var bindings: [Int: UInt16]
    /// Config format version. Files without the key decode as 0 (legacy).
    public var version: Int = 1

    public init(
        targetName: String = "Ryujinx",
        deadzone: Double = 12,
        sensitivity: Double = 1.0,
        offsetX: Double = 0,
        offsetY: Double = 0,
        anchor: AnchorPreset = .center,
        invertY: Bool = false,
        hideCursor: Bool = true,
        directions: DirectionKeys = .rightStick,
        bindings: [Int: UInt16] = [:]
    ) {
        self.targetName = targetName
        self.deadzone = deadzone
        self.sensitivity = sensitivity
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.anchor = anchor
        self.invertY = invertY
        self.hideCursor = hideCursor
        self.directions = directions
        self.bindings = bindings
    }

    public static let `default` = Config()

    private enum CodingKeys: String, CodingKey {
        case targetName, deadzone, sensitivity, offsetX, offsetY, anchor, invertY, hideCursor, directions, bindings, version
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
        anchor = try container.decodeIfPresent(AnchorPreset.self, forKey: .anchor) ?? anchor
        invertY = try container.decodeIfPresent(Bool.self, forKey: .invertY) ?? invertY
        hideCursor = try container.decodeIfPresent(Bool.self, forKey: .hideCursor) ?? hideCursor
        directions = try container.decodeIfPresent(DirectionKeys.self, forKey: .directions) ?? directions
        bindings = try container.decodeIfPresent([Int: UInt16].self, forKey: .bindings) ?? bindings
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
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

    /// One-time migrations for configs written by older releases.
    static func migrate(_ config: Config) -> Config {
        var config = config
        if config.version < 1 {
            // v0 (first release) defaulted to the arrow keys, which many
            // emulators map to the left stick (walking). Move to the
            // I/K/J/L right-stick bindings unless the user chose others.
            if config.directions == .arrows {
                config.directions = .rightStick
            }
            config.version = 1
        }
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
