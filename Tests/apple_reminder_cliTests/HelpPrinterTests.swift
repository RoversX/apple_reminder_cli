import Testing

@testable import apple_reminder_cli

@MainActor
struct HelpPrinterTests {
  @Test("Root help includes commands")
  func rootHelp() {
    let specs = [
      ShowCommand.spec,
      ListCommand.spec,
      AddCommand.spec,
      PolicyCommand.spec,
      PermissionSettingCommand.spec,
      StatusCommand.spec,
      AuthorizeCommand.spec,
    ]
    let lines = HelpPrinter.renderRoot(version: "0.0.0", rootName: "apple_reminder_cli", commands: specs)
    let joined = lines.joined(separator: "\n")
    #expect(joined.contains("show"))
    #expect(joined.contains("list"))
    #expect(joined.contains("add"))
    #expect(joined.contains("policy"))
    #expect(joined.contains("permission-setting"))
    #expect(joined.contains("status"))
    #expect(joined.contains("authorize"))
    #expect(joined.contains("policy.json"))
  }
}
