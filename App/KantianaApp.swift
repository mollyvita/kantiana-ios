import SwiftUI

@main
struct KantianaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task { await model.restore() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .loggedOut:
            LoginView()
        case .loggedIn:
            TabView {
                TodayView().tabItem { Label("Сегодня", systemImage: "calendar") }
                CoursesView().tabItem { Label("Курсы", systemImage: "books.vertical") }
                GradesView().tabItem { Label("Оценки", systemImage: "chart.bar") }
                InboxView().tabItem { Label("Входящие", systemImage: "tray") }
                ProfileView().tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            }
        }
    }
}
