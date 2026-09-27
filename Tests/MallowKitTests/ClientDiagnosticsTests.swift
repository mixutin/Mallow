// SPDX-License-Identifier: 0BSD
import Foundation
import Testing

@testable import MallowKit

@Suite struct ClientDiagnosticsTests {
  private func temporary() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "mallow-diagnostics-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    return directory
  }
  private func thin(_ cpu: UInt32, little: Bool = true) -> Data {
    var bytes = [UInt8](repeating: 0, count: 32)
    let words: [UInt32] = [0xfeed_facf, cpu]
    for (index, value) in words.enumerated() {
      for shift in 0..<4 {
        bytes[index * 4 + shift] = UInt8(
          truncatingIfNeeded: value >> ((little ? shift : 3 - shift) * 8))
      }
    }
    return Data(bytes)
  }
  @Test(arguments: [true, false]) func thinHeaders(little: Bool) throws {
    #expect(
      try MachOHeader.cpuTypes(in: thin(MachOHeader.x86_64, little: little)) == [MachOHeader.x86_64]
    )
    #expect(
      try MachOHeader.cpuTypes(in: thin(MachOHeader.arm64, little: little)) == [MachOHeader.arm64])
  }
  @Test func universalHeader() throws {
    var bytes = Data([0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 2])
    bytes.append(contentsOf: [1, 0, 0, 7] + [UInt8](repeating: 0, count: 16))
    bytes.append(contentsOf: [1, 0, 0, 12] + [UInt8](repeating: 0, count: 16))
    #expect(try MachOHeader.cpuTypes(in: bytes) == [MachOHeader.x86_64, MachOHeader.arm64])
  }
  @Test(arguments: [0, 1, 3, 4, 7, 27, 31]) func truncatedHeaders(length: Int) {
    #expect(throws: (any Error).self) {
      try MachOHeader.cpuTypes(in: thin(MachOHeader.x86_64).prefix(length))
    }
  }
  @Test func malformedAndOversizedFatHeader() {
    for bytes: [UInt8] in [
      [0, 0, 0, 0], [0xca, 0xfe, 0xba, 0xbe, 0, 0, 0, 0],
      [0xca, 0xfe, 0xba, 0xbe, 0xff, 0xff, 0xff, 0xff], [0xca, 0xfe, 0xba, 0xbf, 0, 0, 0, 1],
    ] {
      #expect(throws: (any Error).self) { try MachOHeader.cpuTypes(in: Data(bytes)) }
    }
  }
  @Test func architectureDetectionIsReadOnly() throws {
    let root = try temporary()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("not-an-executable")
    try thin(MachOHeader.arm64).write(to: file)
    #expect(ClientDiagnostics.architectureCheck(id: "test", at: file).status == .failed)
    try thin(MachOHeader.x86_64).write(to: file)
    #expect(ClientDiagnostics.architectureCheck(id: "test", at: file).status == .passed)
    #expect(try Data(contentsOf: file) == thin(MachOHeader.x86_64))
    #expect(ClientDiagnostics.architectureCheck(id: "test", at: root).status == .failed)
    #expect(
      ClientDiagnostics.architectureCheck(id: "test", at: root.appendingPathComponent("missing"))
        .status == .warning)
  }
  @Test func buildMetadataCannotInjectPathsOrTokens() {
    let build = ClientBuild(
      revision: "/Users/private/token", number: "secret", configuration: "../../credentials")
    #expect(
      build.revision == "unknown" && build.number == "unknown" && build.configuration == "unknown")
    let good = ClientBuild(
      revision: String(repeating: "a", count: 40), number: "12", configuration: "debug")
    #expect(good.number == "12" && good.configuration == "debug")
  }
  @Test func captureDoesNotCreateDataRootAndReportsBlockers() async throws {
    let root = try temporary()
    defer { try? FileManager.default.removeItem(at: root) }
    let absent = root.appendingPathComponent("absent")
    let report = try await ClientDiagnostics(paths: .init(root: absent)).capture()
    #expect(!FileManager.default.fileExists(atPath: absent.path))
    #expect(report.checks.contains { $0.id == "runtime-metadata" && $0.status == .warning })
    #expect(report.checks.contains { $0.id == "kernel-sandbox" && $0.status == .notImplemented })
    #expect(!report.windowsLaunching && !report.sandboxImplemented && report.selfTests == nil)
    #expect(!report.selfTestsPassed && report.captureMilliseconds >= 0)
  }
  @Test func reportExcludesPathsAndRawIntegrityProblems() async throws {
    let root = try temporary()
    defer { try? FileManager.default.removeItem(at: root) }
    let integrity = RuntimeIntegrityReport(
      runtimeID: "private-runtime", checkedFiles: 1, checkedBytes: 3,
      elapsedSeconds: 0.5, problems: ["Unexpected: /Users/private/secret=TOKEN"])
    let report = try await ClientDiagnostics(paths: .init(root: root)).capture(
      lastIntegrity: .init(integrity),
      operations: Array(
        repeating: .init(action: .install, outcome: .failed, elapsedMilliseconds: 2), count: 100))
    let data = try report.json()
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains("TOKEN") && !text.contains("/Users/") && !text.contains(root.path))
    #expect(!text.contains("private-runtime") && !text.contains("environment"))
    #expect(report.lastIntegrity?.problemCount == 1 && report.recentOperations.count == 32)
    #expect(report.checks.contains { $0.id == "runtime-metadata" && $0.status == .failed })
    #expect(data.count < 262144)
    #expect(try JSONDecoder.withDates.decode(ClientReport.self, from: data).schemaVersion == 1)
  }
  @Test func exportPreservesExistingFileAndSymlink() async throws {
    let root = try temporary()
    defer { try? FileManager.default.removeItem(at: root) }
    let report = try await ClientDiagnostics(
      paths: .init(root: root.appendingPathComponent("missing"))
    ).capture()
    let file = root.appendingPathComponent("report.json")
    try await report.writeNewFile(to: file)
    let saved = try Data(contentsOf: file)
    await #expect(throws: (any Error).self) { try await report.writeNewFile(to: file) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
    await #expect(throws: (any Error).self) { try await report.writeNewFile(to: link) }
    #expect(try Data(contentsOf: file) == saved)
    let mode =
      try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
    #expect(mode?.intValue == 0o600)
    await #expect(throws: (any Error).self) {
      try await report.writeNewFile(to: URL(string: "https://example.invalid/report")!)
    }
  }
  @Test func clientSelfTestsRunAndAreExplicit() async throws {
    let checks = try await ClientSelfTests.run()
    #expect(
      Set(checks.map(\.id)) == [
        "atomic-json", "exclusive-lock", "sha256-vector", "download-policy",
      ])
    #expect(checks.filter { $0.id != "sha256-vector" }.allSatisfy { $0.status == .passed })
    #if canImport(CryptoKit)
      #expect(checks.allSatisfy { $0.status == .passed })
    #else
      #expect(checks.contains { $0.id == "sha256-vector" && $0.status == .warning })
    #endif
  }
  @Test func cancelledCaptureDoesNotCreateRoot() async throws {
    let root = try temporary()
    defer { try? FileManager.default.removeItem(at: root) }
    let missing = root.appendingPathComponent("missing")
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await ClientDiagnostics(paths: .init(root: missing)).capture(runSelfTests: true)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(!FileManager.default.fileExists(atPath: missing.path))
  }
  @Test func operationTimingRejectsInvalidValues() {
    #expect(
      ClientOperation(action: .install, outcome: .failed, elapsedMilliseconds: .infinity)
        .elapsedMilliseconds == 0)
    #expect(
      ClientOperation(action: .install, outcome: .failed, elapsedMilliseconds: -1)
        .elapsedMilliseconds == 0)
  }
}
extension JSONDecoder {
  fileprivate static var withDates: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
