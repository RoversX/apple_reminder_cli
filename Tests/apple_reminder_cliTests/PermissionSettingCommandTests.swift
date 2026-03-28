import Testing

@testable import RemindCore
@testable import apple_reminder_cli

// PermissionSettingCommand uses a raw-terminal arrow-key UI and is not unit-testable.
// Policy logic is covered by ReminderPolicyTests.
