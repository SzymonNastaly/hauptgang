import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            Color.hauptgangBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Logo and title
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Hauptgang")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(.hauptgangTextPrimary)

                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(.hauptgangTextSecondary)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Form
                    VStack(spacing: Theme.Spacing.lg) {
                        // Email field
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Email")
                                .font(.footnote)
                                .foregroundColor(.hauptgangTextSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            TextField("Enter your email", text: self.$viewModel.email)
                                .themeTextField(isError: self.viewModel.emailError != nil)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused(self.$focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { self.focusedField = .password }

                            if let error = viewModel.emailError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.hauptgangError)
                            }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Password")
                                .font(.footnote)
                                .foregroundColor(.hauptgangTextSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            SecureField("Enter your password", text: self.$viewModel.password)
                                .themeTextField()
                                .textContentType(.password)
                                .focused(self.$focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { self.submitForm() }
                        }

                        // Error message
                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.hauptgangError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Sign in button
                        Button(action: self.submitForm) {
                            HStack(spacing: Theme.Spacing.sm) {
                                if self.viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(self.viewModel.isLoading ? "Signing in…" : "Sign In")
                            }
                        }
                        .primaryButton()
                        .disabled(!self.viewModel.isFormValid || self.viewModel.isLoading)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .onTapGesture {
            self.focusedField = nil
        }
    }

    private func submitForm() {
        guard self.viewModel.isFormValid, !self.viewModel.isLoading else { return }
        self.focusedField = nil

        Task {
            await self.viewModel.login(authManager: self.authManager)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
