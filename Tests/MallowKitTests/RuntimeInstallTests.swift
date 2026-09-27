// SPDX-License-Identifier: 0BSD
import CArchive
import Foundation
import Testing
@testable import MallowKit

@Suite struct RuntimeInstallTests {
  struct Entry {
    var path: String
    var text = "test"
    var kind: UInt32 = UInt32(MALLOW_ARCHIVE_IFREG)
    var permissions: Int32 = 0o755
    var link: String? = nil
    var hardLink = false
  }
  let prefix = "Wine Stable.app/Contents/Resources/wine/bin/"
  func temporary() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mallow-install-tests-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    return root
  }
  func archive(_ entries: [Entry], at url: URL) throws {
    let writer = try #require(archive_write_new())
    defer { archive_write_free(writer) }
    #expect(archive_write_set_format_pax_restricted(writer) == ARCHIVE_OK)
    #expect(archive_write_open_filename(writer, url.path) == ARCHIVE_OK)
    for item in entries {
      let entry = try #require(archive_entry_new())
      defer { archive_entry_free(entry) }
      archive_entry_set_pathname(entry, item.path)
      archive_entry_set_filetype(entry, item.kind)
      archive_entry_set_perm(entry, mode_t(item.permissions))
      if let link = item.link {
        if item.hardLink { archive_entry_set_hardlink(entry, link) }
        else { archive_entry_set_symlink(entry, link) }
      }
      let data = Data(item.text.utf8)
      archive_entry_set_size(entry, item.kind == MALLOW_ARCHIVE_IFREG && item.link == nil ? Int64(data.count) : 0)
      #expect(archive_write_header(writer, entry) == ARCHIVE_OK)
      if item.kind == MALLOW_ARCHIVE_IFREG && item.link == nil {
        let written = data.withUnsafeBytes { archive_write_data(writer, $0.baseAddress, $0.count) }
        #expect(written == data.count)
      }
      #expect(archive_write_finish_entry(writer) == ARCHIVE_OK)
    }
    #expect(archive_write_close(writer) == ARCHIVE_OK)
  }
  struct Hasher: DownloadHasher {
    func sha256(of url: URL) async throws -> String {
      if url.lastPathComponent == "source.tar.xz" { return BuiltinComponents.standardWine.sha256 }
      return try Data(contentsOf: url).base64EncodedString()
    }
  }
  func installFixture(_ root: URL, entries: [Entry]? = nil) async throws -> (StandardWineInstaller, URL) {
    let source = root.appendingPathComponent("fixture.tar")
    try archive(entries ?? [Entry(path: prefix + "wine"), Entry(path: prefix + "wineserver")], at: source)
    let file = try FileHandle(forWritingTo: source)
    try file.truncate(atOffset: UInt64(BuiltinComponents.standardWine.size))
    try file.close()
    let installer = StandardWineInstaller(paths: MallowPaths(root: root.appendingPathComponent("data")), hasher: Hasher())
    let destination = try await installer.installVerifiedArchive(source)
    return (installer, destination)
  }

  @Test func installsAndVerifiesAndReusesWithoutExtractingAgain() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let (installer, destination) = try await installFixture(root)
    #expect(try await installer.isInstalled())
    let report = try await installer.verify()
    #expect(report.passed && report.checkedFiles == 2 && report.checkedBytes == 8)
    #expect(try await installer.installVerifiedArchive(root.appendingPathComponent("missing.tar")) == destination)
    #expect(!(try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path))
      .contains(where: { $0.hasPrefix(".install-") }))
  }
  @Test func detectsModifiedMissingAndUnexpectedFiles() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let (installer, destination) = try await installFixture(root)
    try Data("edit".utf8).write(to: destination.appendingPathComponent(prefix + "wine"))
    try FileManager.default.removeItem(at: destination.appendingPathComponent(prefix + "wineserver"))
    try Data("extra".utf8).write(to: destination.appendingPathComponent("extra"))
    let report = try await installer.verify()
    #expect(!report.passed && report.problems.count == 3)
    await #expect(throws: RuntimeInstallError.self) {
      _ = try await installer.installVerifiedArchive(root.appendingPathComponent("fixture.tar"))
    }
    #expect(try Data(contentsOf: destination.appendingPathComponent(prefix + "wine")) == Data("edit".utf8))
  }
  @Test func metadataCheckDoesNotHashInstalledFiles() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let (installer, destination) = try await installFixture(root)
    try Data("edit".utf8).write(to: destination.appendingPathComponent(prefix + "wine"))
    #expect(try await installer.isInstalled())
    #expect(try await installer.verify().passed == false)
  }
  @Test func refusesFutureReceiptWithoutChangingIt() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let (installer, destination) = try await installFixture(root)
    let url = destination.appendingPathComponent(".mallow-install.json")
    let text = try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":999")
    try Data(text.utf8).write(to: url)
    await #expect(throws: (any Error).self) { _ = try await installer.verify() }
    #expect(try String(contentsOf: url, encoding: .utf8) == text)
  }
  @Test func noConsentDoesNotCreateDirectories() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let data = root.appendingPathComponent("data")
    let installer = StandardWineInstaller(paths: MallowPaths(root: data))
    await #expect(throws: SetupError.self) {
      _ = try await installer.install(archive: root.appendingPathComponent("none"), approved: false)
    }
    #expect(!FileManager.default.fileExists(atPath: data.path))
  }
  @Test func cancellationBeforeInstallHasNoEffects() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let data = root.appendingPathComponent("data")
    let installer = StandardWineInstaller(paths: MallowPaths(root: data))
    let task = Task {
      while !Task.isCancelled { await Task.yield() }
      return try await installer.installVerifiedArchive(root.appendingPathComponent("none"))
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    #expect(!FileManager.default.fileExists(atPath: data.path))
  }
  @Test func invalidLayoutLeavesNoActiveRuntime() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    await #expect(throws: (any Error).self) { _ = try await installFixture(root, entries: [Entry(path: "not-wine")]) }
    let runtimes = root.appendingPathComponent("data/Runtimes")
    #expect(try FileManager.default.contentsOfDirectory(atPath: runtimes.path) == [".lock"])
  }
  @Test(arguments: ["../escape", "/tmp/escape", "a/../../escape", "a\\b", "bad\nname"])
  func rejectsTraversal(path: String) async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("input.tar")
    let output = root.appendingPathComponent("output")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    try archive([Entry(path: path)], at: source)
    await #expect(throws: ArchiveError.self) { try await ArchiveExtractor().extract(source, into: output) }
  }
  @Test func linksCannotRedirectLaterWrites() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("input.tar")
    let output = root.appendingPathComponent("output")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    try archive([Entry(path: "link", kind: MALLOW_ARCHIVE_IFLNK, link: "../"), Entry(path: "link/escape")], at: source)
    await #expect(throws: ArchiveError.self) { try await ArchiveExtractor().extract(source, into: output) }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("escape").path))
  }
  @Test func permitsConfinedSymlinkAndHardlink() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("input.tar")
    let output = root.appendingPathComponent("output")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    try archive([Entry(path: "bin/wine"), Entry(path: "bin/wine64", kind: MALLOW_ARCHIVE_IFLNK, link: "wine"),
      Entry(path: "hard", link: "bin/wine", hardLink: true)], at: source)
    try await ArchiveExtractor().extract(source, into: output)
    #expect(try Data(contentsOf: output.appendingPathComponent("bin/wine64")) == Data("test".utf8))
    #expect(try Data(contentsOf: output.appendingPathComponent("hard")) == Data("test".utf8))
  }
  @Test func refusesDuplicateAndSpecialEntries() async throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    for (index, entries) in [[Entry(path: "a"), Entry(path: "A")], [Entry(path: "suid", permissions: 0o4755)],
      [Entry(path: "pipe", kind: 0o010000)]].enumerated() {
      let source = root.appendingPathComponent("input\(index).tar")
      let output = root.appendingPathComponent("output\(index)")
      try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
      try archive(entries, at: source)
      await #expect(throws: ArchiveError.self) { try await ArchiveExtractor().extract(source, into: output) }
    }
  }
  @Test func refusesForeignAndSymlinkDataRoots() throws {
    let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
    #expect(throws: (any Error).self) { try MallowPaths(root: root).ensureDirectories() }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
    #expect(throws: (any Error).self) { try MallowPaths(root: link).ensureDirectories() }
  }
}
