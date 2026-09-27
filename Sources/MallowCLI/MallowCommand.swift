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
        Mallow development preview — runtime installation; Windows launching is not enabled
        Usage:
          mallow doctor [--json] [--verify-archive]
          mallow setup --install-runtime --accept-download [--json]
          mallow setup --download-runtime --accept-download [--json]
          mallow setup --install-rosetta --accept-apple-license [--json]
          mallow runtime verify [--json]
          mallow runtime path
        Runtime installation and Rosetta setup may be combined. --download-runtime is cache-only.
        MALLOW_HOME may name an absolute throwaway data root for testing.
        Apple licence: https://www.apple.com/legal/sla/
        """)
      return
    }
    do {
      if let home = ProcessInfo.processInfo.environment["MALLOW_HOME"], !home.hasPrefix("/") || home.utf8.contains(0) {
        throw CLIError.usage
      }
      let service = SetupService()
      if args == ["runtime", "path"] {
        print(try await service.installedRuntimeURL().path); return
      }
      if args == ["runtime", "verify"] || args == ["runtime", "verify", "--json"] {
        let result = try await service.verifyRuntime()
        if args.contains("--json") { try printJSON(result) }
        else {
          print("Runtime verification: \(result.passed ? "passed" : "FAILED")")
          print("Checked \(result.checkedFiles) files / \(result.checkedBytes) bytes in \(String(format: "%.2f", result.elapsedSeconds)) seconds.")
          for problem in result.problems { print(problem) }
        }
        if !result.passed { exit(4) }
        return
      }
      let command = args[0]
      let flags = Set(args.dropFirst())
      let allowed: Set<String> = command == "doctor" ? ["--json", "--verify-archive"] : [
        "--json", "--install-runtime", "--download-runtime", "--accept-download", "--install-rosetta", "--accept-apple-license",
      ]
      guard ["doctor", "setup"].contains(command), flags.isSubset(of: allowed),
        flags.count == args.count - 1 else { throw CLIError.usage }
      if command == "setup" {
        let runtime = flags.contains("--install-runtime")
        let download = flags.contains("--download-runtime")
        let rosetta = flags.contains("--install-rosetta")
        guard runtime || download || rosetta, !(runtime && download) else { throw CLIError.usage }
        guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
        if (runtime || download) && !flags.contains("--accept-download") { throw SetupError.consentRequired }
        if rosetta && !flags.contains("--accept-apple-license") { throw SetupError.consentRequired }
        if rosetta { try await Rosetta.install(licenseAccepted: true) }
        if runtime { _ = try await service.installRuntime(approved: true) }
        else if download { _ = try await service.downloadRuntime(approved: true) }
      }
      let report = try await service.report(verifyArchive: flags.contains("--verify-archive"))
      if flags.contains("--json") { try printJSON(report) }
      else {
        print("Host: \(report.host.system) \(report.host.version); Apple Silicon: \(report.host.isAppleSilicon)")
        print("Rosetta detected: \(report.host.rosettaInstalled)")
        print("Wine archive cached: \(report.runtimeArchiveCached); hash checked now: \(report.runtimeArchiveVerified)")
        print("Wine runtime installed: \(report.runtimeActivated)")
        print("Use 'mallow runtime verify' for a full integrity check. Windows launching and its sandbox are not implemented.")
      }
    } catch {
      try? FileHandle.standardError.write(contentsOf: Data("mallow: \(error.localizedDescription)\n".utf8))
      exit(error is CLIError ? 2 : 3)
    }
  }
  private static func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
  }
  enum CLIError: Error, LocalizedError {
    case usage
    var errorDescription: String? { "Invalid arguments. Run mallow --help for the implemented commands." }
  }
}
