// SPDX-License-Identifier: 0BSD
import Foundation
import Testing
@testable import MallowKit

@Suite struct SetupServiceTests {
  private let goodHash = String(repeating: "a", count: 64)
  private let payload = Data("fixture".utf8)
  private func spec(fileName: String = "fixture.tar.xz", size: Int64 = 7, digest: String? = nil) -> DownloadSpec {
    DownloadSpec(id: "fixture", fileName: fileName, url: URL(string: "https://example.test/fixture")!,
      size: size, sha256: digest ?? goodHash, allowedHosts: ["example.test"])
  }
  private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mallow-setup-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    return root
  }
  private struct Transport: DownloadTransport {
    let data: Data
    var fail = false
    func download(_ spec: DownloadSpec, to destination: URL,
      progress: @escaping @Sendable (SetupProgress) -> Void) async throws {
      try data.write(to: destination, options: .withoutOverwriting)
      if fail { throw CancellationError() }
      progress(.init(phase: .downloading, received: Int64(data.count), expected: spec.size))
    }
  }
  private struct Hasher: DownloadHasher {
    let digest: String
    func sha256(of url: URL) async throws -> String { digest }
  }

  @Test func compiledPinIsValid() throws {
    try BuiltinComponents.standardWine.validate()
    #expect(BuiltinComponents.standardWine.size == 185303032)
    #expect(BuiltinComponents.standardWine.sha256 == "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388")
  }
  @Test(arguments: ["http://example.test/a", "https://evil.test/a", "https://example.test.evil.test/a",
    "https://user:password@example.test/a", "https://example.test:444/a", "file:///tmp/a"])
  func rejectsUnsafeDestination(value: String) {
    #expect(!spec().permits(URL(string: value)!))
  }
  @Test(arguments: ["", ".", "..", "../escape", "/tmp/escape", "nested/file", "nested\\file", "bad\0name"])
  func rejectsUnsafeFilename(value: String) {
    #expect(throws: SetupError.invalidDownload) { try spec(fileName: value).validate() }
  }
  @Test func requiresExplicitAppleConsent() throws {
    #expect(throws: SetupError.consentRequired) { try Rosetta.installationArguments(licenseAccepted: false) }
    #expect(try Rosetta.installationArguments(licenseAccepted: true) == ["--install-rosetta", "--agree-to-license"])
  }
  @Test func reportsNeverClaimWindowsReadiness() throws {
    let host = SetupHost(system: "macOS", version: "15.0.0", majorVersion: 15, isAppleSilicon: true, rosettaInstalled: true)
    let report = SetupReport(host: host, runtimeArchiveVerified: true, runtimeID: "test")
    #expect(host.supported)
    #expect(!report.readyToRunWindows && !report.runtimeActivated && !report.sandboxImplemented)
    let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
    #expect(json["readyToRunWindows"] as? Bool == false)
  }
  @Test func rejectsOldMacAndIntel() {
    #expect(!SetupHost(system: "macOS", version: "14.0", majorVersion: 14, isAppleSilicon: true, rosettaInstalled: true).supported)
    #expect(!SetupHost(system: "macOS", version: "26.0", majorVersion: 26, isAppleSilicon: false, rosettaInstalled: true).supported)
  }
  @Test func noConsentHasNoFilesystemEffects() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let cache = root.appendingPathComponent("cache")
    let service = SetupService(cacheDirectory: cache, transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    await #expect(throws: SetupError.consentRequired) { try await service.acquire(spec(), approved: false) }
    #expect(!FileManager.default.fileExists(atPath: cache.path))
  }
  @Test func successfulAcquisitionReusesVerifiedCache() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let cache = root.appendingPathComponent("cache")
    let service = SetupService(cacheDirectory: cache, transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    let first = try await service.acquire(spec(), approved: true)
    #expect(try Data(contentsOf: first) == payload)
    let offline = SetupService(cacheDirectory: cache, transport: Transport(data: Data(), fail: true), hasher: Hasher(digest: goodHash))
    #expect(try await offline.acquire(spec(), approved: true) == first)
  }
  @Test func mismatchAndCancellationRemoveStaging() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    for fail in [false, true] {
      let cache = root.appendingPathComponent(fail ? "cancel" : "mismatch")
      let service = SetupService(cacheDirectory: cache, transport: Transport(data: payload, fail: fail), hasher: Hasher(digest: "wrong"))
      await #expect(throws: (any Error).self) { try await service.acquire(spec(), approved: true) }
      let entries = try FileManager.default.contentsOfDirectory(atPath: cache.path)
      #expect(!entries.contains(spec().fileName))
      #expect(!entries.contains(where: { $0.hasPrefix(".download-") }))
    }
  }
  @Test func rejectsWrongSize() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let service = SetupService(cacheDirectory: root.appendingPathComponent("cache"), transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    await #expect(throws: SetupError.unexpectedSize) { try await service.acquire(spec(size: 99), approved: true) }
  }
  @Test func refusesUnownedDirectory() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let userFile = root.appendingPathComponent("keep.txt")
    try payload.write(to: userFile)
    let service = SetupService(cacheDirectory: root, transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    await #expect(throws: SetupError.unsafeCache) { try await service.acquire(spec(), approved: true) }
    #expect(try Data(contentsOf: userFile) == payload)
  }
  @Test func refusesSymlinkRoot() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
    let service = SetupService(cacheDirectory: link, transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    await #expect(throws: SetupError.unsafeCache) { try await service.acquire(spec(), approved: true) }
  }
  @Test func failedRepairKeepsPreviousFile() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let cache = root.appendingPathComponent("cache")
    let service = SetupService(cacheDirectory: cache, transport: Transport(data: payload), hasher: Hasher(digest: goodHash))
    let destination = try await service.acquire(spec(), approved: true)
    let failing = SetupService(cacheDirectory: cache, transport: Transport(data: Data("wrong!!".utf8)), hasher: Hasher(digest: "bad"))
    await #expect(throws: SetupError.checksumMismatch) { try await failing.acquire(spec(), approved: true) }
    #expect(try Data(contentsOf: destination) == payload)
  }
  @Test func lockExcludesOtherOpenDescriptionsAndReleasesOnThrow() throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let lock = root.appendingPathComponent("lock")
    var excluded = false
    do {
      try FileLock.withExclusiveLock(lock) {
        do { try FileLock.withExclusiveLock(lock, timeout: .zero) {} }
        catch SetupError.busy { excluded = true }
        throw SetupError.rejectedResponse
      }
      Issue.record("Expected the body error to propagate")
    } catch SetupError.rejectedResponse {}
    #expect(excluded)
    try FileLock.withExclusiveLock(lock, timeout: .zero) {}
  }
  #if canImport(CryptoKit)
  @Test func cryptoKitHashesKnownVector() async throws {
    let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("vector")
    try Data("abc".utf8).write(to: file)
    #expect(try await SHA256DownloadHasher().sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  }
  #endif
}
