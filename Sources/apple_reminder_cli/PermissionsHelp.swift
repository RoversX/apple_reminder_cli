import RemindCore

enum PermissionsHelp {
  static let settingsPath = "System Settings > Privacy & Security > Reminders"

  static func guidanceLines(for status: RemindersAuthorizationStatus) -> [String] {
    switch status {
    case .fullAccess:
      return []
    case .notDetermined:
      return [
        "Run `apple_reminder_cli authorize` to trigger the system prompt.",
        "If needed, open \(settingsPath) and allow Terminal (or apple_reminder_cli).",
      ]
    case .denied, .restricted:
      return [
        "Grant access in \(settingsPath) for Terminal (or apple_reminder_cli).",
        "If running over SSH, grant access on the Mac that runs the command.",
      ]
    case .writeOnly:
      return [
        "Switch to Full Access in \(settingsPath).",
        "If running over SSH, grant access on the Mac that runs the command.",
      ]
    }
  }
}
