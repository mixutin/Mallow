// SPDX-License-Identifier: 0BSD
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum RuntimeInstallError: Error, LocalizedError, Sendable {
  case invalidLayout, damagedInstallation, noInstallation, unsupportedReceipt, notEnoughSpace
  public var errorDescription: String? {
    switch self {
    case .invalidLayout: "The verified archive does not contain the expected confined Wine Stable.app layout."
    case .damagedInstallation: "The existing runtime failed verification. It was preserved; do not use it."
    case .noInstallation: "Install the Wine runtime before checking its files."
    case .unsupportedReceipt: "The runtime receipt is invalid or from an unsupported version. Nothing was changed."
    case .notEnoughSpace: "Runtime installation requires at least 2 GB of free space for staging and verification."
    }
  }
}

public struct RuntimeIntegrityReport: Codable, Sendable, Equatable {
  public let runtimeID: String
  public let checkedFiles: Int
  public let checkedBytes: Int64
  public let elapsedSeconds: Double
  public let problems: [String]
  public var passed: Bool { problems.isEmpty }
}

struct RuntimeFileRecord: Codable, Sendable {
  var path: String
  var kind: String
  var size: Int64?
  var sha256: String?
  var target: String?
  var executable: Bool?
}

struct RuntimeInstallReceipt: Codable, Sendable {
  var schemaVersion = 1
  var runtimeID: String
  var archiveSHA256: String
  var installedAt: Date
  var files: [RuntimeFileRecord]
}

