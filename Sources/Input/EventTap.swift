import CoreGraphics
import Foundation

/// A listen-only CGEventTap for global mouse movement and button events.
/// Requires Accessibility (or Input Monitoring) access; `start()` returns
/// false when the tap cannot be created (surfaces as RMB-IN-001).
public final class EventTap {
    /// Mouse position in CG global coordinates.
    public var onMouseMoved: ((CGPoint) -> Void)?
    /// Button index (0 = left, 1 = right, 2 = middle, 3/4 = back/forward), pressed state.
    public var onMouseButton: ((Int, Bool) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public var isRunning: Bool { tap != nil }

    public init() {}

    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.mouseMoved.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                if let refcon {
                    let owner = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                    owner.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        runLoopSource = source
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .mouseMoved:
            onMouseMoved?(event.location)
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp:
            let isDown = type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown
            let button: Int
            switch type {
            case .leftMouseDown, .leftMouseUp:
                button = 0
            case .rightMouseDown, .rightMouseUp:
                button = 1
            default:
                button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            }
            onMouseButton?(button, isDown)
        default:
            break
        }
    }
}
