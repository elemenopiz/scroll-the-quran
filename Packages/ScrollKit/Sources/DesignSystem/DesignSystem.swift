import Foundation
#if canImport(CoreText)
    import CoreText
#endif

/// Entry point for the design system. `registerFonts()` is called once from the
/// app's `init` (and from the widget) before any view asks for a bundled face.
public enum DesignSystem {
    public static let moduleName = "DesignSystem"

    /// Font files that ship inside `Bundle.module`, discovered rather than hard-coded
    /// so dropping a new face into `Resources/Fonts` is all it takes.
    public static var bundledFontURLs: [URL] {
        guard let fonts = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: fonts,
                  includingPropertiesForKeys: nil
              )
        else { return [] }
        return contents
            .filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static var didRegister = false

    /// Registers every bundled face with CoreText. Idempotent; safe to call from
    /// the app, the widget extension and previews.
    @discardableResult
    public static func registerFonts() -> [String] {
        #if canImport(CoreText)
            guard !didRegister else { return registeredPostScriptNames }
            didRegister = true
            var registered: [String] = []
            for url in bundledFontURLs {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    registered.append(url.lastPathComponent)
                } else {
                    // Already registered (e.g. also listed in UIAppFonts) is not a failure.
                    error?.release()
                }
            }
            registeredPostScriptNames = registered
            return registered
        #else
            return []
        #endif
    }

    public private(set) static var registeredPostScriptNames: [String] = []
}
