import Foundation
import RemindCore

enum OutputFormat {
  case standard
  case plain
  case json
  case quiet
}

struct ListSummary: Codable, Sendable, Equatable {
  let id: String
  let title: String
  let reminderCount: Int
  let overdueCount: Int
}

struct AuthorizationSummary: Codable, Sendable, Equatable {
  let status: String
  let authorized: Bool
}

struct PolicyListSummary: Codable, Sendable, Equatable {
  let name: String
  let configured: ReminderPolicyRule?
  let effective: EffectiveReminderPolicyRule
}

struct PolicySummary: Codable, Sendable, Equatable {
  let path: String
  let authorizationStatus: String
  let defaults: EffectiveReminderPolicyRule
  let lists: [PolicyListSummary]
}

enum OutputRenderer {
  static func printReminders(_ reminders: [ReminderItem], format: OutputFormat) {
    switch format {
    case .standard:
      printRemindersStandard(reminders)
    case .plain:
      printRemindersPlain(reminders)
    case .json:
      printJSON(reminders)
    case .quiet:
      Swift.print(reminders.count)
    }
  }

  static func printLists(_ summaries: [ListSummary], format: OutputFormat) {
    switch format {
    case .standard:
      printListsStandard(summaries)
    case .plain:
      printListsPlain(summaries)
    case .json:
      printJSON(summaries)
    case .quiet:
      Swift.print(summaries.count)
    }
  }

  static func printReminder(_ reminder: ReminderItem, format: OutputFormat) {
    switch format {
    case .standard:
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      Swift.print("✓ \(reminder.title) [\(reminder.listName)] — \(due)")
    case .plain:
      Swift.print(plainLine(for: reminder))
    case .json:
      printJSON(reminder)
    case .quiet:
      break
    }
  }

  static func printDeleteResult(_ count: Int, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Deleted \(count) reminder(s)")
    case .plain:
      Swift.print("\(count)")
    case .json:
      let payload = ["deleted": count]
      printJSON(payload)
    case .quiet:
      break
    }
  }

  static func printAuthorizationStatus(_ status: RemindersAuthorizationStatus, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Reminders access: \(status.displayName)")
    case .plain:
      Swift.print(status.rawValue)
    case .json:
      printJSON(AuthorizationSummary(status: status.rawValue, authorized: status.isAuthorized))
    case .quiet:
      Swift.print(status.isAuthorized ? "1" : "0")
    }
  }

  static func printPolicy(_ summary: PolicySummary, format: OutputFormat) {
    switch format {
    case .standard:
      printPolicyStandard(summary)
    case .plain:
      printPolicyPlain(summary)
    case .json:
      printJSON(summary)
    case .quiet:
      Swift.print(summary.lists.count)
    }
  }

  static func printPolicyLists(_ entries: [PolicyListEntry], format: OutputFormat) {
    switch format {
    case .standard:
      if entries.isEmpty {
        Swift.print("No lists found")
        return
      }
      for entry in entries.sorted(by: { $0.name < $1.name }) {
        Swift.print("\(entry.name)\(entry.hasOverride ? " [override]" : "")")
      }
    case .plain:
      for entry in entries.sorted(by: { $0.name < $1.name }) {
        Swift.print("\(entry.name)\t\(entry.hasOverride ? "1" : "0")")
      }
    case .json:
      printJSON(entries)
    case .quiet:
      Swift.print(entries.count)
    }
  }

  private static func printRemindersStandard(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    guard !sorted.isEmpty else {
      Swift.print("No reminders found")
      return
    }
    for (index, reminder) in sorted.enumerated() {
      let status = reminder.isCompleted ? "x" : " "
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      let priority = reminder.priority == .none ? "" : " priority=\(reminder.priority.rawValue)"
      Swift.print("[\(index + 1)] [\(status)] \(reminder.title) [\(reminder.listName)] — \(due)\(priority)")
    }
  }

  private static func printRemindersPlain(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    for reminder in sorted {
      Swift.print(plainLine(for: reminder))
    }
  }

  private static func plainLine(for reminder: ReminderItem) -> String {
    let due = reminder.dueDate.map { isoFormatter().string(from: $0) } ?? ""
    return [
      reminder.id,
      reminder.listName,
      reminder.isCompleted ? "1" : "0",
      reminder.priority.rawValue,
      due,
      reminder.title,
    ].joined(separator: "\t")
  }

  private static func printListsStandard(_ summaries: [ListSummary]) {
    guard !summaries.isEmpty else {
      Swift.print("No reminder lists found")
      return
    }
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      let overdue = summary.overdueCount > 0 ? " (\(summary.overdueCount) overdue)" : ""
      Swift.print("\(summary.title) — \(summary.reminderCount) reminders\(overdue)")
    }
  }

  private static func printListsPlain(_ summaries: [ListSummary]) {
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      Swift.print("\(summary.title)\t\(summary.reminderCount)\t\(summary.overdueCount)")
    }
  }

  private static func printPolicyStandard(_ summary: PolicySummary) {
    Swift.print("Policy file: \(summary.path)")
    Swift.print("Reminders access: \(summary.authorizationStatus)")
    Swift.print("")
    Swift.print("Defaults:")
    for capability in ReminderPolicyCapability.allCases {
      Swift.print("  \(capability.rawValue): \(summary.defaults.value(for: capability) ? "allow" : "deny")")
    }

    if summary.lists.isEmpty {
      Swift.print("")
      Swift.print("Lists:")
      Swift.print("  No list-specific policy entries")
      return
    }

    Swift.print("")
    Swift.print("Lists:")
    for list in summary.lists.sorted(by: { $0.name < $1.name }) {
      Swift.print("  \(list.name)")
      if let configured = list.configured {
        Swift.print("    overrides: \(configuredOverrideString(configured))")
      } else {
        Swift.print("    overrides: (none)")
      }
      Swift.print("    effective: \(effectiveRuleString(list.effective))")
    }
  }

  private static func printPolicyPlain(_ summary: PolicySummary) {
    Swift.print(["path", summary.path, summary.authorizationStatus].joined(separator: "\t"))
    Swift.print(["defaults", effectiveRuleString(summary.defaults)].joined(separator: "\t"))
    for list in summary.lists.sorted(by: { $0.name < $1.name }) {
      let configured = list.configured.map(configuredOverrideString) ?? ""
      Swift.print(["list", list.name, configured, effectiveRuleString(list.effective)].joined(separator: "\t"))
    }
  }

  private static func configuredOverrideString(_ rule: ReminderPolicyRule) -> String {
    let parts = ReminderPolicyCapability.allCases.compactMap { capability -> String? in
      guard let value = rule.configuredValue(for: capability) else { return nil }
      return "\(capability.rawValue)=\(value ? "allow" : "deny")"
    }
    return parts.isEmpty ? "(none)" : parts.joined(separator: ", ")
  }

  private static func effectiveRuleString(_ rule: EffectiveReminderPolicyRule) -> String {
    ReminderPolicyCapability.allCases
      .map { "\($0.rawValue)=\(rule.value(for: $0) ? "allow" : "deny")" }
      .joined(separator: ", ")
  }

  private static func printJSON<T: Encodable>(_ payload: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    do {
      let data = try encoder.encode(payload)
      if let json = String(data: data, encoding: .utf8) {
        Swift.print(json)
      }
    } catch {
      Swift.print("Failed to encode JSON: \(error)")
    }
  }

  private static func isoFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}
