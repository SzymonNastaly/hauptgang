import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, password, passwordConfirmation
    }

    var body: some View {
        ZStack {
            Color.hauptgangBackground.ignoresSafeArea()
            self.content
        }
        .onTapGesture { self.focusedField = nil }
        .onChange(of: self.focusedField) { old, _ in
            switch old {
            case .name: self.viewModel.nameDirty = true
            case .email: self.viewModel.emailDirty = true
            case .password: self.viewModel.passwordDirty = true
            case .passwordConfirmation: self.viewModel.passwordConfirmationDirty = true
            case nil: break
            }
        }
    }

    private var content: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            self.logoHeader
            self.form
            self.modeToggle
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var logoHeader: some View {
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
    }

    private var form: some View {
        VStack(spacing: Theme.Spacing.md) {
            self.nameField
            self.emailField
            self.passwordField
            self.passwordConfirmationField
            self.errorBanner
            self.submitButton
        }
        .id(self.viewModel.isSignUp)
    }

    @ViewBuilder
    private var nameField: some View {
        if self.viewModel.isSignUp {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField("Your first name", text: self.$viewModel.name)
                    .themeTextField(isError: self.viewModel.nameError != nil)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(self.$focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { self.focusedField = .email }

                if let error = self.viewModel.nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.hauptgangError)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var emailField: some View {
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

            if let error = self.viewModel.emailError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.hauptgangError)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SecureField("Enter your password", text: self.$viewModel.password)
                .themeTextField()
                .textContentType(self.viewModel.isSignUp ? .newPassword : .password)
                .focused(self.$focusedField, equals: .password)
                .submitLabel(self.viewModel.isSignUp ? .next : .go)
                .onSubmit(self.handlePasswordSubmit)

            if self.showPasswordLengthError {
                Text("Password must be at least 12 characters")
                    .font(.caption)
                    .foregroundStyle(Color.hauptgangError)
            }
        }
    }

    @ViewBuilder
    private var passwordConfirmationField: some View {
        if self.viewModel.isSignUp {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SecureField("Confirm your password", text: self.$viewModel.passwordConfirmation)
                    .themeTextField(isError: self.viewModel.passwordConfirmationError != nil)
                    .textContentType(.newPassword)
                    .focused(self.$focusedField, equals: .passwordConfirmation)
                    .submitLabel(.go)
                    .onSubmit(self.submitForm)

                if let error = self.viewModel.passwordConfirmationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.hauptgangError)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = self.viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.hauptgangError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
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
            .background(self.submitButtonBackground)
        }
        .puffyButton()
        .disabled(!self.viewModel.isFormValid || self.viewModel.isLoading)
        .opacity((!self.viewModel.isFormValid || self.viewModel.isLoading) ? 0.5 : 1.0)
    }

    private var submitButtonBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.hauptgangPrimary)
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
        }
    }

    private var modeToggle: some View {
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
    }

    private var showPasswordLengthError: Bool {
        self.viewModel.isSignUp && self.viewModel.passwordDirty &&
            !self.viewModel.password.isEmpty && self.viewModel.password.count < 12
    }

    private func handlePasswordSubmit() {
        if self.viewModel.isSignUp {
            self.focusedField = .passwordConfirmation
        } else {
            self.submitForm()
        }
    }

    private var buttonLabel: String {
        if self.viewModel.isSignUp {
            return self.viewModel.isLoading ? "Creating Account…" : "Create Account"
        }
        return self.viewModel.isLoading ? "Signing in…" : "Sign In"
    }

    private func submitForm() {
        self.viewModel.markAllDirty()
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
