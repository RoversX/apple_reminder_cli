import Foundation
import RemindCore

enum ReminderPolicyCapability: String, CaseIterable, Hashable, Sendable {
  case readActive
  case readCompleted
  case add
  case edit
  case complete
  case delete
  case createList
  case renameList
  case deleteList

  var description: String {
    switch self {
    case .readActive:
      return "read active reminders"
    case .readCompleted:
      return "read completed reminders"
    case .add:
      return "add reminders"
    case .edit:
      return "edit reminders"
    case .complete:
      return "change completion state"
    case .delete:
      return "delete reminders"
    case .createList:
      return "create lists"
    case .renameList:
      return "rename lists"
    case .deleteList:
      return "delete lists"
    }
  }

  static func parse(_ value: String) -> ReminderPolicyCapability? {
    let normalized = value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: "_", with: "")
      .lowercased()

    return allCases.first { capability in
      capability.rawValue.replacingOccurrences(of: "_", with: "").lowercased() == normalized
    }
  }
}

struct ReminderPolicyRule: Codable, Equatable, Sendable {
  var readActive: Bool?
  var readCompleted: Bool?
  var add: Bool?
  var edit: Bool?
  var complete: Bool?
  var delete: Bool?
  var createList: Bool?
  var renameList: Bool?
  var deleteList: Bool?

  static let defaults = ReminderPolicyRule(
    readActive: true,
    readCompleted: false,
    add: true,
    edit: true,
    complete: true,
    delete: true,
    createList: true,
    renameList: true,
    deleteList: true
  )

  func configuredValue(for capability: ReminderPolicyCapability) -> Bool? {
    switch capability {
    case .readActive:
      return readActive
    case .readCompleted:
      return readCompleted
    case .add:
      return add
    case .edit:
      return edit
    case .complete:
      return complete
    case .delete:
      return delete
    case .createList:
      return createList
    case .renameList:
      return renameList
    case .deleteList:
      return deleteList
    }
  }

  func setting(_ capability: ReminderPolicyCapability, to value: Bool?) -> ReminderPolicyRule {
    var copy = self
    switch capability {
    case .readActive:
      copy.readActive = value
    case .readCompleted:
      copy.readCompleted = value
    case .add:
      copy.add = value
    case .edit:
      copy.edit = value
    case .complete:
      copy.complete = value
    case .delete:
      copy.delete = value
    case .createList:
      copy.createList = value
    case .renameList:
      copy.renameList = value
    case .deleteList:
      copy.deleteList = value
    }
    return copy
  }

  var isEmpty: Bool {
    ReminderPolicyCapability.allCases.allSatisfy { configuredValue(for: $0) == nil }
  }
}

struct ReminderPolicyDocument: Codable, Equatable, Sendable {
  var defaults: ReminderPolicyRule
  var lists: [String: ReminderPolicyRule]

  static let defaultDocument = ReminderPolicyDocument(defaults: .defaults, lists: [:])
}

struct EffectiveReminderPolicyRule: Codable, Equatable, Sendable {
  let readActive: Bool
  let readCompleted: Bool
  let add: Bool
  let edit: Bool
  let complete: Bool
  let delete: Bool
  let createList: Bool
  let renameList: Bool
  let deleteList: Bool

  func allows(_ capability: ReminderPolicyCapability) -> Bool {
    switch capability {
    case .readActive:
      return readActive
    case .readCompleted:
      return readCompleted
    case .add:
      return add
    case .edit:
      return edit
    case .complete:
      return complete
    case .delete:
      return delete
    case .createList:
      return createList
    case .renameList:
      return renameList
    case .deleteList:
      return deleteList
    }
  }

  func value(for capability: ReminderPolicyCapability) -> Bool {
    allows(capability)
  }
}

enum ReminderPolicyError: LocalizedError, Equatable {
  case blocked(action: String, listName: String, policyPath: String)
  case invalidConfiguration(path: String, details: String)

  var errorDescription: String? {
    switch self {
    case .blocked(let action, let listName, let policyPath):
      return "Policy blocks \(action) for list \"\(listName)\". Update \(policyPath) to change this behavior."
    case .invalidConfiguration(let path, let details):
      return "Invalid policy configuration at \(path): \(details)"
    }
  }
}

struct ReminderPolicy: Sendable {
  private static let overrideEnv = "APPLE_REMINDER_CLI_POLICY_PATH"

  let document: ReminderPolicyDocument
  let location: URL

  static func load(
    fileManager: FileManager = .default,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> ReminderPolicy {
    let location = resolveLocation(environment: environment)
    let document = try loadOrCreateDocument(at: location, fileManager: fileManager)
    return ReminderPolicy(document: document, location: location)
  }

  static func defaultDisplayPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
    displayPath(for: resolveLocation(environment: environment))
  }

