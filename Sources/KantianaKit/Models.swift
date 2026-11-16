import Foundation

// MARK: - lk.kantiana.ru

public struct LKEnvelope<T: Decodable>: Decodable {
    public struct Status: Decodable { public let status: Int; public let message: String? }
    public struct Additional: Decodable { public let count: Int?; public let offset: Int?; public let total: Int? }
    public let response: Status?
    public let payload: T?
    public let additional: Additional?
}

public struct LKPaged<T: Decodable & Sendable>: Sendable {
    public let items: [T]
    public let total: Int
}

public struct LKProfile: Codable, Sendable {
    public struct People: Codable, Sendable {
        public struct UniverData: Codable, Sendable {
            public let course: Int?
            public let form: String?
            public let profile: String?
            public let speciality: String?
            public let group: String?
            public let startYear: Int?
            public let endYear: Int?
        }
        public let rootId: Int
        public let ldapId: String
        public let type: String
        public let surname: String
        public let name: String
        public let patronymic: String?
        public let bday: String?
        public let photoLink: String?
        public let mainEmail: String?
        public let mainPhone: String?
        public let mainOnecUniverData: UniverData?

        public var fullName: String { [surname, name, patronymic].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ") }
    }
    public struct Position: Codable, Sendable {
        public let title: String
        public let department: String?
        public let course: Int?
        public let specialty: String?
    }
    public let people: People
    public let positions: [Position]?
    public let emails: [String]?
    public let phones: [String]?
}

public struct LKService: Codable, Sendable {
    public let name: String
    public let role: String?
    public let url: String?
}

public struct LKServices: Codable, Sendable {
    public let token: String?
    public let services: [LKService]
}

public struct LKNotice: Codable, Sendable, Identifiable {
    public let id: String
    public let source: String?
    public let event: String?
    public let link: String?
    public let comment: String?
    public let active: String?
    public let created: String?

    public var isActive: Bool { active == "1" }
}

public struct LKNewsItem: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    public let date: String?
    public let thumbnail: String?
    public let link: String?
}

public struct LKClass: Codable, Sendable, Hashable {
    public struct Time: Codable, Sendable, Hashable { public let start: String; public let end: String }
    public struct Lesson: Codable, Sendable, Hashable { public let title: String; public let type: String }
    public struct Location: Codable, Sendable, Hashable { public let address: String?; public let room: String? }
    public let groups: [String]?
    public let subgroup: String?
    public let teachers: [String]
    public let time: Time
    public let lesson: Lesson
    public let location: Location?
}

public struct LKScheduleDay: Codable, Sendable, Hashable {
    public let date: String
    public let classes: [LKClass]
}

public struct LKTeacher: Codable, Sendable, Identifiable, Hashable {
    public let onecUniverId: String
    public let surname: String
    public let name: String
    public let patronymic: String?

    public var id: String { onecUniverId }
    public var fullName: String { [surname, name, patronymic].compactMap { $0 }.joined(separator: " ") }
}

// MARK: - Moodle (eios / lms)

public struct MoodleSiteInfo: Codable, Sendable {
    public struct Function: Codable, Sendable { public let name: String }
    public let sitename: String
    public let username: String
    public let fullname: String
    public let userid: Int
    public let siteurl: String
    public let userpictureurl: String?
    public let release: String?
    public let functions: [Function]?
}

public struct MoodleCourse: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let shortname: String
    public let fullname: String
    public let summary: String?
    public let progress: Double?
    public let completed: Bool?
    public let startdate: Int?
    public let enddate: Int?
    public let lastaccess: Int?
    public let courseimage: String?
}

public struct MoodleContent: Codable, Sendable, Hashable {
    public let type: String
    public let filename: String
    public let filesize: Int?
    public let fileurl: String?
    public let mimetype: String?
    public let timemodified: Int?
}

public struct MoodleModule: Codable, Sendable, Identifiable, Hashable {
    public struct DateItem: Codable, Sendable, Hashable { public let label: String; public let timestamp: Int }
    public struct Completion: Codable, Sendable, Hashable { public let state: Int }
    public let id: Int
    public let name: String
    public let modname: String
    public let instance: Int?
    public let url: String?
    public let description: String?
    public let visible: Int?
    public let contents: [MoodleContent]?
    public let dates: [DateItem]?
    public let completiondata: Completion?
}

