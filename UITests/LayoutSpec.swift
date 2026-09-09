import Foundation
import XCTest

/// A declarative layout assertion loaded from `UITests/Specs/*.json`.
///
/// Frames are written in **reference points** — the 393x852 pt space the captures in
/// `Reference/` were taken in — and scaled to whatever device is running, so a spec
/// does not have to be re-recorded per simulator.
struct LayoutSpec: Decodable {
    struct Frame: Decodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var rect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    /// How to find the element. XCUITest does not surface the identifier set on a
    /// `.tabItem`, so tab bar buttons are matched by their visible label.
    enum Query: String, Decodable {
        case identifier
        case tabBarButton
        case staticText
        case button
    }

    struct Element: Decodable {
        let name: String
        let query: Query
        let frame: Frame
        let tolerance: Double?
        /// Assert the element exists but do not check its frame.
        let existenceOnly: Bool?
    }

    /// Reference space these frames were recorded in.
    struct Reference: Decodable {
        let width: Double
        let height: Double
    }

    let id: String
    let route: String
    let appearance: String
    let reference: Reference
    let tolerance: Double
    let elements: [Element]

    static func loadAll(in bundle: Bundle = Bundle(for: LayoutSpecTests.self)) throws -> [LayoutSpec] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        return try urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url -> LayoutSpec? in
                let data = try Data(contentsOf: url)
                // Specs are the only JSON in the UI test bundle, but be defensive.
                return try? decoder.decode(LayoutSpec.self, from: data)
            }
    }
}

extension XCUIApplication {
    func element(for element: LayoutSpec.Element) -> XCUIElement {
        switch element.query {
        case .identifier:
            descendants(matching: .any).matching(identifier: element.name).firstMatch
        case .tabBarButton:
            tabBars.buttons[element.name]
        case .staticText:
            staticTexts[element.name]
        case .button:
            buttons[element.name]
        }
    }
}