/// Installs only the compiled-in Wine pin, never a user-selected or catalog-supplied executable.
/// Acquisition, installation, integrity, and readiness to launch Windows are distinct states.
public actor StandardWineInstaller {
  public let paths: MallowPaths
  private let hasher: any DownloadHasher
  private let fm = FileManager.default
  private static let receiptName = ".mallow-install.json"
  private static let wineRoot = "Wine Stable.app/Contents/Resources/wine"
  private static let required = [wineRoot + "/bin/wine", wineRoot + "/bin/wineserver"]

  public init(paths: MallowPaths = .standard, hasher: any DownloadHasher = SHA256DownloadHasher()) {
    self.paths = paths; self.hasher = hasher
  }

  public var installationURL: URL {
    paths.runtimes.appendingPathComponent(BuiltinComponents.standardWine.id, isDirectory: true)
  }

  /// A bounded metadata/layout check. No archive or runtime hashing on ordinary app startup.
  public func isInstalled() throws -> Bool {
    guard (try? fm.attributesOfItem(atPath: paths.root.path)) != nil else { return false }
    try paths.validate()
    guard (try? fm.attributesOfItem(atPath: paths.runtimes.path)) != nil else { return false }
    try MallowPaths.requireOwnedDirectory(paths.runtimes)
    guard (try? fm.attributesOfItem(atPath: installationURL.path)) != nil else { return false }
    _ = try loadReceipt(at: installationURL)
    try validateLayout(at: installationURL)
    return true
  }

  public func install(archive: URL, approved: Bool,
    progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> URL {
    guard approved else { throw SetupError.consentRequired }
    guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
    return try await installVerifiedArchive(archive, progress: progress)
  }

  // Internal entry permits hermetic tests on Linux; production entry always checks the host.
  func installVerifiedArchive(_ archive: URL,
    progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> URL {
    try Task.checkCancellation()
    try paths.ensureDirectories()
    let lock = try FileLock.acquire(paths.runtimes.appendingPathComponent(".lock"))
    defer { FileLock.release(lock) }
    if (try? fm.attributesOfItem(atPath: installationURL.path)) != nil {
      let report = try await verifyUnlocked(progress: progress)
      guard report.passed else { throw RuntimeInstallError.damagedInstallation }
      return installationURL
    }
    let free = try fm.attributesOfFileSystem(forPath: paths.runtimes.path)[.systemFreeSize] as? NSNumber
    guard let free, free.int64Value >= 2_000_000_000 else { throw RuntimeInstallError.notEnoughSpace }
    let staging = paths.runtimes.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
    guard mkdir(staging.path, mode_t(0o700)) == 0 else { throw DataRootError.foreignRoot }
    defer { try? fm.removeItem(at: staging) }
    let payload = staging.appendingPathComponent("payload", isDirectory: true)
    try fm.createDirectory(at: payload, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let snapshot = staging.appendingPathComponent("source.tar.xz")
    // Copy into private staging before checking the hash, so extraction uses those same checked bytes.
    try MallowPaths.requireLocal(archive)
    let sourceInfo = try fm.attributesOfItem(atPath: archive.path)
    guard sourceInfo[.type] as? FileAttributeType == .typeRegular else { throw SetupError.unsafeCache }
    try fm.copyItem(at: archive, to: snapshot)
    let spec = BuiltinComponents.standardWine
    guard (try fm.attributesOfItem(atPath: snapshot.path)[.size] as? NSNumber)?.int64Value == spec.size
    else { throw SetupError.unexpectedSize }
    progress(.init(phase: .verifying, received: spec.size, expected: spec.size))
    guard try await hasher.sha256(of: snapshot) == spec.sha256 else { throw SetupError.checksumMismatch }
    try Task.checkCancellation()
    progress(.init(phase: .extracting, received: 0, expected: 0))
    try await ArchiveExtractor().extract(snapshot, into: payload)
    try validateLayout(at: payload)
    progress(.init(phase: .checkingFiles, received: 0, expected: 0))
    let records = try await inventory(at: payload)
    let receipt = RuntimeInstallReceipt(runtimeID: spec.id, archiveSHA256: spec.sha256,
      installedAt: Date(), files: records)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(receipt).write(to: payload.appendingPathComponent(Self.receiptName), options: .withoutOverwriting)
    try Task.checkCancellation()
    progress(.init(phase: .installing, received: 0, expected: 0))
    // Same-filesystem rename publishes only a complete tree. It never overwrites an existing runtime.
    // No downloaded program is executed, and no system-wide Gatekeeper setting is changed.
    try fm.moveItem(at: payload, to: installationURL)
    progress(.init(phase: .installed, received: 1, expected: 1))
    return installationURL
  }

  public func verify(progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> RuntimeIntegrityReport {
    guard (try? fm.attributesOfItem(atPath: installationURL.path)) != nil else { throw RuntimeInstallError.noInstallation }
    try paths.validate()
    try MallowPaths.requireOwnedDirectory(paths.runtimes)
    let lock = try FileLock.acquire(paths.runtimes.appendingPathComponent(".lock"))
    defer { FileLock.release(lock) }
    return try await verifyUnlocked(progress: progress)
  }

  private func loadReceipt(at root: URL) throws -> RuntimeInstallReceipt {
    try MallowPaths.requireOwnedDirectory(root)
    let url = root.appendingPathComponent(Self.receiptName)
    let attrs = try fm.attributesOfItem(atPath: url.path)
    guard attrs[.type] as? FileAttributeType == .typeRegular,
      let size = attrs[.size] as? NSNumber, size.intValue > 0, size.intValue < 32_000_000
    else { throw RuntimeInstallError.unsupportedReceipt }
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let receipt = try decoder.decode(RuntimeInstallReceipt.self, from: Data(contentsOf: url))
    let spec = BuiltinComponents.standardWine
    guard receipt.schemaVersion == 1, receipt.runtimeID == spec.id, receipt.archiveSHA256 == spec.sha256,
      !receipt.files.isEmpty, receipt.files.count <= 100_000 else { throw RuntimeInstallError.unsupportedReceipt }
    var seen = Set<String>()
    for file in receipt.files {
      let normalized = try ArchiveExtractor.relativePath(file.path)
      guard normalized == file.path, !normalized.isEmpty, normalized != Self.receiptName,
        seen.insert(normalized).inserted,
        ["file", "directory", "symlink"].contains(file.kind)
      else { throw RuntimeInstallError.unsupportedReceipt }
    }
    guard Self.required.allSatisfy({ seen.contains($0) }) else { throw RuntimeInstallError.unsupportedReceipt }
    return receipt
  }

  private func validateLayout(at root: URL) throws {
    try MallowPaths.requireOwnedDirectory(root)
    let canonical = root.resolvingSymlinksInPath().path + "/"
    for path in Self.required {
      let file = root.appendingPathComponent(path).resolvingSymlinksInPath()
      guard file.path.hasPrefix(canonical),
        try fm.attributesOfItem(atPath: file.path)[.type] as? FileAttributeType == .typeRegular,
        fm.isExecutableFile(atPath: file.path)
      else { throw RuntimeInstallError.invalidLayout }
    }
  }

  private func inventory(at root: URL) async throws -> [RuntimeFileRecord] {
    var records: [RuntimeFileRecord] = []
    for file in try ArchiveExtractor.treeURLs(at: root) {
      try Task.checkCancellation()
      let relative = String(file.path.dropFirst(root.path.count + 1))
      let lower = relative.lowercased()
      guard !lower.contains("d3dmetal.framework"), !lower.contains("libd3dshared"),
        !lower.contains("crossover.app") else { throw RuntimeInstallError.invalidLayout }
      let attrs = try fm.attributesOfItem(atPath: file.path)
      switch attrs[.type] as? FileAttributeType {
      case .typeDirectory:
        records.append(.init(path: relative, kind: "directory"))
      case .typeSymbolicLink:
        records.append(.init(path: relative, kind: "symlink", target: try fm.destinationOfSymbolicLink(atPath: file.path)))
      case .typeRegular:
        records.append(.init(path: relative, kind: "file", size: (attrs[.size] as? NSNumber)?.int64Value,
          sha256: try await hasher.sha256(of: file), executable: fm.isExecutableFile(atPath: file.path)))
      default: throw RuntimeInstallError.invalidLayout
      }
    }
    return records
  }

  private func verifyUnlocked(progress: @escaping @Sendable (SetupProgress) -> Void) async throws -> RuntimeIntegrityReport {
    let start = ContinuousClock.now
    let receipt = try loadReceipt(at: installationURL)
    try ArchiveExtractor.validateTree(at: installationURL)
    var problems: [String] = []
    var bytes: Int64 = 0
    var checked = 0
    let actual = try ArchiveExtractor.treeURLs(at: installationURL)
    var remaining = Set(actual.map { String($0.path.dropFirst(installationURL.path.count + 1)) })
    remaining.remove(Self.receiptName)
    for record in receipt.files {
      try Task.checkCancellation()
      let file = installationURL.appendingPathComponent(record.path)
      remaining.remove(record.path)
      guard let attrs = try? fm.attributesOfItem(atPath: file.path) else {
        problems.append("Missing: " + record.path); continue
      }
      let type = attrs[.type] as? FileAttributeType
      var matches = false
      switch record.kind {
      case "directory": matches = type == .typeDirectory
      case "symlink": matches = type == .typeSymbolicLink && (try? fm.destinationOfSymbolicLink(atPath: file.path)) == record.target
      case "file":
        if type == .typeRegular {
          checked += 1
          let size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
          bytes += max(0, size)
          if size == record.size, fm.isExecutableFile(atPath: file.path) == record.executable {
            matches = try await hasher.sha256(of: file) == record.sha256
          }
        }
      default: break
      }
      if !matches { problems.append("Changed: " + record.path) }
      if checked % 64 == 0 { progress(.init(phase: .checkingFiles, received: Int64(checked), expected: 0)) }
    }
    problems += remaining.sorted().map { "Unexpected: " + $0 }
    let elapsed = start.duration(to: .now).components
    return RuntimeIntegrityReport(runtimeID: receipt.runtimeID, checkedFiles: checked, checkedBytes: bytes,
      elapsedSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18, problems: problems)
  }
}
