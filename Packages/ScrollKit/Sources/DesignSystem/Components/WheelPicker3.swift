import SwiftUI

/// A three-column wheel, the shape iOS uses for reminder times and plan pacing.
/// Each column is an independent `Picker` in `.wheel` style so we inherit the system
/// haptics and accessibility, wrapped so the three read as one control.
public struct WheelPicker3: View {
    /// One column: a title used for VoiceOver, and its option labels.
    public struct Column: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let options: [String]

        public init(id: String, title: String, options: [String]) {
            self.id = id
            self.title = title
            self.options = options
        }
    }

    private let columns: [Column]
    @Binding private var selection: [Int]
    private let identifierPrefix: String

    /// `selection` holds one index per column; it is resized and clamped to the
    /// columns on every layout so a stale binding can never index out of bounds.
    public init(identifierPrefix: String, columns: [Column], selection: Binding<[Int]>) {
        self.identifierPrefix = identifierPrefix
        self.columns = columns
        _selection = selection
    }

    /// Fits `selection` to `columns`: pads with zeros, drops extras, clamps each index.
    static func normalized(_ selection: [Int], for columns: [Column]) -> [Int] {
        columns.enumerated().map { index, column in
            guard column.options.isEmpty else {
                let raw = index < selection.count ? selection[index] : 0
                return min(max(raw, 0), column.options.count - 1)
            }
            return 0
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                Picker(column.title, selection: binding(for: index)) {
                    // The offset is the option's identity: `selection` stores indices,
                    // and a column's options are a fixed list for the life of the wheel.
                    ForEach(Array(column.options.enumerated()), id: \.offset) { optionIndex, option in
                        Text(option)
                            .font(.body(18, weight: .medium))
                            .tag(optionIndex)
                    }
                }
                .modifier(WheelStyle())
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityIdentifier("\(identifierPrefix).\(column.id)")
            }
        }
        .frame(height: Metrics.wheelHeight)
        .onAppear { normalize() }
        .onChange(of: columns.map(\.options.count)) { normalize() }
    }

    private func binding(for index: Int) -> Binding<Int> {
        Binding(
            get: { WheelPicker3.normalized(selection, for: columns)[index] },
            set: { newValue in
                var next = WheelPicker3.normalized(selection, for: columns)
                next[index] = newValue
                selection = next
            }
        )
    }

    private func normalize() {
        let next = WheelPicker3.normalized(selection, for: columns)
        if next != selection {
            selection = next
        }
    }
}

/// `.wheel` only exists on iOS/watchOS; the package also builds for macOS (host tests).
private struct WheelStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS) || os(watchOS)
            content.pickerStyle(.wheel)
        #else
            content.pickerStyle(.inline)
        #endif
    }
}

#Preview("WheelPicker3 light") {
    WheelPicker3Previews().preferredColorScheme(.light)
}

#Preview("WheelPicker3 dark") {
    WheelPicker3Previews().preferredColorScheme(.dark)
}

private struct WheelPicker3Previews: View {
    @State private var selection = [7, 30, 1]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            CapsLabel(text: "Daily reminder")
            WheelPicker3(
                identifierPrefix: "gallery.wheel",
                columns: [
                    .init(id: "hour", title: "Hour", options: (1 ... 12).map(String.init)),
                    .init(id: "minute", title: "Minute", options: stride(from: 0, to: 60, by: 5)
                        .map { String(format: "%02d", $0) }),
                    .init(id: "period", title: "Period", options: ["AM", "PM"]),
                ],
                selection: $selection
            )
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
