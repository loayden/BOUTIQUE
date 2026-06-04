import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let allowsClose: Bool

    init(allowsClose: Bool = true) {
        self.allowsClose = allowsClose
    }

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignup = false
    @State private var attemptedSubmit = false
    @State private var authDidComplete = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop()

                PhoneScrollScreen { viewport in
                    VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                        AuthHeader(
                            eyebrow: "Private Client",
                            title: "Sign in to keep checkout, saved pieces, and order history in sync.",
                            subtitle: "Keep saved pieces, delivery details, and order history ready the moment you return."
                        )

                        AuthSignalStrip()

                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 16) {
                                BrandField(
                                    title: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress,
                                    submitLabel: .next,
                                    autocapitalization: .never,
                                    isRequired: true,
                                    errorMessage: emailValidationMessage
                                )

                                AuthSecureField(
                                    title: "Password",
                                    text: $password,
                                    textContentType: .password,
                                    submitLabel: .go,
                                    errorMessage: passwordValidationMessage,
                                    onSubmit: {
                                        if canSubmit {
                                            Task { await login() }
                                        }
                                    }
                                )
                            }

                            if let errorMessage {
                                AuthMessageBanner(title: "Sign-in unavailable", message: errorMessage)
                            }

                            Button {
                                Task { await login() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isLoading {
                                        ProgressView()
                                            .tint(Color.boutCreamTop)
                                    } else {
                                        Image(systemName: "lock.open.display")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Sign In")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                            .disabled(!canSubmit || isLoading)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Need an account?")
                                    .font(BrandFont.mobileTitle3())
                                    .foregroundStyle(BrandPalette.textPrimary)

                                Button {
                                    guard !isLoading, !authDidComplete else { return }
                                    showSignup = true
                                } label: {
                                    HStack {
                                        Text("Create Account")
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(BrandFont.mobileBody())
                                    .foregroundStyle(BrandPalette.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 52)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(BrandPalette.surfaceRaised)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoading || authDidComplete)
                            }
                        }
                        .padding(20)
                        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)

                        AuthTrustNote()
                    }
                    .padding(viewport.horizontalPadding)
                    .padding(.bottom, 80)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowsClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundStyle(BrandPalette.textSecondary)
                    }
                }
            }
            .sheet(isPresented: signupPresentationBinding) {
                SignupView()
            }
        }
    }

    private var canSubmit: Bool {
        emailValidationMessage == nil && passwordValidationMessage == nil && !normalizedEmail.isEmpty && !password.isEmpty
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var signupPresentationBinding: Binding<Bool> {
        Binding(
            get: { showSignup && !isLoading && !authDidComplete },
            set: { showSignup = $0 }
        )
    }

    private var emailValidationMessage: String? {
        if normalizedEmail.isEmpty {
            return attemptedSubmit ? "Email is required." : nil
        }

        let isValid = normalizedEmail.contains("@") && normalizedEmail.split(separator: "@").last?.contains(".") == true
        return isValid ? nil : "Enter a valid email address."
    }

    private var passwordValidationMessage: String? {
        if password.isEmpty {
            return attemptedSubmit ? "Password is required." : nil
        }

        return nil
    }

    private func login() async {
        attemptedSubmit = true
        email = normalizedEmail
        guard canSubmit else { return }
        showSignup = false
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIService.shared.login(email: normalizedEmail, password: password)
            authDidComplete = true
            showSignup = false
            store.login(user: response.user, token: response.token ?? "")
            dismiss()
        } catch {
            errorMessage = loginErrorMessage(for: error)
        }
    }

    private func loginErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "Email or password is incorrect."
            case .notFound, .serverError:
                return "We couldn't verify these credentials right now. Try again shortly or create an account first."
            case .networkError:
                let (_, message, suggestion) = AppErrorHandler.categorize(error)
                return [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
            default:
                break
            }
        }

        let (_, message, suggestion) = AppErrorHandler.categorize(error)
        let fallback = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return fallback.isEmpty ? error.localizedDescription : fallback
    }
}

