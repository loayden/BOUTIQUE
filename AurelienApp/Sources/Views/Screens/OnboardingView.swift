import SwiftUI

struct OnboardingView: View {
    @State private var page = 0
    @State private var showAuth = false

    var body: some View {
        VStack {
            TabView(selection: $page) {
                VStack(spacing: 32) {
                    Image(systemName: "tshirt.fill").font(.system(size: 80))
                    Text("Discover unique fashion from local boutiques.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }.tag(0)
                VStack(spacing: 32) {
                    Image(systemName: "sparkles").font(.system(size: 80))
                    Text("Shop trending and new arrivals with a luxury experience.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }.tag(1)
                VStack(spacing: 32) {
                    Image(systemName: "cart.fill").font(.system(size: 80))
                    Text("Easy checkout and fast delivery to your door.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }.tag(2)
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: 350)

            Spacer()

            Button(page < 2 ? "Next" : "Get Started") {
                if page < 2 {
                    page += 1
                } else {
                    showAuth = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthView()
        }
    }
}

struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AurelienStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text(isLogin ? "Login" : "Sign Up")
                .font(.largeTitle.bold())
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            Button(isLogin ? "Login" : "Sign Up") {
                Task {
                    isLoading = true
                    errorMessage = nil
                    do {
                        if isLogin {
                            let response = try await APIService.shared.login(email: email, password: password)
                            store.login(user: response.user, token: response.token ?? "")
                        } else {
                            let response = try await APIService.shared.signup(
                                name: email.components(separatedBy: "@").first ?? "Client",
                                email: email,
                                password: password,
                                confirmPassword: password
                            )
                            store.login(user: response.user, token: response.token ?? "")
                        }

                        await MainActor.run {
                            dismiss()
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                        }
                    }
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login") {
                isLogin.toggle()
            }
            .font(.footnote)
        }
        .padding()
    }
}
