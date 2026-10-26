import AppKit

extension NSScreen {
    /// A stable identifier for this display that survives reboots and reconnects.
    var displayUUID: String {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else {
            return localizedName
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
