import SwiftUI
import QuickLook
import KantianaKit

struct CoursesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            AsyncContent(load: { try await model.withEios { try await $0.courses() } }) { courses in
                List(courses) { c in
                    NavigationLink(value: c) {
                        VStack(alignment: .leading) {
                            Text(c.fullname)
                            if let p = c.progress { ProgressView(value: p, total: 100).tint(.accentColor) }
                        }
                    }
                }
                .overlay { if courses.isEmpty { ContentUnavailableView("Нет курсов", systemImage: "books.vertical") } }
            }
            .navigationDestination(for: MoodleCourse.self) { CourseDetailView(course: $0) }
            .navigationTitle("Курсы")
        }
    }
}

struct CourseDetailView: View {
    @EnvironmentObject var model: AppModel
    let course: MoodleCourse

    var body: some View {
        AsyncContent(load: { try await model.withEios { try await $0.courseContents(courseId: course.id) } }) { sections in
            List {
                ForEach(sections.filter { !$0.modules.isEmpty || !($0.summary ?? "").isEmpty }) { s in
                    Section(s.name) {
                        if let summary = s.summary?.strippingHTML, !summary.isEmpty { Text(summary).font(.callout) }
                        ForEach(s.modules) { ModuleRow(module: $0, courseId: course.id) }
                    }
                }
            }
        }
        .navigationTitle(course.fullname)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModuleRow: View {
    @EnvironmentObject var model: AppModel
    let module: MoodleModule
    let courseId: Int
    @State private var preview: URL?
    @State private var downloading = false

    private var icon: String {
        switch module.modname {
        case "resource": "doc"
        case "assign": "square.and.pencil"
        case "forum": "bubble.left.and.bubble.right"
        case "quiz": "checklist"
        case "url": "link"
        case "folder": "folder"
        default: "square.grid.2x2"
        }
    }

    var body: some View {
        Group {
            if module.modname == "assign", let instance = module.instance {
                NavigationLink { AssignmentView(assignId: instance, courseId: courseId, title: module.name) } label: { label }
            } else if let file = module.contents?.first(where: { $0.type == "file" }), let url = file.fileurl.flatMap(URL.init(string:)) {
                Button { Task { await open(url: url, filename: file.filename) } } label: { label }
            } else if let url = module.url.flatMap(URL.init(string:)) {
                Link(destination: url) { label }
            } else {
                label
            }
        }
        .quickLookPreview($preview)
    }

    private var label: some View {
        HStack {
            Label(module.name, systemImage: icon)
            Spacer()
            if downloading { ProgressView() }
            if module.completiondata?.state == 1 { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
        }
    }

    private func open(url: URL, filename: String) async {
        downloading = true
        defer { downloading = false }
        do {
            let res = try await model.withEios { try await $0.download(url) }
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try res.body.write(to: dest)
            preview = dest
        } catch {}
    }
}

struct AssignmentView: View {
    @EnvironmentObject var model: AppModel
    let assignId: Int
    let courseId: Int
    let title: String
    @State private var text = ""
    @State private var message: String?
    @State private var reload = 0

    var body: some View {
        AsyncContent(load: {
            try await model.withEios { m in
                async let a = m.assignments(courseIds: [courseId])
                async let s = m.submissionStatus(assignId: assignId)
                return (try await a.courses.flatMap(\.assignments).first { $0.id == assignId }, try await s)
            }
        }) { (assignment: MoodleAssignment?, status: MoodleSubmissionStatus) in
            Form {
                if let a = assignment {
                    Section("Задание") {
                        LabeledContent("Срок", value: Fmt.unix(a.duedate))
                        if let intro = a.intro?.strippingHTML, !intro.isEmpty { Text(intro) }
                    }
                }
                Section("Статус") {
                    LabeledContent("Ответ", value: status.lastattempt?.submission?.status ?? "—")
                    LabeledContent("Оценивание", value: status.lastattempt?.gradingstatus ?? "—")
                    if let g = status.feedback?.gradefordisplay { LabeledContent("Оценка", value: g.strippingHTML) }
                }
                if status.lastattempt?.canedit ?? false {
                    Section("Ответ текстом") {
                        TextEditor(text: $text).frame(minHeight: 120)
                        Button("Сохранить черновик") { Task { await save(submit: false) } }.disabled(text.isEmpty)
                        Button("Отправить на оценку") { Task { await save(submit: true) } }.disabled(text.isEmpty)
                    }
                }
                if let message { Text(message).font(.footnote) }
            }
        }
        .id(reload)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(submit: Bool) async {
        do {
            try await model.withEios { m in
                try await m.saveSubmission(assignmentId: assignId, text: text)
                if submit { try await m.submitForGrading(assignmentId: assignId) }
            }
            message = submit ? "Отправлено" : "Сохранено"
            reload += 1
        } catch {
            message = error.localizedDescription
        }
    }
}
