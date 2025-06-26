import Foundation
import ApplicationServices

let skylight = SLSMainConnectionID()
var current: CGWindowID?
var keys, mouse: CFMachPort?

extension UInt32 {
  var littleEndianBytes: ArraySlice<UInt8> {
    withUnsafeBytes(of: self.littleEndian) {
      return ArraySlice($0)
    }
  }
}

func active(_ psn: ProcessSerialNumber) -> Bool {
  var front = ProcessSerialNumber()
  return _SLPSGetFrontProcess(&front) == .success
    && front.lowLongOfPSN == psn.lowLongOfPSN
    && front.highLongOfPSN == psn.highLongOfPSN
}

func focus() -> CGWindowID? {
  var client = Int32()
  var location = CGPoint()
  var psn = ProcessSerialNumber()
  var window = CGWindowID()

  guard var point = CGEvent(source: nil)?.location,
      SLSFindWindowAndOwner(skylight, 0, 1, 0, &point, &location, &window,
        &client) == .success,
      SLSGetConnectionPSN(client, &psn) == .success else {
    return nil
  }

  if ["Dock", "Emoji & Symbols", "Window Server"].contains(owner(window)) {
    return window
  }

  if active(psn) {
    guard let focused = focused(), focused != window else {
      return window
    }

    var msg = [UInt8](repeating: 0, count: 256)
    msg[0x04] = 0xf8
    msg[0x08] = 0x0d

    msg[0x3c...0x3f] = focused.littleEndianBytes
    msg[0x8a] = 0x02 // Deactivate window
    SLPSPostEventRecordTo(&psn, &msg)

    msg[0x3c...0x3f] = window.littleEndianBytes
    msg[0x8a] = 0x01 // Activate window
    SLPSPostEventRecordTo(&psn, &msg)
  } else {
    _SLPSSetFrontProcessWithOptions(&psn, window, kCPSUserGenerated)
  }

  var msg = [UInt8](repeating: 0, count: 256)
  msg[0x04] = 0xf8
  msg[0x20...0x2f] = ArraySlice<UInt8>(repeating: 0xff, count: 16)
  msg[0x3a] = 0x10
  msg[0x3c...0x3f] = window.littleEndianBytes

  msg[0x08] = 0x01 // Synthetic mouse down
  SLPSPostEventRecordTo(&psn, &msg)

  msg[0x08] = 0x02 // Synthetic mouse up
  SLPSPostEventRecordTo(&psn, &msg)

  return window
}

func focused() -> CGWindowID? {
  var value: CFTypeRef?
  var window = CGWindowID()

  guard let front = NSWorkspace.shared.frontmostApplication else {
    return nil
  }

  var element = AXUIElementCreateApplication(front.processIdentifier)
  guard AXUIElementCopyAttributeValue(element,
          kAXFocusedWindowAttribute as CFString, &value) == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
    return nil
  }

  element = unsafeBitCast(value, to: AXUIElement.self)
  if _AXUIElementGetWindow(element, &window) == .success {
    return window
  }
  return nil
}

func owner(_ window: CGWindowID) -> String? {
  return (CGWindowListCopyWindowInfo([.optionIncludingWindow], window)
    as? [[String: Any]])?.first?[kCGWindowOwnerName as String] as? String
}

keys = CGEvent.tapCreate(tap: .cgSessionEventTap,
  place: .headInsertEventTap, options: .defaultTap,
  eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
  callback: { _, type, event, _ in
    switch type {
      case .tapDisabledByTimeout:
        exit(EXIT_FAILURE)
      case .keyDown:
        current = focus()
        if let keys, let mouse, current != nil {
          CGEvent.tapEnable(tap: keys, enable: false)
          CGEvent.tapEnable(tap: mouse, enable: true)
        }
      default:
        break
    }
    return Unmanaged.passUnretained(event)
  }, userInfo: nil)

mouse = CGEvent.tapCreate(tap: .cgSessionEventTap,
  place: .headInsertEventTap, options: .defaultTap,
  eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
  callback: { _, type, event, _ in
    switch type {
      case .tapDisabledByTimeout:
        exit(EXIT_FAILURE)
      case .mouseMoved:
        var client = Int32(), point = CGPoint(), window = CGWindowID()
        if SLSFindWindowAndOwner(skylight, 0, 1, 0, &event.location,
              &point, &window, &client) == .success,
            let keys, let mouse, current != window {
          CGEvent.tapEnable(tap: keys, enable: true)
          CGEvent.tapEnable(tap: mouse, enable: false)
        }
      default:
        break
    }
    return Unmanaged.passUnretained(event)
  }, userInfo: nil)

guard let keys, let mouse else {
  exit(EXIT_FAILURE)
}

CFRunLoopAddSource(CFRunLoopGetCurrent(),
  CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keys, 0), .commonModes)
CFRunLoopAddSource(CFRunLoopGetCurrent(),
  CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouse, 0), .commonModes)
CGEvent.tapEnable(tap: keys, enable: true)
RunLoop.main.run()
