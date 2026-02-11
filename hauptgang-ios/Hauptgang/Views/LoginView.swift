import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password, passwordConfirmation
    }

    var body: some View {
        ZStack {
            Color.hauptgangBackground
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // App icon and tagline
                VStack(spacing: Theme.Spacing.md) {
                    Image("LoginLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl))

                    (Text("Cook something ")
                        .foregroundColor(.hauptgangTextPrimary)
                    + Text("delicious")
                        .foregroundColor(.hauptgangPrimary)
                        .italic()
                        .underline()
                    + Text(" today")
                        .foregroundColor(.hauptgangTextPrimary))
                        .font(.system(.title2, design: .serif))
                }

                // Form
                VStack(spacing: Theme.Spacing.md) {
                    // Email field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
                        SecureField("Enter your password", text: self.$viewModel.password)
                            .themeTextField()
                            .textContentType(self.viewModel.isSignUp ? .newPassword : .password)
                            .focused(self.$focusedField, equals: .password)
                            .submitLabel(self.viewModel.isSignUp ? .next : .go)
                            .onSubmit {
                                if self.viewModel.isSignUp {
                                    self.focusedField = .passwordConfirmation
                                } else {
                                    self.submitForm()
                                }
                            }

                        if self.viewModel.isSignUp && !self.viewModel.password.isEmpty && self.viewModel.password.count < 12 {
                            Text("Password must be at least 12 characters")
                                .font(.caption)
                                .foregroundColor(.hauptgangError)
                        }
                    }

                    // Password confirmation (signup only)
                    if self.viewModel.isSignUp {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            SecureField("Confirm your password", text: self.$viewModel.passwordConfirmation)
                                .themeTextField(isError: self.viewModel.passwordConfirmationError != nil)
                                .textContentType(.newPassword)
                                .focused(self.$focusedField, equals: .passwordConfirmation)
                                .submitLabel(.go)
                                .onSubmit { self.submitForm() }

                            if let error = viewModel.passwordConfirmationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.hauptgangError)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.hauptgangError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Submit button
                    Button(action: self.submitForm) {
                        HStack(spacing: Theme.Spacing.sm) {
                            if self.viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(self.buttonLabel)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(Color.hauptgangPrimary)
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.25),
                                                .clear,
                                                .black.opacity(0.15),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.35),
                                                .clear,
                                            ],
                                            startPoint: .top,
                                            endPoint: .center
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                    }
                    .puffyButton()
                    .disabled(!self.viewModel.isFormValid || self.viewModel.isLoading)
                    .opacity((!self.viewModel.isFormValid || self.viewModel.isLoading) ? 0.5 : 1.0)
                }

                // Toggle sign in / sign up
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.viewModel.isSignUp.toggle()
                    }
                } label: {
                    if self.viewModel.isSignUp {
                        (Text("Already have an account? ")
                            .foregroundColor(.hauptgangTextSecondary)
                        + Text("Sign In")
                            .foregroundColor(.hauptgangPrimary)
                            .bold())
                            .font(.subheadline)
                    } else {
                        (Text("Don't have an account? ")
                            .foregroundColor(.hauptgangTextSecondary)
                        + Text("Sign Up")
                            .foregroundColor(.hauptgangPrimary)
                            .bold())
                            .font(.subheadline)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .onTapGesture {
            self.focusedField = nil
        }
    }

    private var buttonLabel: String {
        if self.viewModel.isSignUp {
            return self.viewModel.isLoading ? "Creating Account…" : "Create Account"
        }
        return self.viewModel.isLoading ? "Signing in…" : "Sign In"
    }

    private func submitForm() {
        guard self.viewModel.isFormValid, !self.viewModel.isLoading else { return }
        self.focusedField = nil

        Task {
            if self.viewModel.isSignUp {
                await self.viewModel.signup(authManager: self.authManager)
            } else {
                await self.viewModel.login(authManager: self.authManager)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
