import SwiftUI
import AuthenticationServices

struct NewBackendLoginView: View {
    @Environment(NewBackendAuthService.self) private var auth

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .signIn
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showForgotPassword: Bool = false
    @State private var resetStep: ResetStep = .enterEmail
    @State private var resetEmail: String = ""
    @State private var resetPin: String = ""
    @State private var resetNewPassword: String = ""
    @State private var resetConfirmPassword: String = ""
    @State private var resetLocalError: String?
    @State private var currentNonce: String?

    private enum ResetStep {
        case enterEmail
        case enterCode
        case completed
    }

    var body: some View {
        ZStack {
            VineyardTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    modePicker
                    formCard
                    actionButton
                    dividerWithOr
                    appleSignInButton
                    footerLinks
                    if let errorMessage = auth.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .padding(.top, 24)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(VineyardTheme.leafGreen.gradient)
                    .frame(width: 80, height: 80)
                GrapeLeafIcon(size: 40, color: .white)
            }
            Text("VineTrackV2")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(VineyardTheme.olive)
            Text("Manage your vineyard, your way.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 8)
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                LoginField(
                    title: "Name",
                    text: $name,
                    icon: "person.fill",
                    contentType: .name,
                    keyboard: .default
                )
            }
            LoginField(
                title: "Email",
                text: $email,
                icon: "envelope.fill",
                contentType: .emailAddress,
                keyboard: .emailAddress,
                autocapitalize: false
            )
            LoginField(
                title: "Password",
                text: $password,
                icon: "lock.fill",
                contentType: mode == .signUp ? .newPassword : .password,
                keyboard: .default,
                autocapitalize: false,
                isSecure: true
            )
        }
        .padding(16)
        .background(VineyardTheme.cardBackground, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VineyardTheme.cardBorder, lineWidth: 0.5)
        )
    }

    private var actionButton: some View {
        Button {
            Task {
                switch mode {
                case .signIn:
                    await auth.signIn(email: email, password: password)
                case .signUp:
                    await auth.signUp(name: name, email: email, password: password)
                }
            }
        } label: {
            if auth.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(mode == .signIn ? "Sign In" : "Create Account")
            }
        }
        .buttonStyle(.vineyardPrimary)
        .disabled(auth.isLoading || !canSubmit)
    }

    private var dividerWithOr: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(VineyardTheme.stone.opacity(0.4))
                .frame(height: 1)
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(VineyardTheme.stone.opacity(0.4))
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = AppleSignInHelper.randomNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInHelper.sha256(nonce)
        } onCompletion: { result in
            handleAppleResult(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(.rect(cornerRadius: 12))
        .disabled(auth.isLoading)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue { return }
            Task { @MainActor in
                auth.errorMessage = error.localizedDescription
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                Task { @MainActor in
                    auth.errorMessage = "Apple did not return a valid identity token."
                }
                return
            }
            let fullName = credential.fullName.flatMap { components -> String? in
                let parts = [components.givenName, components.middleName, components.familyName]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }
            let nonce = currentNonce
            Task {
                await auth.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName)
                currentNonce = nil
            }
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            if mode == .signIn {
                Button("Forgot password?") {
                    resetEmail = email
                    resetStep = .enterEmail
                    resetPin = ""
                    resetNewPassword = ""
                    resetConfirmPassword = ""
                    resetLocalError = nil
                    showForgotPassword = true
                }
                .font(.footnote)
                .foregroundStyle(VineyardTheme.leafGreen)
            }
        }
    }

    private var forgotPasswordSheet: some View {
        NavigationStack {
            Form {
                switch resetStep {
                case .enterEmail:
                    enterEmailSection
                case .enterCode:
                    enterCodeSection
                case .completed:
                    completedSection
                }

                if let message = resetLocalError ?? auth.errorMessage, resetStep != .completed {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resetStep == .completed ? "Close" : "Cancel") {
                        closeForgotPasswordSheet()
                    }
                }
            }
            .interactiveDismissDisabled(resetStep == .enterCode)
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var enterEmailSection: some View {
        Section {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Step 1 — Request Code")
        } footer: {
            Text("We'll email you a 6-digit code. No links — codes only.")
        }

        Section {
            Button {
                Task { await requestResetCode() }
            } label: {
                if auth.isLoading {
                    ProgressView()
                } else {
                    Text("Send Code")
                }
            }
            .disabled(auth.isLoading || resetEmail.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var enterCodeSection: some View {
        if let success = auth.passwordResetSuccessMessage {
            Section {
                Label(success, systemImage: "envelope.badge.fill")
                    .foregroundStyle(VineyardTheme.leafGreen)
            }
        }

        Section {
            HStack {
                Text("Email")
                Spacer()
                Text(resetEmail)
                    .foregroundStyle(.secondary)
            }
            TextField("6-digit code", text: $resetPin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .autocorrectionDisabled()
            SecureField("New password", text: $resetNewPassword)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Confirm new password", text: $resetConfirmPassword)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Step 2 — Enter Code & New Password")
        } footer: {
            Text("Code expires after a short time. Password must be at least 8 characters.")
        }

        Section {
            Button {
                Task { await submitPasswordReset() }
            } label: {
                if auth.isLoading {
                    ProgressView()
                } else {
                    Text("Update Password")
                }
            }
            .disabled(auth.isLoading || !canSubmitReset)

            Button("Resend Code") {
                Task { await requestResetCode() }
            }
            .disabled(auth.isLoading)

            Button("Use a different email") {
                resetStep = .enterEmail
                resetPin = ""
                resetNewPassword = ""
                resetConfirmPassword = ""
                resetLocalError = nil
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        Section {
            Label(
                auth.passwordResetSuccessMessage ?? "Password updated. You can now sign in.",
                systemImage: "checkmark.seal.fill"
            )
            .foregroundStyle(VineyardTheme.leafGreen)
        }
        Section {
            Button("Back to Sign In") {
                password = resetNewPassword
                email = resetEmail
                closeForgotPasswordSheet()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func requestResetCode() async {
        resetLocalError = nil
        let success = await auth.sendPasswordReset(email: resetEmail)
        if success {
            resetStep = .enterCode
        }
    }

    private var canSubmitReset: Bool {
        let pinOk = resetPin.trimmingCharacters(in: .whitespaces).count >= 4
        let pwOk = resetNewPassword.count >= 8 && resetNewPassword == resetConfirmPassword
        return pinOk && pwOk
    }

    private func submitPasswordReset() async {
        resetLocalError = nil
        let trimmedPin = resetPin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPin.count >= 4 else {
            resetLocalError = "Enter the code from your email."
            return
        }
        guard resetNewPassword.count >= 8 else {
            resetLocalError = "Password must be at least 8 characters."
            return
        }
        guard resetNewPassword == resetConfirmPassword else {
            resetLocalError = "Passwords do not match."
            return
        }
        let success = await auth.resetPasswordWithPin(
            email: resetEmail,
            pin: trimmedPin,
            newPassword: resetNewPassword
        )
        if success {
            resetStep = .completed
        }
    }

    private func closeForgotPasswordSheet() {
        showForgotPassword = false
        resetStep = .enterEmail
        resetPin = ""
        resetNewPassword = ""
        resetConfirmPassword = ""
        resetLocalError = nil
    }

    private var canSubmit: Bool {
        let hasEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPassword = !password.isEmpty
        if mode == .signUp {
            return hasEmail && hasPassword && !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return hasEmail && hasPassword
    }
}

private struct LoginField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let contentType: UITextContentType
    let keyboard: UIKeyboardType
    var autocapitalize: Bool = true
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(VineyardTheme.olive)
                .frame(width: 20)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalize ? .sentences : .never)
            .autocorrectionDisabled(!autocapitalize)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VineyardTheme.stone.opacity(0.4), lineWidth: 1)
        )
    }
}
