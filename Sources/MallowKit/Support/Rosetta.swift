// SPDX-License-Identifier: 0BSD
import Foundation

public enum Rosetta {
  // DESIGN.md §3.4.1 and Apple's Rosetta support article:
  // https://support.apple.com/en-us/102527. No licence is accepted on first launch.
  public static let marker = URL(filePath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
  public static let licenseURL = URL(string: "https://www.apple.com/legal/sla/")!
  public static let interactiveCommand = ["/usr/sbin/softwareupdate", "--install-rosetta"]
  public static func isInstalled() -> Bool { FileManager.default.fileExists(atPath: marker.path) }

  public static func installationArguments(licenseAccepted: Bool) throws -> [String] {
    guard licenseAccepted else { throw SetupError.consentRequired }
    // softwareupdate's documented --agree-to-license is only used after explicit consent.
    return ["--install-rosetta", "--agree-to-license"]
  }

  @concurrent public static func install(licenseAccepted: Bool) async throws {
    let arguments = try installationArguments(licenseAccepted: licenseAccepted)
    guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
    if isInstalled() { return }
    let log = FileManager.default.temporaryDirectory.appendingPathComponent("mallow-rosetta-\(UUID().uuidString).log")
    guard FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
    else { throw CocoaError(.fileWriteUnknown) }
    defer { try? FileManager.default.removeItem(at: log) }
    let output = try FileHandle(forWritingTo: log)
    defer { try? output.close() }
    let process = Process()
    process.executableURL = URL(filePath: "/usr/sbin/softwareupdate")
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output; process.standardError = output
    try process.run()
    defer { if process.isRunning { process.terminate() } }
    while process.isRunning { try await Task.sleep(for: .milliseconds(100)) }
    try Task.checkCancellation()
    guard process.terminationStatus == 0, isInstalled() else {
      let text = (try? String(contentsOf: log, encoding: .utf8)) ?? "No installer output."
      throw SetupError.rosettaFailed(String(text.suffix(4000)))
    }
  }
}
