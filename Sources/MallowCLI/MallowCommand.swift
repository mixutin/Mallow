// SPDX-License-Identifier: 0BSD
import Foundation
import MallowKit
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main struct MallowCommand {
  static func main() async {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.isEmpty || args == ["--help"] || args == ["-h"] {
      print("""
        Mallow development bootstrap — no Windows launching yet
        Usage:
          mallow doctor [--json]
          mallow setup --download-runtime --accept-download [--json]
          mallow setup --install-rosetta --accept-apple-license [--json]
        The two setup operations can be combined. Runtime download is acquisition only,
        not installation. Apple licence: https://www.apple.com/legal/sla/
        """)
      return
    }
    do {
      let command = args[0]
      let flags = Set(args.dropFirst())
      let allowed: Set<String> = command == "doctor" ? ["--json"] : [
        "--json", "--download-runtime", "--accept-download", "--install-rosetta", "--accept-apple-license",
      ]
      guard ["doctor", "setup"].contains(command), flags.isSubset(of: allowed),
        flags.count == args.count - 1 else { throw CLIError.usage }
      let service = SetupService()
      if command == "setup" {
        guard flags.contains("--download-runtime") || flags.contains("--install-rosetta") else { throw CLIError.usage }
        guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
        // Preflight both consents before any side effect, including when operations are combined.
        if flags.contains("--download-runtime") && !flags.contains("--accept-download") { throw SetupError.consentRequired }
        if flags.contains("--install-rosetta") && !flags.contains("--accept-apple-license") { throw SetupError.consentRequired }
        if flags.contains("--install-rosetta") { try await Rosetta.install(licenseAccepted: true) }
        if flags.contains("--download-runtime") { _ = try await service.downloadRuntime(approved: true) }
      }
      let report = try await service.report()
      if flags.contains("--json") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
      } else {
        print("Host: \(report.host.system) \(report.host.version); Apple Silicon: \(report.host.isAppleSilicon)")
        print("Rosetta detected: \(report.host.rosettaInstalled)")
        print("Wine archive verified: \(report.runtimeArchiveVerified)")
        print("Wine activation and sandbox: not implemented. Windows launching is disabled.")
      }
    } catch {
      let message = "mallow: \(error.localizedDescription)\n"
      try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
      exit(error is CLIError ? 2 : 3)
    }
  }
  enum CLIError: Error, LocalizedError {
    case usage
    var errorDescription: String? { "Invalid arguments. Run mallow --help for the implemented commands." }
  }
}
