// SPDX-License-Identifier: 0BSD
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum DataRootError: Error, LocalizedError, Sendable {
  case foreignRoot
  public var errorDescription: String? {
    "The data directory is not owned by Mallow or is unsafe. No existing files were replaced."
  }
}

/// Bootstrap ownership rules; not a sandbox against other processes running as this user.
public struct MallowPaths: Sendable {
  public let root: URL
  public var runtimes: URL { root.appendingPathComponent("Runtimes", isDirectory: true) }
  public var rootMarker: URL { root.appendingPathComponent(".mallow-root.json") }
  public init(root: URL) { self.root = root }
  public static var standard: MallowPaths {
    if let home = ProcessInfo.processInfo.environment["MALLOW_HOME"], home.hasPrefix("/") {
      return MallowPaths(root: URL(filePath: home))
    }
    return MallowPaths(root: FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Mallow", isDirectory: true))
  }

  private struct Marker: Codable {
    let schema: String
    let createdAt: Date
    let createdBy: String
  }
  private static let schema = "io.github.mixutin.Mallow.root.v1"

  public func ensureDirectories() throws {
    try Self.requireLocal(root)
    let fm = FileManager.default
    if (try? fm.attributesOfItem(atPath: root.path)) != nil {
      try validate()
    } else {
      let parent = root.deletingLastPathComponent()
      try fm.createDirectory(at: parent, withIntermediateDirectories: true)
      let staging = parent.appendingPathComponent(".mallow-root-\(UUID().uuidString)")
      guard mkdir(staging.path, mode_t(0o700)) == 0 else { throw DataRootError.foreignRoot }
      defer { try? fm.removeItem(at: staging) }
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let marker = Marker(schema: Self.schema, createdAt: Date(), createdBy: "mallow setup preview")
      try encoder.encode(marker).write(to: staging.appendingPathComponent(".mallow-root.json"), options: .withoutOverwriting)
      // FileManager refuses an existing destination; it does not adopt somebody else's folder.
      do { try fm.moveItem(at: staging, to: root) }
      catch { try validate() }
    }
    if mkdir(runtimes.path, mode_t(0o700)) != 0 && errno != EEXIST { throw DataRootError.foreignRoot }
    try Self.requireOwnedDirectory(runtimes)
  }

  public func validate() throws {
    try Self.requireLocal(root)
    try Self.requireOwnedDirectory(root)
    let attrs = try FileManager.default.attributesOfItem(atPath: rootMarker.path)
    guard attrs[.type] as? FileAttributeType == .typeRegular,
      ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) < 4096 else { throw DataRootError.foreignRoot }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard try decoder.decode(Marker.self, from: Data(contentsOf: rootMarker)).schema == Self.schema
    else { throw DataRootError.foreignRoot }
  }

  static func requireLocal(_ url: URL) throws {
    guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0),
      url.host == nil || url.host == "" || url.host == "localhost" else { throw DataRootError.foreignRoot }
  }
  static func requireOwnedDirectory(_ url: URL) throws {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    guard attrs[.type] as? FileAttributeType == .typeDirectory,
      (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
      let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue, mode & 0o022 == 0
    else { throw DataRootError.foreignRoot }
  }
}
