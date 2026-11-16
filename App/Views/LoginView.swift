import SwiftUI

struct LoginView: View {
    @EnvironmentObject var model: AppModel
    @State private var login = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Логин (ivanov или ivanov@stud.kantiana.ru)", text: $login)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Пароль", text: $password)
                        .textContentType(.password)
                } footer: {
                    Text("Те же данные, что и для lk.kantiana.ru. Хранятся только в Keychain на этом устройстве.")
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button {
                    Task {
                        busy = true
                        defer { busy = false }
                        do { try await model.login(login, password: password) } catch { self.error = error.localizedDescription }
                    }
                } label: {
                    if busy { ProgressView() } else { Text("Войти") }
                }
                .disabled(login.isEmpty || password.isEmpty || busy)
            }
            .navigationTitle("Kantiana")
        }
    }
}
