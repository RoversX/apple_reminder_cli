import Foundation
import RemindCore

enum PolicySupport {
  static func discoverListNames(status: RemindersAuthorizationStatus) async -> [String] {
    guard status.isAuthorized else { return [] }
    let store = RemindersStore()
    return await store.lists().map(\.title).sorted()
  }

  static func makeSummary(
    policy: ReminderPolicy,
    authorizationStatus: RemindersAuthorizationStatus,
    discoveredListNames: [String],
    selectedListName: String? = nil
  ) -> PolicySummary {
    let listNames: [String]
    if let selectedListName {
      listNames = [selectedListName]
    } else {
      listNames = Array(Set(discoveredListNames).union(policy.document.lists.keys)).sorted()
    }

    let lists = listNames.map { listName in
      PolicyListSummary(
        name: listName,
        configured: policy.document.lists[listName],
        effective: policy.effectiveRule(forListNamed: listName)
      )
    }

    return PolicySummary(
      path: policy.displayPath,
      authorizationStatus: authorizationStatus.rawValue,
      defaults: policy.defaultRule,
      lists: lists
    )
  }

  static func makeListEntries(
    policy: ReminderPolicy,
    discoveredListNames: [String]
  ) -> [PolicyListEntry] {
    Array(Set(discoveredListNames).union(policy.document.lists.keys))
      .sorted()
      .map { name in
        PolicyListEntry(name: name, hasOverride: policy.document.lists[name] != nil)
      }
  }
}
