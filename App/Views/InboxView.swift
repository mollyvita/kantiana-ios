import SwiftUI
import KantianaKit

struct InboxView: View {
    enum Tab: String, CaseIterable { case notices = "Уведомления", news = "Новости", messages = "Сообщения" }
    @State private var tab = Tab.notices

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) } }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                switch tab {
                case .notices: NoticesList()
                case .news: NewsList()
                case .messages: MessagesList()
                }
            }
            .navigationTitle("Входящие")
        }
    }
}

struct NoticesList: View {
    @EnvironmentObject var model: AppModel
    @State private var dismissed: Set<String> = []

    var body: some View {
        AsyncContent(load: {
            async let lk = model.withLK { try await $0.notices(count: 50) }
            async let moodle = model.withEios { try await $0.notifications(limit: 30) }
            return (try await lk.items, (try? await moodle.notifications) ?? [])
        }) { (notices: [LKNotice], notifications: [MoodleNotification]) in
            List {
                Section("ЛК") {
                    ForEach(notices.filter { !dismissed.contains($0.id) }) { n in
                        VStack(alignment: .leading) {
                            Text(n.comment ?? n.event ?? "Уведомление").fontWeight(n.isActive ? .semibold : .regular)
                            Text("\(n.source?.uppercased() ?? "") · \(Fmt.iso(n.created))").font(.caption).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Скрыть") {
                                Task { try? await model.withLK { try await $0.dismissNotice(id: n.id) }; dismissed.insert(n.id) }
                            }
                        }
                        .onTapGesture { if let l = n.link, let u = URL(string: l) { UIApplication.shared.open(u) } }
                    }
                }
                if !notifications.isEmpty {
                    Section("eios") {
                        ForEach(notifications) { n in
                            VStack(alignment: .leading) {
                                Text(n.subject ?? "").fontWeight(n.read == false ? .semibold : .regular)
                                Text(Fmt.unix(n.timecreated)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NewsList: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        AsyncContent(load: { try await model.withLK { try await $0.news(count: 30) }.items }) { items in
            List(items) { n in
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let t = n.thumbnail, let u = URL(string: t) {
                                AsyncImage(url: u) { $0.resizable().scaledToFit() } placeholder: { Color.secondary.opacity(0.1).frame(height: 180) }
                            }
                            Text(n.title).font(.title3.bold())
                            Text(Fmt.iso(n.date)).font(.caption).foregroundStyle(.secondary)
                            Text(n.description?.strippingHTML ?? "")
                            if let l = n.link, let u = URL(string: l) { Link("Открыть на сайте", destination: u) }
                        }
                        .padding()
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(n.title).lineLimit(3)
                        Text(Fmt.iso(n.date)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MessagesList: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        AsyncContent(load: {
            try await model.withEios { m in (try await m.conversations(), try await m.userId()) }
        }) { (convs: [MoodleConversation], me: Int) in
            List(convs) { c in
                let title = c.name.flatMap { $0.isEmpty ? nil : $0 } ?? c.members.filter { $0.id != me }.map(\.fullname).first ?? "Избранное"
                NavigationLink {
                    ConversationView(conversation: c, me: me, title: title)
                } label: {
                    VStack(alignment: .leading) {
                        Text(title).fontWeight((c.unreadcount ?? 0) > 0 ? .semibold : .regular)
                        if let last = c.messages.first { Text(last.text.strippingHTML).lineLimit(1).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .overlay { if convs.isEmpty { ContentUnavailableView("Нет сообщений", systemImage: "bubble.left") } }
        }
    }
}

struct ConversationView: View {
    @EnvironmentObject var model: AppModel
    let conversation: MoodleConversation
    let me: Int
    let title: String
    @State private var draft = ""
    @State private var reload = 0

    var body: some View {
        VStack {
            AsyncContent(load: { try await model.withEios { try await $0.conversationMessages(conversationId: conversation.id) }.messages }) { msgs in
                List(msgs.reversed()) { m in
                    HStack {
                        if m.useridfrom == me { Spacer() }
                        Text(m.text.strippingHTML)
                            .padding(8)
                            .background(m.useridfrom == me ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: .rect(cornerRadius: 10))
                        if m.useridfrom != me { Spacer() }
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            .id(reload)
            if let other = conversation.members.first(where: { $0.id != me }) {
                HStack {
                    TextField("Сообщение", text: $draft).textFieldStyle(.roundedBorder)
                    Button {
                        let text = draft
                        Task {
                            try? await model.withEios { try await $0.sendMessage(toUserId: other.id, text: text) }
                            draft = ""
                            reload += 1
                        }
                    } label: { Image(systemName: "paperplane.fill") }
                    .disabled(draft.isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
