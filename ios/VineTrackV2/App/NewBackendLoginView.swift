import SwiftUI

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
    @State private var resetEmail: String = ""
    @State private var resetSent: Bool = false
    @State private var resetPin: String = ""
    @State private var resetNewPassword: String = ""
    @State private var resetConfirmPassword: String = ""
    @State private var resetCompleted: Bool = false
    @State private var resetLocalError: String?

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

    private var footerLinks: some View {
        VStack(spacing: 8) {
            if mode == .signIn {
                Button("Forgot password?") {
                    resetEmail = email
                    resetSent = false
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
                if resetCompleted {
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
                    }
                } else {
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
                            Task {
                                resetLocalError = nil
                                await auth.sendPasswordReset(email: resetEmail)
                                resetSent = auth.passwordResetSuccessMessage != nil && auth.errorMessage == nil
                            }
                        } label: {
                            if auth.isLoading && !resetSent {
                                ProgressView()
                            } else {
                                Text(resetSent ? "Resend Code" : "Send Code")
                            }
                        }
                        .disabled(auth.isLoading || resetEmail.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if resetSent {
                        if let success = auth.passwordResetSuccessMessage {
                            Section {
                                Label(success, systemImage: "envelope.badge.fill")
                                    .foregroundStyle(VineyardTheme.leafGreen)
                            }
                        }

                        Section {
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
                            Text("Password must be at least 8 characters.")
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
                        }
                    }

                    if let message = resetLocalError ?? auth.errorMessage {
                        Section {
                            Text(message)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { closeForgotPasswordSheet() }
                }
            }
        }
    }

    private var canSubmitReset: Bool {
        let pinOk = resetPin.trimmingCharacters(in: .whitespaces).count >= 4
        let pwOk = resetNewPassword.count >= 8 && resetNewPassword == resetConfirmPassword
        return pinOk && pwOk
    }

    private func submitPasswordReset() async {
        resetLocalError = nil
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
            pin: resetPin,
            newPassword: resetNewPassword
        )
        if success {
            resetCompleted = true
        }
    }

    private func closeForgotPasswordSheet() {
        showForgotPassword = false
        resetSent = false
        resetCompleted = false
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
