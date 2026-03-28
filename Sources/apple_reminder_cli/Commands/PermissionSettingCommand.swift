import Commander
import Darwin
import Foundation
import RemindCore

enum PermissionSettingCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "permission-setting",
      abstract: "Edit the local per-list policy",
      discussion:
        "Arrow-key editor for ~/.config/apple_reminder_cli/policy.json. "
        + "↑↓ to move, ←→ to change value, Tab to switch list, q to quit.",
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "apple_reminder_cli permission-setting",
      ]
    ) { _, runtime in
      guard Console.isTTY, !runtime.noInput else {
        throw RemindCoreError.operationFailed("permission-setting requires an interactive terminal.")
      }

      let policy = try ReminderPolicy.load()
      let status = RemindersStore.authorizationStatus()
      let discovered = await PolicySupport.discoverListNames(status: status)
      var document = policy.document

      try PermissionSettingEditor.run(
        document: &document,
        saveLocation: policy.location,
        policyPath: policy.displayPath,
        authorizationStatus: status,
        discoveredListNames: discovered
      )
    }
  }
}

// MARK: - Editor

private enum PermissionSettingEditor {

  // MARK: Raw terminal

  private struct RawTerminal {
    private var saved = termios()

    mutating func enable() {
      tcgetattr(STDIN_FILENO, &saved)
      var t = saved
      t.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)
      withUnsafeMutablePointer(to: &t.c_cc.0) { cc in
        cc[Int(VMIN)] = 1
        cc[Int(VTIME)] = 0
      }
      tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }

    func disable() {
      var t = saved
      tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }

