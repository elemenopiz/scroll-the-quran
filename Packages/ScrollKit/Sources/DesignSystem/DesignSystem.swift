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

    /// Registers every bundled face with CoreText. Idempotent and thread-safe: the
    /// work hangs off a lazily-initialised `static let`, which Swift runs exactly once
    /// under `swift_once`. A hand-rolled `didRegister` flag is not enough — Swift
    /// Testing runs suites in parallel, so a second caller could see the flag set and
    /// start drawing before the first caller had finished registering.
    @discardableResult
    public static func registerFonts() -> [String] {
        registeredFontFiles
    }

    /// File names of the faces CoreText accepted, in bundle order.
    public static var registeredPostScriptNames: [String] {
        registeredFontFiles
    }

    private static let registeredFontFiles: [String] = {
        #if canImport(CoreText)
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
            return registered
        #else
            return []
        #endif
    }()
}
