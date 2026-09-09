import DesignSystem
import SwiftUI

/// "Add a Quran Verse Widget": the four steps for putting an ayah on the Lock or Home Screen.
/// There is no API to add a widget for the user, so this is a guide, not a button.
public struct AddWidgetGuide: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Add a widget", showsDivider: true) {
                OutlinePillButton("Done", height: 40) { dismiss() }
                    .frame(width: 92)
                    .accessibilityIdentifier("widgetGuide.done")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("Put an ayah where you already look")
                        .font(.serifDisplay(28, relativeTo: .title))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 0) {
                        ForEach(Array(AddWidgetGuide.steps.enumerated()), id: \.offset) { index, step in
                            TimelineStep(
                                systemImage: step.systemImage,
                                title: step.title,
                                message: step.message,
                                isLast: index == AddWidgetGuide.steps.count - 1
                            )
                        }
                    }

                    Text(
                        "The widget shows the ayah of the day, or the one you pinned. It reads what is already on the device — the app makes no network calls."
                    )
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.huge)
            }
        }
        .background(Color.appBackgroundFlat)
        .accessibilityIdentifier("widget-gallery")
    }

    struct Step {
        let systemImage: String
        let title: String
        let message: String
    }

    static let steps = [
        Step(
            systemImage: "hand.tap",
            title: "Touch and hold",
            message: "Press and hold an empty part of your Home Screen until the icons start to jiggle."
        ),
        Step(
            systemImage: "plus",
            title: "Tap Edit, then Add Widget",
            message: "The button is at the top of the screen."
        ),
        Step(
            systemImage: "magnifyingglass",
            title: "Search for Scroll the Quran",
            message: "Pick it from the list of apps that offer widgets."
        ),
        Step(
            systemImage: "checkmark",
            title: "Choose a size and add it",
            message: "For the Lock Screen, touch and hold the lock screen instead, tap Customise, then add the widget there."
        ),
    ]
}