struct SignupView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var attemptedSubmit = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop()
                
                PhoneScrollScreen { viewport in
                    VStack(alignment: .leading, spacing: BrandSpacing.xl) {
                        AuthHeader(
                            eyebrow: "Create Account",
                            title: "Set up your client profile once, then keep bag, address, and checkout data ready.",
                            subtitle: "Create your account once, then move through saved pieces, checkout, and orders with less friction."
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            BrandField(
                                title: "Full Name",
                                text: $name,
                                textContentType: .name,
                                isRequired: true,
                                errorMessage: nameValidationMessage
                            )

                            BrandField(
                                title: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress,
                                autocapitalization: .never,
                                isRequired: true,
                                errorMessage: emailValidationMessage
                            )

                            BrandField(
                                title: "Phone",
                                text: $phone,
                                keyboardType: .phonePad,
                                textContentType: .telephoneNumber,
                                autocapitalization: .never,
                                errorMessage: phoneValidationMessage
                            )
                            .onChange(of: phone) { _, newValue in
                                let formatted = newValue.formattedBoutPhone
                                if formatted != newValue {
                                    phone = formatted
                                }
                            }

                            AuthSecureField(
                                title: "Password",
                                text: $password,
                                textContentType: .newPassword,
                                submitLabel: .next,
                                errorMessage: passwordValidationMessage
                            )
                            AuthSecureField(
                                title: "Confirm Password",
                                text: $confirmPassword,
                                textContentType: .newPassword,
                                submitLabel: .go,
                                errorMessage: confirmPasswordValidationMessage,
                                onSubmit: {
                                    if isValid {
                                        Task { await signup() }
                                    }
                                }
                            )
                        }
                        .padding(18)
                        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)

                        if let errorMessage {
                            AuthMessageBanner(title: "Account setup unavailable", message: errorMessage)
                        }

                        Button {
                            Task { await signup() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(BrandPalette.textPrimary)
                                } else {
                                    Text("Create Account")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                        .disabled(!isValid || isLoading)

                        Text("By creating an account, you agree to the boutique terms and privacy policy.")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(viewport.horizontalPadding)
                    .padding(.bottom, 80)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.textSecondary)
                }
            }
        }
    }

    private var isValid: Bool {
        nameValidationMessage == nil &&
        emailValidationMessage == nil &&
        phoneValidationMessage == nil &&
        passwordValidationMessage == nil &&
        confirmPasswordValidationMessage == nil &&
        !trimmedName.isEmpty &&
        !normalizedEmail.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var nameValidationMessage: String? {
        if trimmedName.isEmpty {
            return attemptedSubmit ? "Full name is required." : nil
        }

        return trimmedName.count < 2 ? "Enter your full name." : nil
    }

    private var emailValidationMessage: String? {
        if normalizedEmail.isEmpty {
            return attemptedSubmit ? "Email is required." : nil
        }

        let isValid = normalizedEmail.contains("@") && normalizedEmail.split(separator: "@").last?.contains(".") == true
        return isValid ? nil : "Enter a valid email address."
    }

    private var phoneValidationMessage: String? {
        guard !phone.isEmpty else { return nil }
        return phone.phoneDigits.count >= 11 && phone.phoneDigits.hasPrefix("01") ? nil : "Enter a valid mobile number."
    }

    private var passwordValidationMessage: String? {
        if password.isEmpty {
            return attemptedSubmit ? "Password is required." : nil
        }

        return password.count >= 8 ? nil : "Use at least 8 characters."
    }

    private var confirmPasswordValidationMessage: String? {
        if confirmPassword.isEmpty {
            return attemptedSubmit ? "Confirm your password." : nil
        }

        return password == confirmPassword ? nil : "Passwords do not match."
    }

    private func signup() async {
        attemptedSubmit = true
        name = trimmedName
        email = normalizedEmail
        guard isValid else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIService.shared.signup(
                name: trimmedName,
                email: normalizedEmail,
                password: password,
                confirmPassword: confirmPassword,
                phone: phone.phoneDigits.isEmpty ? nil : phone.phoneDigits
            )
            store.login(user: response.user, token: response.token ?? "")
            dismiss()
        } catch {
            let (_, message, suggestion) = AppErrorHandler.categorize(error)
            let fallback = [message, suggestion].filter { !$0.isEmpty }.joined(separator: "\n\n")
            errorMessage = fallback.isEmpty ? error.localizedDescription : fallback
        }
    }
}

private struct AuthHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased())
                .font(BrandFont.mobileCaption())
                .tracking(3)
                .foregroundStyle(BrandPalette.gold)

            Text(title)
                .font(BrandFont.serif(34, relativeTo: .largeTitle))
                .foregroundStyle(BrandPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AuthSignalStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            AuthSignalPill(icon: "shippingbox", title: "Saved bag")
            AuthSignalPill(icon: "mappin.and.ellipse", title: "Addresses")
            AuthSignalPill(icon: "checkmark.shield", title: "Secure checkout")
        }
    }
}

private struct AuthSignalPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandPalette.gold)

            Text(title)
                .font(BrandFont.mobileCaption2())
                .foregroundStyle(BrandPalette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 12)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct AuthTrustNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandPalette.gold)
                .padding(.top, 2)

            Text("Account access keeps your checkout progress, saved products, and delivery details available across sessions.")
                .font(BrandFont.mobileCaption())
                .foregroundStyle(BrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surfaceRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
        )
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .go
    var errorMessage: String? = nil
    var onSubmit: (() -> Void)? = nil

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(BrandFont.mobileCaption())
                .tracking(3)
                .foregroundStyle(BrandPalette.textMuted)

            HStack(spacing: 10) {
                Group {
                    if isRevealed {
                        TextField(title, text: $text)
                    } else {
                        SecureField(title, text: $text)
                    }
                }
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(DarkTextFieldStyle())
                .submitLabel(submitLabel)
                .onSubmit {
                    onSubmit?()
                }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(BrandPalette.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(BrandFont.mobileCaption())
                    .foregroundStyle(Color.red.opacity(0.88))
            }
        }
    }
}

private struct AuthMessageBanner: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BrandFont.mobileCaption())
                .tracking(1.8)
                .foregroundStyle(BrandPalette.gold)

            Text(message)
                .font(BrandFont.mobileBody())
                .foregroundStyle(BrandPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.goldBorder, lineWidth: 0.5)
        )
    }
}

private extension String {
    var formattedBoutPhone: String {
        String(phoneDigits.prefix(11))
    }
}
