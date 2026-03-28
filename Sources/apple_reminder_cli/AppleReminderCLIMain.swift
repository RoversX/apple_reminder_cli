import Foundation

@main
enum AppleReminderCLIMain {
  static func main() async {
    let code = await CommandRouter().run()
    exit(code)
  }
}
