// SPDX-License-Identifier: 0BSD
import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Local bounded checks, never a substitute for real Wine/GUI/sandbox testing.
public enum ClientSelfTests {
  @concurrent public static func run() async throws -> [ClientCheck] {
    try Task.checkCancellation()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "mallow-client-check-\(UUID().uuidString)")
    guard mkdir(directory.path, mode_t(0o700)) == 0 else {
      return [
        .init(
          id: "scratch-directory", status: .failed,
          summary: "Could not create private test storage.", elapsedMilliseconds: nil)
      ]
    }
    defer { try? FileManager.default.removeItem(at: directory) }
    var checks: [ClientCheck] = []
    func record(_ id: String, _ body: () throws -> Bool) {
      let start = ContinuousClock.now
      let passed = (try? body()) == true
      checks.append(
        .init(
          id: id, status: passed ? .passed : .failed,
          summary: passed
            ? "Local check passed." : "Local check failed; no personal file content was collected.",
          elapsedMilliseconds: ClientDiagnostics.milliseconds(since: start)))
    }
    record("atomic-json") {
      let file = directory.appendingPathComponent("roundtrip.json")
      try JSONStore.writeAtomically(["value": 1], to: file)
      try JSONStore.writeAtomically(["value": 2], to: file)
      return try JSONStore.read([String: Int].self, from: file) == ["value": 2]
    }
    record("exclusive-lock") {
      let lock = directory.appendingPathComponent("probe.lock")
      return try FileLock.withExclusiveLock(lock) {
        do {
          try FileLock.withExclusiveLock(lock, timeout: .zero) {}
          return false
        } catch SetupError.busy { return true }
      }
    }
    try Task.checkCancellation()
    let start = ContinuousClock.now
    #if canImport(CryptoKit)
      let vector = directory.appendingPathComponent("vector")
      do {
        try Data("abc".utf8).write(to: vector, options: .withoutOverwriting)
        let digest = try await SHA256DownloadHasher().sha256(of: vector)
        checks.append(
          .init(
            id: "sha256-vector",
            status: digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
              ? .passed : .failed,
            summary: "CryptoKit checked against the SHA-256 abc known-answer vector.",
            elapsedMilliseconds: ClientDiagnostics.milliseconds(since: start)))
      } catch is CancellationError { throw CancellationError() } catch {
        checks.append(
          .init(
            id: "sha256-vector", status: .failed, summary: "The local checksum check failed.",
            elapsedMilliseconds: ClientDiagnostics.milliseconds(since: start)))
      }
    #else
      checks.append(
        .init(
          id: "sha256-vector", status: .warning,
          summary: "CryptoKit unavailable on this host; the checksum check was not run.",
          elapsedMilliseconds: nil))
    #endif
    record("download-policy") {
      let spec = BuiltinComponents.standardWine
      try spec.validate()
      return !spec.permits(URL(string: "http://github.com/untrusted")!)
        && !spec.permits(URL(string: "https://github.com.example.invalid/archive")!)
    }
    try Task.checkCancellation()
    return checks
  }
}
