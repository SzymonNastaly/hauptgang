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
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundColor(.hauptgangPrimary)

                        Text("Hauptgang")
                            .font(.largeTitle)
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
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.hauptgangTextPrimary)

                            TextField("you@example.com", text: $viewModel.email)
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
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.hauptgangTextPrimary)

                            SecureField("Enter your password", text: $viewModel.password)
                                .themeTextField()
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { submitForm() }
                        }

                        // Error message
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .font(.subheadline)
                            .foregroundColor(.hauptgangError)
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(Color.hauptgangError.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.md)
                        }

                        // Sign in button
                        Button(action: submitForm) {
                            HStack(spacing: Theme.Spacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(viewModel.isLoading ? "Signing in..." : "Sign in")
                            }
                        }
                        .primaryButton()
                        .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Color.hauptgangCard)
                    .cornerRadius(Theme.CornerRadius.lg)
                    .shadow(
                        color: Theme.Shadow.md.color,
                        radius: Theme.Shadow.md.radius,
                        y: Theme.Shadow.md.y
                    )
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