  static func saveDocument(
    _ document: ReminderPolicyDocument,
    to location: URL,
    fileManager: FileManager = .default
  ) throws {
    try writeDocument(document, to: location, fileManager: fileManager)
  }

  func allows(_ capability: ReminderPolicyCapability, forListNamed listName: String) -> Bool {
    resolvedRule(forListNamed: listName).allows(capability)
  }

  var defaultRule: EffectiveReminderPolicyRule {
    makeEffectiveRule(defaults: document.defaults, override: nil)
  }

  func effectiveRule(forListNamed listName: String) -> EffectiveReminderPolicyRule {
    resolvedRule(forListNamed: listName)
  }

  func canReadAny(fromListNamed listName: String) -> Bool {
    let rule = resolvedRule(forListNamed: listName)
    return rule.readActive || rule.readCompleted
  }

  func ensureAllowed(_ capability: ReminderPolicyCapability, forListNamed listName: String) throws {
    guard allows(capability, forListNamed: listName) else {
      throw ReminderPolicyError.blocked(
        action: capability.description,
        listName: listName,
        policyPath: displayPath
      )
    }
  }

  func ensureReadable(listName: String) throws {
    guard canReadAny(fromListNamed: listName) else {
      throw ReminderPolicyError.blocked(
        action: "read reminders",
        listName: listName,
        policyPath: displayPath
      )
    }
  }

  func filterReadable(_ reminders: [ReminderItem]) -> [ReminderItem] {
    reminders.filter(canRead)
  }

  func filterVisible(_ lists: [ReminderList]) -> [ReminderList] {
    lists.filter { canReadAny(fromListNamed: $0.title) }
  }

  func canRead(_ reminder: ReminderItem) -> Bool {
    if reminder.isCompleted {
      return allows(.readCompleted, forListNamed: reminder.listName)
    }
    return allows(.readActive, forListNamed: reminder.listName)
  }

  var displayPath: String {
    Self.displayPath(for: location)
  }

  private func resolvedRule(forListNamed listName: String) -> EffectiveReminderPolicyRule {
    makeEffectiveRule(defaults: document.defaults, override: document.lists[listName])
  }

  private func makeEffectiveRule(
    defaults: ReminderPolicyRule,
    override: ReminderPolicyRule?
  ) -> EffectiveReminderPolicyRule {
    EffectiveReminderPolicyRule(
      readActive: override?.readActive ?? defaults.readActive ?? true,
      readCompleted: override?.readCompleted ?? defaults.readCompleted ?? false,
      add: override?.add ?? defaults.add ?? true,
      edit: override?.edit ?? defaults.edit ?? true,
      complete: override?.complete ?? defaults.complete ?? true,
      delete: override?.delete ?? defaults.delete ?? true,
      createList: override?.createList ?? defaults.createList ?? true,
      renameList: override?.renameList ?? defaults.renameList ?? true,
      deleteList: override?.deleteList ?? defaults.deleteList ?? true
    )
  }

  private static func resolveLocation(environment: [String: String]) -> URL {
    if let override = environment[overrideEnv], !override.isEmpty {
      let expanded = NSString(string: override).expandingTildeInPath
      return URL(fileURLWithPath: expanded, isDirectory: false)
    }

    let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    return homeURL
      .appendingPathComponent(".config", isDirectory: true)
      .appendingPathComponent("apple_reminder_cli", isDirectory: true)
      .appendingPathComponent("policy.json", isDirectory: false)
  }

  private static func displayPath(for url: URL) -> String {
    let path = url.path
    let home = NSHomeDirectory()
    if path == home {
      return "~"
    }
    if path.hasPrefix(home + "/") {
      return "~" + String(path.dropFirst(home.count))
    }
    return path
  }

  private static func loadOrCreateDocument(
    at location: URL,
    fileManager: FileManager
  ) throws -> ReminderPolicyDocument {
    if !fileManager.fileExists(atPath: location.path) {
      try writeDefaultDocument(to: location, fileManager: fileManager)
      return .defaultDocument
    }

    do {
      let data = try Data(contentsOf: location)
      return try JSONDecoder().decode(ReminderPolicyDocument.self, from: data)
    } catch {
      throw ReminderPolicyError.invalidConfiguration(
        path: displayPath(for: location),
        details: error.localizedDescription
      )
    }
  }

  private static func writeDefaultDocument(
    to location: URL,
    fileManager: FileManager
  ) throws {
    try writeDocument(.defaultDocument, to: location, fileManager: fileManager)
  }

  private static func writeDocument(
    _ document: ReminderPolicyDocument,
    to location: URL,
    fileManager: FileManager
  ) throws {
    let directory = location.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(document)
    try data.write(to: location, options: .atomic)
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)
  }
}
