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

                            TextField("Enter your email", text: $viewModel.email)
                                .themeTextField(isError: viewModel.emailError != nil)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }

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

                            SecureField("Enter your password", text: $viewModel.password)
                                .themeTextField()
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { submitForm() }
                        }

                        // Error message
                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.hauptgangError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Sign in button
                        Button(action: submitForm) {
                            HStack(spacing: Theme.Spacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(viewModel.isLoading ? "Signing in…" : "Sign In")
                            }
                        }
                        .primaryButton()
                        .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    private func submitForm() {
        guard viewModel.isFormValid, !viewModel.isLoading else { return }
        focusedField = nil

        Task {
            await viewModel.login(authManager: authManager)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
