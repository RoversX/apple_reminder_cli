import Commander
import Foundation
import RemindCore

enum ListCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "list",
      abstract: "List reminder lists or show list contents",
      discussion: "Without a name, shows all lists. With a name, shows reminders in that list.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "name", help: "List name", isOptional: true)
          ],
          options: [
            .make(
              label: "rename",
              names: [.short("r"), .long("rename")],
              help: "Rename the list",
              parsing: .singleValue
            )
          ],
          flags: [
            .make(label: "delete", names: [.short("d"), .long("delete")], help: "Delete the list"),
            .make(label: "create", names: [.long("create")], help: "Create list if missing"),
            .make(label: "force", names: [.short("f"), .long("force")], help: "Skip confirmation prompts"),
          ]
        )
      ),
      usageExamples: [
        "apple_reminder_cli list",
        "apple_reminder_cli list Work",
        "apple_reminder_cli list Work --rename Office",
        "apple_reminder_cli list Work --delete",
        "apple_reminder_cli list Projects --create",
      ]
    ) { values, runtime in
      let name = values.argument(0)
      let renameTo = values.option("rename")
      let deleteList = values.flag("delete")
      let createList = values.flag("create")
      let force = values.flag("force")
      let policy = try ReminderPolicy.load()

      if let name {
        if deleteList {
          try policy.ensureAllowed(.deleteList, forListNamed: name)
        } else if renameTo != nil {
          try policy.ensureAllowed(.renameList, forListNamed: name)
        } else if createList {
          try policy.ensureAllowed(.createList, forListNamed: name)
        } else {
          try policy.ensureReadable(listName: name)
        }
      }

      let store = RemindersStore()
      try await store.requestAccess()

      if let name {
        if deleteList {
          if !force && !runtime.noInput && Console.isTTY {
            if !Console.confirm("Delete list \"\(name)\"?", defaultValue: false) {
              return
            }
          }
          try await store.deleteList(name: name)
          if runtime.outputFormat == .standard {
            Swift.print("Deleted list \"\(name)\"")
          }
          return
        }

        if let renameTo {
          try await store.renameList(oldName: name, newName: renameTo)
          if runtime.outputFormat == .standard {
            Swift.print("Renamed list \"\(name)\" -> \"\(renameTo)\"")
          }
          return
        }

        if createList {
          let list = try await store.createList(name: name)
          if runtime.outputFormat == .json {
            OutputRenderer.printLists(
              [ListSummary(id: list.id, title: list.title, reminderCount: 0, overdueCount: 0)],
              format: runtime.outputFormat
            )
          } else if runtime.outputFormat == .standard {
            Swift.print("Created list \"\(list.title)\"")
          }
          return
        }

        let reminders = try await store.reminders(in: name)
        OutputRenderer.printReminders(policy.filterReadable(reminders), format: runtime.outputFormat)
        return
      }

      let lists = policy.filterVisible(await store.lists())
      let reminders = policy.filterReadable(try await store.reminders(in: nil))

      let startOfToday = Calendar.current.startOfDay(for: Date())
      var counts: [String: (total: Int, overdue: Int)] = [:]
      for reminder in reminders where !reminder.isCompleted {
        let entry = counts[reminder.listID] ?? (0, 0)
        let overdue = (reminder.dueDate.map { $0 < startOfToday } ?? false) ? 1 : 0
        counts[reminder.listID] = (entry.total + 1, entry.overdue + overdue)
      }

      let summaries = lists.map { list in
        let entry = counts[list.id] ?? (0, 0)
        return ListSummary(
          id: list.id,
          title: list.title,
          reminderCount: entry.total,
          overdueCount: entry.overdue
        )
      }

      OutputRenderer.printLists(summaries, format: runtime.outputFormat)
    }
  }
}
