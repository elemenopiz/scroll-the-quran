import AuthenticationServices
import DesignSystem
import SwiftUI

/// `onboarding-signin`: the bottom sheet over the dimmed hook.
///
/// Real Sign in with Apple — the credential's `user` goes straight to the app's
/// `OnboardingAccountSink`. The email field is optional and local: there is no code to
/// send, no request to make and no fake verification step (`CLAUDE.md` rule 9).
/// Block positions are traced off `Reference/onboarding-signin.png`, where the sheet
/// spans rows 404...843 and its content column runs x 27...365.
struct SignInSheet: View {
    let content: OnboardingContent.SignIn
    @Binding var email: String
    let onAppleSignIn: (ASAuthorizationAppleIDCredential) -> Void
    let onSkip: () -> Void

    @Environment(\.openURL) private var openURL

    private enum Gap {
        static let title: CGFloat = 46
        static let titleToBody: CGFloat = 18
        static let bodyToField: CGFloat = 13
        static let fieldToApple: CGFloat = 19
        static let appleToDivider: CGFloat = 21
        static let dividerToRecover: CGFloat = 25
        static let recoverToFootnote: CGFloat = 15
        static let footnoteToSkip: CGFloat = 16
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(content.title)
                .font(.serifDisplay(OnboardingMetrics.sheetTitleSize, relativeTo: .title))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, Gap.title)
                .accessibilityIdentifier("onboarding.signin.title")

            Text(content.body)
                .font(.body(15))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Gap.titleToBody)

            emailField
                .padding(.top, Gap.bodyToField)

            appleButton
                .padding(.top, Gap.fieldToApple)

            Rectangle()
                .fill(Color.divider)
                .frame(height: Stroke.hairline)
                .padding(.top, Gap.appleToDivider)

            Button {
                if let url = content.recoverURL {
                    openURL(url)
                }
            } label: {
                Text(content.recoverCTA)
                    .font(.body(16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, Gap.dividerToRecover)
            .accessibilityIdentifier("onboarding.signin.recover")

            Text(content.emailFootnote)
                .font(.body(13))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Gap.recoverToFootnote)

            Button(content.skipCTA, action: onSkip)
                .font(.body(16, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .buttonStyle(.plain)
                .padding(.top, Gap.footnoteToSkip)
                .accessibilityIdentifier("onboarding.signin.skip")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OnboardingMetrics.sheetContentInset)
        .background(Color.sheetBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.onboarding-signin")
    }

    private var emailField: some View {
        TextField(content.emailPlaceholder, text: $email)
            .font(.body(17))
            .foregroundStyle(Color.textPrimary)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
        #if os(iOS)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #endif
            .padding(.horizontal, Spacing.lg)
            .frame(height: OnboardingMetrics.fieldHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: OnboardingMetrics.fieldCornerRadius, style: .continuous)
                    .fill(Color.rowBackground)
            )
            .accessibilityLabel(content.emailLabel)
            .accessibilityIdentifier("onboarding.signin.email")
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            guard case let .success(authorisation) = result else { return }
            guard let credential = authorisation.credential as? ASAuthorizationAppleIDCredential else { return }
            onAppleSignIn(credential)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: OnboardingMetrics.sheetButtonHeight)
        .frame(maxWidth: .infinity)
        .clipShape(Capsule())
        .accessibilityIdentifier("onboarding.signin.apple")
    }
}

#Preview("Sign in") {
    SignInSheet(
        content: OnboardingContent.sample.signIn,
        email: .constant(""),
        onAppleSignIn: { _ in },
        onSkip: {}
    )
}
