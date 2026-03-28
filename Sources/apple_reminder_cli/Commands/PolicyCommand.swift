import Commander
import Foundation
import RemindCore

struct PolicyListEntry: Codable, Equatable, Sendable {
  let name: String
  let hasOverride: Bool
}

enum PolicyCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "policy",
      abstract: "View or edit the local policy",
      discussion:
        """
        Usage patterns:
          apple_reminder_cli policy
          apple_reminder_cli policy <list>
          apple_reminder_cli policy lists
          apple_reminder_cli policy set defaults <capability> <allow|deny>
          apple_reminder_cli policy set <list> <capability> <allow|deny>
          apple_reminder_cli policy unset <list> <capability>
        """,
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "args", help: "policy action and arguments", isOptional: true)
          ]
        )
      ),
      usageExamples: [
        "apple_reminder_cli policy",
        "apple_reminder_cli policy Work",
        "apple_reminder_cli policy lists",
        "apple_reminder_cli policy set defaults readCompleted deny",
        "apple_reminder_cli policy set Work delete deny",
        "apple_reminder_cli policy unset Work delete",
      ]
    ) { values, runtime in
      let args = values.positional
      let policy = try ReminderPolicy.load()
      let status = RemindersStore.authorizationStatus()
      let discovered = await PolicySupport.discoverListNames(status: status)

      guard let first = args.first else {
        let summary = PolicySupport.makeSummary(
          policy: policy,
          authorizationStatus: status,
          discoveredListNames: discovered
        )
        OutputRenderer.printPolicy(summary, format: runtime.outputFormat)
        return
      }

      switch first {
      case "lists":
        let entries = PolicySupport.makeListEntries(policy: policy, discoveredListNames: discovered)
        OutputRenderer.printPolicyLists(entries, format: runtime.outputFormat)
      case "set":
        try handleSet(args: args, runtime: runtime, policy: policy)
      case "unset":
        try handleUnset(args: args, runtime: runtime, policy: policy)
      default:
        let summary = PolicySupport.makeSummary(
          policy: policy,
          authorizationStatus: status,
          discoveredListNames: discovered,
          selectedListName: first
        )
        OutputRenderer.printPolicy(summary, format: runtime.outputFormat)
      }
    }
  }

  private static func handleSet(
    args: [String],
    runtime: RuntimeOptions,
    policy: ReminderPolicy
  ) throws {
    guard args.count == 4 else {
      throw RemindCoreError.operationFailed("Usage: policy set <defaults|list> <capability> <allow|deny>")
    }

    let target = args[1]
    let capabilityValue = args[2]
    let decisionValue = args[3]

    guard let capability = ReminderPolicyCapability.parse(capabilityValue) else {
      throw RemindCoreError.operationFailed("Unknown capability: \(capabilityValue)")
    }

    let decision: Bool
    switch decisionValue.lowercased() {
    case "allow", "true", "yes", "y":
      decision = true
    case "deny", "false", "no", "n":
      decision = false
    default:
      throw RemindCoreError.operationFailed("Value must be allow or deny.")
    }

    var document = policy.document
    if target == "defaults" {
      document.defaults = document.defaults.setting(capability, to: decision)
    } else {
      var rule = document.lists[target] ?? ReminderPolicyRule()
      rule = rule.setting(capability, to: decision)
      document.lists[target] = rule
    }

    try ReminderPolicy.saveDocument(document, to: policy.location)
    if runtime.outputFormat == .json {
      let updated = ReminderPolicy(document: document, location: policy.location)
      let summary = PolicySupport.makeSummary(
        policy: updated,
        authorizationStatus: RemindersStore.authorizationStatus(),
        discoveredListNames: []
      )
      OutputRenderer.printPolicy(summary, format: .json)
    } else if runtime.outputFormat == .plain {
      Swift.print(["set", target, capability.rawValue, decision ? "allow" : "deny"].joined(separator: "\t"))
    } else if runtime.outputFormat == .standard {
      Swift.print("Set \(target).\(capability.rawValue) = \(decision ? "allow" : "deny")")
    }
  }

  private static func handleUnset(
    args: [String],
    runtime: RuntimeOptions,
    policy: ReminderPolicy
  ) throws {
    guard args.count == 3 else {
      throw RemindCoreError.operationFailed("Usage: policy unset <list> <capability>")
    }

    let target = args[1]
    guard target != "defaults" else {
      throw RemindCoreError.operationFailed("Defaults cannot be unset. Use policy set defaults ... instead.")
    }

    let capabilityValue = args[2]
    guard let capability = ReminderPolicyCapability.parse(capabilityValue) else {
      throw RemindCoreError.operationFailed("Unknown capability: \(capabilityValue)")
    }

    var document = policy.document
    var rule = document.lists[target] ?? ReminderPolicyRule()
    rule = rule.setting(capability, to: nil)
    if rule.isEmpty {
      document.lists.removeValue(forKey: target)
    } else {
      document.lists[target] = rule
    }

    try ReminderPolicy.saveDocument(document, to: policy.location)
    if runtime.outputFormat == .json {
      let updated = ReminderPolicy(document: document, location: policy.location)
      let summary = PolicySupport.makeSummary(
        policy: updated,
        authorizationStatus: RemindersStore.authorizationStatus(),
        discoveredListNames: []
      )
      OutputRenderer.printPolicy(summary, format: .json)
    } else if runtime.outputFormat == .plain {
      Swift.print(["unset", target, capability.rawValue].joined(separator: "\t"))
    } else if runtime.outputFormat == .standard {
      Swift.print("Unset \(target).\(capability.rawValue)")
    }
  }
}
