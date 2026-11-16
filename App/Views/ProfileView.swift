import SwiftUI
import KantianaKit

struct ProfileView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                if let p = model.profile {
                    Section {
                        HStack(spacing: 16) {
                            AsyncImage(url: p.people.photoLink.flatMap(URL.init(string:))) { $0.resizable().scaledToFill() } placeholder: {
                                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(p.people.fullName).font(.headline)
                                Text(p.people.mainOnecUniverData?.group ?? p.people.type).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("Обучение") {
                        if let d = p.people.mainOnecUniverData {
                            if let s = d.speciality { LabeledContent("Направление", value: s) }
                            if let pr = d.profile { LabeledContent("Профиль", value: pr) }
                            if let c = d.course { LabeledContent("Курс", value: String(c)) }
                            if let f = d.form { LabeledContent("Форма", value: f) }
                        }
                        ForEach(p.positions ?? [], id: \.title) { pos in
                            if let dep = pos.department { LabeledContent(pos.title, value: dep) }
                        }
                    }
                    Section("Контакты") {
                        ForEach(p.emails ?? [], id: \.self) { Text($0) }
                        ForEach(p.phones ?? [], id: \.self) { Text($0) }
                    }
                }
                Section("Расписание") {
                    NavigationLink("Расписание группы") { GroupSearchView() }
                    NavigationLink("Расписание преподавателя") { TeacherSearchView() }
                }
                Section {
                    Button("Выйти", role: .destructive) { model.logout() }
                }
            }
            .navigationTitle("Профиль")
        }
    }
}

struct GroupSearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""

    var body: some View {
        AsyncContent(load: { try await model.withLK { try await $0.groups() } }) { groups in
            List(groups.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { g in
                NavigationLink(g) {
                    ScheduleView { d in try await model.withLK { try await $0.groupSchedule(group: g, date: d) } }.navigationTitle(g)
                }
            }
            .searchable(text: $query, prompt: "Группа")
        }
        .navigationTitle("Группы")
    }
}

struct TeacherSearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var results: [LKTeacher] = []

    var body: some View {
        List(results) { t in
            NavigationLink(t.fullName) {
                ScheduleView { d in try await model.withLK { try await $0.teacherSchedule(teacherId: t.id, date: d) } }.navigationTitle(t.fullName)
            }
        }
        .searchable(text: $query, prompt: "Фамилия")
        .task(id: query) {
            guard query.count >= 3 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            results = (try? await model.withLK { try await $0.searchTeachers(query) }) ?? []
        }
        .navigationTitle("Преподаватели")
    }
}
