import Testing

@testable import RemindCore
@testable import apple_reminder_cli

@MainActor
struct PermissionSettingCommandTests {
  @Test("Permission editor exits without saving on EOF")
  func exitsWithoutSavingOnEOF() {
    var document = ReminderPolicyDocument.defaultDocument

    let shouldSave = PermissionSettingCommand.runWizard(
      document: &document,
      policyPath: "~/.config/apple_reminder_cli/policy.json",
      authorizationStatus: .fullAccess,
      discoveredListNames: [],
      inputReader: { _ in nil }
    )

    #expect(!shouldSave)
    #expect(document == .defaultDocument)
  }

  @Test("Permission editor can set a list override")
  func setsListOverride() {
    var document = ReminderPolicyDocument.defaultDocument
    var iterator = ["3", "Work", "delete", "deny", "5"].makeIterator()

    let shouldSave = PermissionSettingCommand.runWizard(
      document: &document,
      policyPath: "~/.config/apple_reminder_cli/policy.json",
      authorizationStatus: .fullAccess,
      discoveredListNames: ["Work"],
      inputReader: { _ in iterator.next() }
    )

    #expect(shouldSave)
    #expect(document.lists["Work"]?.delete == false)
  }
}
