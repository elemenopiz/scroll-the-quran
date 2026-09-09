import DesignSystem
import SwiftUI

/// Wraps the DesignSystem component gallery so the app target can route
/// `--screenshot gallery` to it without importing DesignSystem directly.
public struct GalleryScreen: View {
    public init() {}
    public var body: some View { ComponentGallery() }
}
