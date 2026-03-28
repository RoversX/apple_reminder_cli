import Commander
import Foundation
import RemindCore

enum ShowCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "show",
      abstract: "Show reminders",
      discussion: "Filters: today, tomorrow, week, overdue, upcoming, completed, all, or a date string.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(
              label: "filter",
              help: "today|tomorrow|week|overdue|upcoming|completed|all|<date>",
              isOptional: true
            )
          ],
          options: [
            .make(
              label: "list",
              names: [.short("l"), .long("list")],
              help: "Limit to a specific list",
              parsing: .singleValue
            )
          ]
        )
      ),
      usageExamples: [
        "apple_reminder_cli",
        "apple_reminder_cli today",
        "apple_reminder_cli show overdue",
        "apple_reminder_cli show 2026-01-04",
        "apple_reminder_cli show --list Work",
      ]
    ) { values, runtime in
      let listName = values.option("list")
      let filterToken = values.argument(0)
      let policy = try ReminderPolicy.load()

      let filter: ReminderFilter
      if let token = filterToken {
        guard let parsed = ReminderFiltering.parse(token) else {
          throw RemindCoreError.operationFailed("Unknown filter: \"\(token)\"")
        }
        filter = parsed
      } else {
        filter = .today
      }

      if let listName {
        if filter == .completed {
          try policy.ensureAllowed(.readCompleted, forListNamed: listName)
        } else {
          try policy.ensureReadable(listName: listName)
        }
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: listName)
      let filtered = ReminderFiltering.apply(policy.filterReadable(reminders), filter: filter)
      OutputRenderer.printReminders(filtered, format: runtime.outputFormat)
    }
  }
}
