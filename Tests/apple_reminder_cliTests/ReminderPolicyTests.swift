import Foundation
import Testing

@testable import RemindCore
@testable import apple_reminder_cli

@MainActor
struct ReminderPolicyTests {
  @Test("Default policy file is created with completed history disabled")
  func createDefaultPolicyFile() throws {
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let policyURL = tempDir.appendingPathComponent("policy.json", isDirectory: false)
    defer { try? fileManager.removeItem(at: tempDir) }

    let policy = try ReminderPolicy.load(
      fileManager: fileManager,
      environment: ["APPLE_REMINDER_CLI_POLICY_PATH": policyURL.path]
    )

    #expect(fileManager.fileExists(atPath: policyURL.path))
    #expect(policy.allows(.readActive, forListNamed: "Inbox"))
    #expect(!policy.allows(.readCompleted, forListNamed: "Inbox"))

    let data = try Data(contentsOf: policyURL)
    let decoded = try JSONDecoder().decode(ReminderPolicyDocument.self, from: data)
    #expect(decoded == .defaultDocument)
  }

  @Test("Per-list overrides filter reminders and list visibility")
  func listOverrides() {
    let policy = ReminderPolicy(
      document: ReminderPolicyDocument(
        defaults: .defaults,
        lists: [
          "Private": ReminderPolicyRule(readActive: false, readCompleted: false),
          "Work": ReminderPolicyRule(readCompleted: true, delete: false),
        ]
      ),
      location: URL(fileURLWithPath: "/tmp/policy.json")
    )

    let reminders = [
      ReminderItem(
        id: "1",
        title: "Active work",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: nil,
        listID: "work",
        listName: "Work"
      ),
      ReminderItem(
        id: "2",
        title: "Done work",
        notes: nil,
        isCompleted: true,
        completionDate: Date(timeIntervalSince1970: 1_700_000_000),
        priority: .none,
        dueDate: nil,
        listID: "work",
        listName: "Work"
      ),
      ReminderItem(
        id: "3",
        title: "Private note",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: nil,
        listID: "private",
        listName: "Private"
      ),
    ]

    let visible = policy.filterReadable(reminders)
    #expect(visible.map(\.title) == ["Active work", "Done work"])
    #expect(policy.filterVisible([
      ReminderList(id: "work", title: "Work"),
      ReminderList(id: "private", title: "Private"),
    ]) == [
      ReminderList(id: "work", title: "Work")
    ])
    #expect(throws: ReminderPolicyError.blocked(
      action: ReminderPolicyCapability.delete.description,
      listName: "Work",
      policyPath: "/tmp/policy.json"
    )) {
      try policy.ensureAllowed(.delete, forListNamed: "Work")
    }
  }
}