public struct MoodleSection: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let summary: String?
    public let section: Int
    public let visible: Int?
    public let modules: [MoodleModule]
}

public struct MoodleAssignment: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let cmid: Int
    public let course: Int
    public let name: String
    public let intro: String?
    public let duedate: Int
    public let cutoffdate: Int?
    public let allowsubmissionsfromdate: Int?
    public let introattachments: [MoodleContent]?
}

public struct MoodleAssignmentsResponse: Codable, Sendable {
    public struct Course: Codable, Sendable { public let id: Int; public let fullname: String; public let assignments: [MoodleAssignment] }
    public let courses: [Course]
}

public struct MoodleSubmissionStatus: Codable, Sendable {
    public struct LastAttempt: Codable, Sendable {
        public struct Submission: Codable, Sendable { public let status: String; public let timemodified: Int? }
        public let submission: Submission?
        public let cansubmit: Bool?
        public let canedit: Bool?
        public let gradingstatus: String?
    }
    public struct Feedback: Codable, Sendable {
        public let gradefordisplay: String?
        public let gradeddate: Int?
    }
    public let lastattempt: LastAttempt?
    public let feedback: Feedback?
}

public struct MoodleEvent: Codable, Sendable, Identifiable, Hashable {
    public struct CourseRef: Codable, Sendable, Hashable { public let id: Int; public let fullname: String }
    public struct Action: Codable, Sendable, Hashable { public let name: String; public let url: String?; public let actionable: Bool? }
    public let id: Int
    public let name: String
    public let description: String?
    public let modulename: String?
    public let instance: Int?
    public let eventtype: String
    public let timestart: Int
    public let timesort: Int?
    public let course: CourseRef?
    public let url: String?
    public let action: Action?
}

public struct MoodleEventsResponse: Codable, Sendable { public let events: [MoodleEvent] }

public struct MoodleGradeOverview: Codable, Sendable {
    public struct Grade: Codable, Sendable { public let courseid: Int; public let grade: String?; public let rawgrade: String?; public let rank: Int? }
    public let grades: [Grade]
}

public struct MoodleCourseGrades: Codable, Sendable {
    public struct UserGrade: Codable, Sendable {
        public struct Item: Codable, Sendable, Identifiable, Hashable {
            public let id: Int
            public let itemname: String?
            public let itemtype: String
            public let itemmodule: String?
            public let gradeformatted: String?
            public let percentageformatted: String?
            public let grademin: Double?
            public let grademax: Double?
            public let feedback: String?
        }
        public let courseid: Int
        public let gradeitems: [Item]
    }
    public let usergrades: [UserGrade]
}

public struct MoodleConversation: Codable, Sendable, Identifiable, Hashable {
    public struct Member: Codable, Sendable, Hashable { public let id: Int; public let fullname: String; public let profileimageurl: String? }
    public let id: Int
    public let name: String?
    public let type: Int
    public let isread: Bool?
    public let unreadcount: Int?
    public let members: [Member]
    public let messages: [MoodleMessage]
}

public struct MoodleConversationsResponse: Codable, Sendable { public let conversations: [MoodleConversation] }

public struct MoodleMessage: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let useridfrom: Int
    public let text: String
    public let timecreated: Int
}

public struct MoodleConversationMessages: Codable, Sendable {
    public let id: Int
    public let members: [MoodleConversation.Member]
    public let messages: [MoodleMessage]
}

public struct MoodleNotification: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let subject: String?
    public let shortenedsubject: String?
    public let smallmessage: String?
    public let fullmessagehtml: String?
    public let timecreated: Int
    public let read: Bool?
    public let contexturl: String?
}

public struct MoodleNotificationsResponse: Codable, Sendable {
    public let notifications: [MoodleNotification]
    public let unreadcount: Int?
}

struct MoodleException: Decodable {
    let exception: String
    let errorcode: String?
    let message: String?
}
