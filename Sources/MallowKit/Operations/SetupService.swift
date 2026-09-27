// SPDX-License-Identifier: 0BSD
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// First-run acquisition and installation of the compiled pin. Never launches a Windows program.
public actor SetupService {
  public let cacheDirectory: URL
  private let transport: any DownloadTransport
  private let hasher: any DownloadHasher
  private let installer: StandardWineInstaller
  private static let ownership = Data("io.github.mixutin.Mallow.setup-cache.v1\n".utf8)

  public init(cacheDirectory: URL = SetupService.defaultCacheDirectory,
    transport: any DownloadTransport = URLSessionDownloadTransport(),
    hasher: any DownloadHasher = SHA256DownloadHasher(), paths: MallowPaths = .standard) {
    self.cacheDirectory = cacheDirectory; self.transport = transport; self.hasher = hasher
    self.installer = StandardWineInstaller(paths: paths, hasher: hasher)
  }

  public static var defaultCacheDirectory: URL {
    if let home = ProcessInfo.processInfo.environment["MALLOW_HOME"], home.hasPrefix("/") {
      return URL(filePath: home).appendingPathComponent("Caches/Setup", isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/io.github.mixutin.Mallow.setup", isDirectory: true)
  }

  /// Ordinary startup uses metadata only. Full hashing is explicit and never inferred from a receipt.
  public func report(host: SetupHost = .current(), verifyArchive: Bool = false) async throws -> SetupReport {
    let spec = BuiltinComponents.standardWine
    let exists = FileManager.default.fileExists(atPath: cacheDirectory.path)
    if exists { try validateOwnedCache() }
    let cached = exists && (try? regularFileSize(cacheDirectory.appendingPathComponent(spec.fileName))) == spec.size
    let verified = verifyArchive && cached ? try await verifyIfPresent(spec) : false
    let installed = try await installer.isInstalled()
    return SetupReport(host: host, runtimeArchiveVerified: verified, runtimeID: spec.id,
      runtimeArchiveCached: cached, runtimeActivated: installed)
  }

  public func downloadRuntime(approved: Bool,
    progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> URL {
    guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
    return try await acquire(BuiltinComponents.standardWine, approved: approved, progress: progress)
  }

  public func installRuntime(approved: Bool,
    progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> URL {
    guard approved else { throw SetupError.consentRequired }
    guard SetupHost.current().supported else { throw SetupError.unsupportedHost }
    if try await installer.isInstalled() {
      // An explicit repeat install checks the existing tree, without fetching the archive again.
      return try await installer.install(archive: cacheDirectory.appendingPathComponent(BuiltinComponents.standardWine.fileName),
        approved: true, progress: progress)
    }
    let archive = try await downloadRuntime(approved: true, progress: progress)
    return try await installer.install(archive: archive, approved: true, progress: progress)
  }

  public func verifyRuntime(progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> RuntimeIntegrityReport {
    try await installer.verify(progress: progress)
  }

  public func installedRuntimeURL() async throws -> URL {
    guard try await installer.isInstalled() else { throw RuntimeInstallError.noInstallation }
    return await installer.installationURL
  }

  // Internal spec injection is used by hermetic tests. Production UI/CLI can request only the compiled pin.
  func acquire(_ spec: DownloadSpec, approved: Bool,
    progress: @escaping @Sendable (SetupProgress) -> Void = { _ in }) async throws -> URL {
    guard approved else { throw SetupError.consentRequired }
    try spec.validate()
    try prepareCache()
    let descriptor = try FileLock.acquire(cacheDirectory.appendingPathComponent(".lock"))
    defer { FileLock.release(descriptor) }
    let destination = cacheDirectory.appendingPathComponent(spec.fileName)
    if try await verifyIfPresent(spec) {
      progress(.init(phase: .cached, received: spec.size, expected: spec.size)); return destination
    }
    let temporary = cacheDirectory.appendingPathComponent(".download-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: temporary) }
    try await transport.download(spec, to: temporary, progress: progress)
    try Task.checkCancellation()
    guard try regularFileSize(temporary) == spec.size else { throw SetupError.unexpectedSize }
    progress(.init(phase: .verifying, received: spec.size, expected: spec.size))
    guard try await hasher.sha256(of: temporary) == spec.sha256 else { throw SetupError.checksumMismatch }
    try Task.checkCancellation()
    if FileManager.default.fileExists(atPath: destination.path) {
      guard try isRegularFile(destination) else { throw SetupError.unsafeCache }
      guard rename(temporary.path, destination.path) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
    } else {
      try FileManager.default.moveItem(at: temporary, to: destination)
    }
    progress(.init(phase: .cached, received: spec.size, expected: spec.size))
    return destination
  }

  private func verifyIfPresent(_ spec: DownloadSpec) async throws -> Bool {
    let file = cacheDirectory.appendingPathComponent(spec.fileName)
    guard FileManager.default.fileExists(atPath: file.path) else { return false }
    guard try regularFileSize(file) == spec.size else { return false }
    return try await hasher.sha256(of: file) == spec.sha256
  }

  private func isRegularFile(_ url: URL) throws -> Bool {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return attributes[.type] as? FileAttributeType == .typeRegular
  }
  private func regularFileSize(_ url: URL) throws -> Int64 {
    guard try isRegularFile(url) else { throw SetupError.unsafeCache }
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.size] as? NSNumber)?.int64Value ?? -1
  }
  private func validateOwnedCache() throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: cacheDirectory.path)
    guard attributes[.type] as? FileAttributeType == .typeDirectory,
      (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
      let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue, mode & 0o022 == 0
    else { throw SetupError.unsafeCache }
    let marker = cacheDirectory.appendingPathComponent(".mallow-setup-root")
    guard (try? regularFileSize(marker)) == Int64(Self.ownership.count), (try? Data(contentsOf: marker)) == Self.ownership
    else { throw SetupError.unsafeCache }
  }
  private func prepareCache() throws {
    guard cacheDirectory.isFileURL, cacheDirectory.path.hasPrefix("/"),
      cacheDirectory.host == nil || cacheDirectory.host == "" || cacheDirectory.host == "localhost",
      !cacheDirectory.path.utf8.contains(0)
    else { throw SetupError.unsafeCache }
    if FileManager.default.fileExists(atPath: cacheDirectory.path) {
      try validateOwnedCache(); return
    }
    let parent = cacheDirectory.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    guard mkdir(cacheDirectory.path, mode_t(0o700)) == 0 else {
      if errno == EEXIST { try validateOwnedCache(); return }
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    try Self.ownership.write(to: cacheDirectory.appendingPathComponent(".mallow-setup-root"), options: .withoutOverwriting)
  }
}