    func readKey() -> Key {
      var b: UInt8 = 0
      guard Darwin.read(STDIN_FILENO, &b, 1) == 1 else { return .unknown }

      if b == 27 {
        // Read escape sequence non-blocking to handle standalone ESC gracefully
        let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
        _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
        var b2: UInt8 = 0, b3: UInt8 = 0
        let got2 = Darwin.read(STDIN_FILENO, &b2, 1) == 1
        let got3 = got2 && Darwin.read(STDIN_FILENO, &b3, 1) == 1
        _ = fcntl(STDIN_FILENO, F_SETFL, flags)
        if got2 && got3 && b2 == 91 {
          switch b3 {
          case 65: return .up
          case 66: return .down
          case 67: return .right
          case 68: return .left
          default: break
          }
        }
        return .escape
      }

      switch b {
      case 9: return .tab
      case 10, 13: return .enter
      case 3: return .ctrlC
      default:
        return .char(Character(Unicode.Scalar(b)))
      }
    }
  }

  private enum Key {
    case up, down, left, right, tab, enter, escape, ctrlC
    case char(Character)
    case unknown
  }

  // MARK: State

  private enum Target: Equatable {
    case defaults
    case list(String)

    var title: String {
      switch self {
      case .defaults: return "Defaults"
      case .list(let n): return n
      }
    }
  }

  private struct EditorState {
    var document: ReminderPolicyDocument
    var allListNames: [String]
    var targetIndex = 0
    var capabilityIndex = 0
    var status = "↑↓ field   ←→ value   tab to switch list   q quit"
  }

  // MARK: Entry point

  static func run(
    document: inout ReminderPolicyDocument,
    saveLocation: URL,
    policyPath: String,
    authorizationStatus: RemindersAuthorizationStatus,
    discoveredListNames: [String]
  ) throws {
    var terminal = RawTerminal()
    terminal.enable()
    Swift.print("\u{001B}[?25l", terminator: "")  // hide cursor
    fflush(nil)

    defer {
      terminal.disable()
      Swift.print("\u{001B}[?25h")  // show cursor
      fflush(nil)
    }

    let allListNames = Array(Set(document.lists.keys).union(discoveredListNames)).sorted()
    var state = EditorState(document: document, allListNames: allListNames)
    let capCount = ReminderPolicyCapability.allCases.count

    while true {
      let targets = buildTargets(from: state)
      clamp(&state, targets: targets)
      render(state: state, targets: targets, policyPath: policyPath, authorizationStatus: authorizationStatus)

      switch terminal.readKey() {
      // Navigation
      case .up, .char("k"):
        state.capabilityIndex = max(0, state.capabilityIndex - 1)
      case .down, .char("j"):
        state.capabilityIndex = min(capCount - 1, state.capabilityIndex + 1)
      case .tab, .char("]"):
        state.targetIndex = (state.targetIndex + 1) % targets.count
      case .char("["):
        state.targetIndex = (state.targetIndex + targets.count - 1) % targets.count
      // Value cycling — auto-save on every change
      case .right, .enter, .char("l"):
        cycleValue(&state, targets: targets, direction: 1)
        autosave(&state, to: saveLocation)
      case .left, .char("h"):
        cycleValue(&state, targets: targets, direction: -1)
        autosave(&state, to: saveLocation)
      case .char("q"), .escape, .ctrlC:
        document = state.document
        return
      default:
        break
      }
    }
  }

  private static func autosave(_ state: inout EditorState, to location: URL) {
    do {
      try ReminderPolicy.saveDocument(state.document, to: location)
    } catch {
      state.status = "Save failed: \(error.localizedDescription)"
    }
  }

  // MARK: Mutations

  private static func buildTargets(from state: EditorState) -> [Target] {
    [.defaults] + state.allListNames.map(Target.list)
  }

  private static func clamp(_ state: inout EditorState, targets: [Target]) {
    state.targetIndex = min(state.targetIndex, max(0, targets.count - 1))
    state.capabilityIndex = min(
      state.capabilityIndex,
      ReminderPolicyCapability.allCases.count - 1
    )
  }

  private static func cycleValue(_ state: inout EditorState, targets: [Target], direction: Int) {
    let cap = ReminderPolicyCapability.allCases[state.capabilityIndex]
    switch targets[state.targetIndex] {
    case .defaults:
      let current = state.document.defaults.configuredValue(for: cap) ?? false
      state.document.defaults = state.document.defaults.setting(cap, to: !current)
      state.status = "defaults.\(cap.rawValue) → \(!current ? "allow" : "deny")"
    case .list(let name):
      let current = state.document.lists[name]?.configuredValue(for: cap)
      let next = triCycle(current, direction: direction)
      var rule = state.document.lists[name] ?? ReminderPolicyRule()
      rule = rule.setting(cap, to: next)
      if ReminderPolicyCapability.allCases.allSatisfy({ rule.configuredValue(for: $0) == nil }) {
        state.document.lists.removeValue(forKey: name)
        state.status = "Removed empty override for \(name)."
      } else {
        state.document.lists[name] = rule
        let label = next == nil ? "inherit" : (next! ? "allow" : "deny")
        state.status = "\(name).\(cap.rawValue) → \(label)"
      }
    }
  }

  private static func triCycle(_ value: Bool?, direction: Int) -> Bool? {
    let order: [Bool?] = [nil, true, false]
    guard let i = order.firstIndex(where: { $0 == value }) else { return nil }
    return order[(i + (direction >= 0 ? 1 : order.count - 1)) % order.count]
  }



  // MARK: Rendering

  private static func render(
    state: EditorState,
    targets: [Target],
    policyPath: String,
    authorizationStatus: RemindersAuthorizationStatus
  ) {
    let capW = 26, valW = 13
    let hRule = String(repeating: "─", count: capW)
    let vRule = String(repeating: "─", count: valW)
    let selectedTarget = targets[state.targetIndex]
    let isListTarget: Bool
    if case .list = selectedTarget { isListTarget = true } else { isListTarget = false }

    var out = "\u{001B}[2J\u{001B}[H"

    // Header
    out += "\n  \u{001B}[1mPolicy Editor\u{001B}[0m  \u{001B}[2m\(policyPath)  ·  \(authorizationStatus.displayName)\u{001B}[0m\n\n"

    // Target tabs
    out += "  "
    for (i, t) in targets.enumerated() {
      out += i == state.targetIndex
        ? "\u{001B}[7m \(t.title) \u{001B}[0m"
        : " \u{001B}[2m\(t.title)\u{001B}[0m "
    }
    out += "\n\n"

    // Table
    let headerVal = isListTarget ? " Value (eff)" : " Value"
    out += "  ┌\(hRule)┬\(vRule)┐\n"
    out += "  │\u{001B}[2m\(col(" Capability", capW))\u{001B}[0m│\u{001B}[2m\(col(headerVal, valW))\u{001B}[0m│\n"
    out += "  ├\(hRule)┼\(vRule)┤\n"

    for (i, cap) in ReminderPolicyCapability.allCases.enumerated() {
      let sel = i == state.capabilityIndex
      let marker = sel ? "▶" : " "
      let capCell = col("\(marker) \(cap.description)", capW)
      let valCell = valueCell(cap: cap, target: selectedTarget, document: state.document, width: valW)
      out += sel
        ? "  │\u{001B}[7m\(capCell)\u{001B}[0m│\(valCell)│\n"
        : "  │\(capCell)│\(valCell)│\n"
    }

    out += "  └\(hRule)┴\(vRule)┘\n\n"
    out += "  \u{001B}[2m\(state.status)\u{001B}[0m\n"

    Swift.print(out, terminator: "")
    fflush(nil)
  }

  private static func valueCell(
    cap: ReminderPolicyCapability,
    target: Target,
    document: ReminderPolicyDocument,
    width: Int
  ) -> String {
    switch target {
    case .defaults:
      let v = document.defaults.configuredValue(for: cap) ?? false
      let label = v ? "allow" : "deny"
      let code = v ? "\u{001B}[32m" : "\u{001B}[31m"
      return " \(code)\(label)\u{001B}[0m" + String(repeating: " ", count: width - 1 - label.count)
    case .list(let name):
      let configured = document.lists[name]?.configuredValue(for: cap)
      let eff = document.lists[name]?.configuredValue(for: cap)
        ?? document.defaults.configuredValue(for: cap) ?? false
      let effCode = eff ? "\u{001B}[32m" : "\u{001B}[31m"
      let effChar = eff ? "✓" : "✗"
      switch configured {
      case .some(true):
        return " \u{001B}[32mallow\u{001B}[0m" + String(repeating: " ", count: width - 6)
      case .some(false):
        return " \u{001B}[31mdeny\u{001B}[0m " + String(repeating: " ", count: width - 6)
      case .none:
        return " \u{001B}[2minherit\u{001B}[0m \(effCode)(\(effChar))\u{001B}[0m "
      }
    }
  }

  private static func col(_ s: String, _ width: Int) -> String {
    let n = s.count
    if n >= width { return String(s.prefix(width)) }
    return s + String(repeating: " ", count: width - n)
  }
}
