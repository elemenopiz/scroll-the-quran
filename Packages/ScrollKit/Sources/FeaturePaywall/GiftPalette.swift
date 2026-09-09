import DesignSystem
import SwiftUI

/// The gift screens are the only surface in the app painted in the warm paper palette,
/// so the values live next to the views that use them rather than in `Tokens.swift`.
///
/// Every value was sampled from `Reference/gift-closed.png` / `gift-open.png` with
/// `Tools/snapshot/profile`-style probes. They are candidates for promotion into
/// `DesignSystem/Tokens.swift` once that target is unfrozen — see the task report.
enum GiftPalette {
    /// Flat background behind the clouds: `#DED6C0`.
    static let paper = Color(rgb: 0xDED6C0)
    /// Warm cloud highlight: `#F8F4EC`.
    static let cloudWarm = Color(rgb: 0xF8F4EC)
    /// Cool cloud highlight on the right of the sealed envelope: `#EDE9E7`.
    static let cloudCool = Color(rgb: 0xEDE9E7)
    /// Envelope paper front: `#F0E0C2`.
    static let envelopeFront = Color(rgb: 0xF0E0C2)
    /// Envelope flap, one step darker: `#E7D2A9`.
    static let envelopeFlap = Color(rgb: 0xE7D2A9)
    /// Inside of the opened envelope, seen behind the card: `#D9BE8C`.
    static let envelopeLining = Color(rgb: 0xD9BE8C)
    /// Edge shading on folds: `#C8A97A`.
    static let envelopeShade = Color(rgb: 0xC8A97A)
    /// The offer card slipped inside the envelope: `#F5ECDD`.
    static let offerCard = Color(rgb: 0xF5ECDD)
    /// Wax seal gold, light to dark.
    static let sealLight = Color(rgb: 0xD9A94F)
    static let sealMid = Color(rgb: 0xC18A40)
    static let sealDark = Color(rgb: 0x9A6B2C)
    /// Ink on the gift screens: `#2B2B2B`.
    static let ink = Color(rgb: 0x2B2B2B)
    /// Muted copy on the gift screens: `#6B655C`.
    static let inkMuted = Color(rgb: 0x6B655C)
}
