import Foundation
import ApplicationServices

let accessibility = AXUIElementCreateSystemWide()
let skylight = SLSMainConnectionID()

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

func getpsn(_ window: CGWindowID) -> ProcessSerialNumber? {
  var cid = Int32()
  var psn = ProcessSerialNumber()

  if SLSGetWindowOwner(skylight, window, &cid) == .success
      && SLSGetConnectionPSN(cid, &psn) == .success {
    return psn
  }
  return nil
}

func focused() -> CGWindowID? {
  var value: CFTypeRef?
  var window = CGWindowID()

  if let front = NSWorkspace.shared.frontmostApplication {
    let application = AXUIElementCreateApplication(front.processIdentifier)
    if AXUIElementCopyAttributeValue(application,
          kAXFocusedWindowAttribute as CFString, &value) == .success,
        let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
      let element = unsafeBitCast(value, to: AXUIElement.self)
      if _AXUIElementGetWindow(element, &window) == .success {
        return window
      }
    }
  }
  return nil
}

func target() -> CGWindowID? {
  if let point = CGEvent(source: nil)?.location {
    var element: AXUIElement? = nil
    AXUIElementCopyElementAtPosition(accessibility,
      Float(point.x), Float(point.y), &element)

    while element != nil {
      var value: CFTypeRef?
      var window = CGWindowID()

      if _AXUIElementGetWindow(element!, &window) == .success {
        return window
      }

      if AXUIElementCopyAttributeValue(element!,
            kAXParentAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
        element = unsafeBitCast(value, to: AXUIElement.self)
      } else {
        break
      }
    }
  }
  return nil
}

func focus() {
  if let window = target(), var psn = getpsn(window) {
    if active(psn) {
      guard let focusedwindow = focused(), focusedwindow != window else {
        return
      }

      var msg = [UInt8](repeating: 0, count: 0x100)
      msg[0x04] = 0xf8
      msg[0x08] = 0x0d

      msg[0x3c...0x3f] = focusedwindow.littleEndianBytes
      msg[0x8a] = 0x02 // Deactivate window
      SLPSPostEventRecordTo(&psn, &msg)

      msg[0x3c...0x3f] = window.littleEndianBytes
      msg[0x8a] = 0x01 // Activate window
      SLPSPostEventRecordTo(&psn, &msg)
    } else {
      _SLPSSetFrontProcessWithOptions(&psn, window, kCPSUserGenerated)
    }

    var msg = [UInt8](repeating: 0, count: 0x100)
    msg[0x04] = 0xf8
    msg[0x20...0x2f] = ArraySlice<UInt8>(repeating: 0xff, count: 16)
    msg[0x3a] = 0x10
    msg[0x3c...0x3f] = window.littleEndianBytes

    msg[0x08] = 0x01 // Synthetic mouse down
    SLPSPostEventRecordTo(&psn, &msg)

    msg[0x08] = 0x02 // Synthetic mouse up
    SLPSPostEventRecordTo(&psn, &msg)
  }
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
    place: .headInsertEventTap, options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: { _, type, event, _ in
      switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
          exit(EXIT_FAILURE)
        case .keyDown:
          if event.getIntegerValueField(.keyboardEventKeycode) == 179 {
            focus()
          }
        default:
          break
      }
      return Unmanaged.passRetained(event)
    }, userInfo: nil) else {
  fputs("Failed to create event tap\n", stderr)
  exit(EXIT_FAILURE)
}

CFRunLoopAddSource(CFRunLoopGetCurrent(),
  CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
RunLoop.main.run()
