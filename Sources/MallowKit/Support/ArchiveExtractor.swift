// SPDX-License-Identifier: 0BSD
import CArchive
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum ArchiveError: Error, LocalizedError, Sendable, Equatable {
  case unsafeEntry(String), readFailed, sizeLimit, invalidDestination
  public var errorDescription: String? {
    switch self {
    case .unsafeEntry(let path): "The runtime archive contains an unsafe or duplicate entry: \(path)"
    case .readFailed: "The runtime archive is damaged or uses an unsupported format."
    case .sizeLimit: "The runtime archive exceeds the extraction size or entry limit."
    case .invalidDestination: "Runtime extraction requires an empty, private, ordinary directory."
    }
  }
}

/// Only tar files, directories and confined links are supported. No archive-supplied ACL,
/// xattr, ownership or special-file metadata is applied. This uses the OS libarchive reader:
/// https://github.com/libarchive/libarchive/blob/master/libarchive/archive_read.3
public struct ArchiveExtractor: Sendable {
  public init() {}

  @concurrent public func extract(_ archiveURL: URL, into root: URL) async throws {
    try Self.requireEmptyDirectory(root)
    guard archiveURL.isFileURL, archiveURL.host == nil || archiveURL.host == "" || archiveURL.host == "localhost",
      !archiveURL.path.utf8.contains(0) else { throw ArchiveError.readFailed }
    let fd = open(archiveURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw ArchiveError.readFailed }
    defer { _ = close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & mode_t(CArchive.S_IFMT) == mode_t(CArchive.S_IFREG),
      let reader = archive_read_new() else { throw ArchiveError.readFailed }
    defer { archive_read_free(reader) }
    guard archive_read_support_filter_none(reader) == ARCHIVE_OK,
      archive_read_support_filter_xz(reader) == ARCHIVE_OK,
      archive_read_support_filter_gzip(reader) == ARCHIVE_OK,
      archive_read_support_format_tar(reader) == ARCHIVE_OK
    else { throw ArchiveError.readFailed }
    guard archive_read_open_fd(reader, fd, 1 << 20) == ARCHIVE_OK else { throw ArchiveError.readFailed }
    var seen = Set<String>()
    var regularFiles = Set<String>()
    var links: [(path: String, target: String, hard: Bool)] = []
    var expanded: Int64 = 0
    var count = 0
    var entry: OpaquePointer?
    var buffer = [UInt8](repeating: 0, count: 1 << 20)
    while true {
      try Task.checkCancellation()
      let result = archive_read_next_header(reader, &entry)
      if result == ARCHIVE_EOF { break }
      guard result == ARCHIVE_OK, let entry,
        let raw = archive_entry_pathname(entry), let name = String(validatingCString: raw)
      else { throw ArchiveError.readFailed }
      count += 1
      guard count <= 100_000 else { throw ArchiveError.sizeLimit }
      let path = try Self.relativePath(name)
      let kind = archive_entry_filetype(entry)
      let mode = archive_entry_perm(entry)
      guard mode & 0o7000 == 0 else { throw ArchiveError.unsafeEntry(name) }
      if path.isEmpty {
        guard kind == MALLOW_ARCHIVE_IFDIR else { throw ArchiveError.unsafeEntry(name) }
        continue
      }
      guard seen.insert(path.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw ArchiveError.unsafeEntry(path) }
      let destination = root.appendingPathComponent(path)
      try Self.makeParents(of: path, under: root)
      if let rawTarget = archive_entry_hardlink(entry) {
        guard let target = String(validatingCString: rawTarget) else { throw ArchiveError.readFailed }
        links.append((path, try Self.relativePath(target), true))
      } else if kind == MALLOW_ARCHIVE_IFLNK {
        guard let rawTarget = archive_entry_symlink(entry), let target = String(validatingCString: rawTarget),
          !target.isEmpty, !target.hasPrefix("/"), !target.contains("\\"),
          !target.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
        else { throw ArchiveError.unsafeEntry(path) }
        // Links are created last, so subsequent archive entries can never write through them.
        links.append((path, target, false))
      } else if kind == MALLOW_ARCHIVE_IFDIR {
        try Self.makeDirectory(destination)
      } else if kind == MALLOW_ARCHIVE_IFREG {
        let size = archive_entry_size(entry)
        guard size >= 0, size <= 4_294_967_296 - expanded else { throw ArchiveError.sizeLimit }
        expanded += size
        let output = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard output >= 0 else { throw ArchiveError.unsafeEntry(path) }
        let handle = FileHandle(fileDescriptor: output, closeOnDealloc: true)
        do {
          var written: Int64 = 0
          while true {
            try Task.checkCancellation()
            let amount = archive_read_data(reader, &buffer, buffer.count)
            guard amount >= 0 else { throw ArchiveError.readFailed }
            if amount == 0 { break }
            written += Int64(amount)
            guard written <= size else { throw ArchiveError.sizeLimit }
            try handle.write(contentsOf: Data(buffer.prefix(amount)))
          }
          guard written == size, fchmod(output, mode_t(mode & 0o555) | 0o600) == 0 else { throw ArchiveError.readFailed }
          try handle.close()
          regularFiles.insert(path)
        } catch {
          try? handle.close()
          throw error
        }
      } else { throw ArchiveError.unsafeEntry(path) }
    }
    for item in links where item.hard {
      try Task.checkCancellation()
      guard regularFiles.contains(item.target),
        link(root.appendingPathComponent(item.target).path, root.appendingPathComponent(item.path).path) == 0
      else { throw ArchiveError.unsafeEntry(item.path) }
    }
    for item in links where !item.hard {
      try Task.checkCancellation()
      guard symlink(item.target, root.appendingPathComponent(item.path).path) == 0
      else { throw ArchiveError.unsafeEntry(item.path) }
    }
    try Self.validateTree(at: root)
  }

  static func relativePath(_ value: String) throws -> String {
    let parts = value.split(separator: "/").filter { $0 != "." }
    guard !value.hasPrefix("/"), !value.contains("\\"), value.utf8.count <= 4096,
      !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
      !parts.contains(".."), parts.allSatisfy({ $0.utf8.count <= 255 })
    else { throw ArchiveError.unsafeEntry(value) }
    return parts.joined(separator: "/")
  }

  private static func requireEmptyDirectory(_ root: URL) throws {
    guard root.isFileURL, root.host == nil || root.host == "" || root.host == "localhost",
      !root.path.utf8.contains(0) else { throw ArchiveError.invalidDestination }
    let info = try FileManager.default.attributesOfItem(atPath: root.path)
    guard info[.type] as? FileAttributeType == .typeDirectory,
      (info[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
      let mode = (info[.posixPermissions] as? NSNumber)?.intValue, mode & 0o077 == 0,
      try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty
    else { throw ArchiveError.invalidDestination }
  }

  private static func makeParents(of path: String, under root: URL) throws {
    var current = root
    for part in path.split(separator: "/").dropLast() {
      current.appendPathComponent(String(part))
      try makeDirectory(current)
    }
  }

  private static func makeDirectory(_ url: URL) throws {
    if mkdir(url.path, mode_t(0o700)) == 0 { return }
    guard errno == EEXIST,
      try FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeDirectory
    else { throw ArchiveError.unsafeEntry(url.lastPathComponent) }
  }

  static func treeURLs(at root: URL) throws -> [URL] {
    var pending = [root]
    var result: [URL] = []
    while let directory = pending.popLast() {
      try Task.checkCancellation()
      for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
        result.append(url)
        guard result.count <= 100_000 else { throw ArchiveError.sizeLimit }
        if try FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeDirectory {
          pending.append(url)
        }
      }
    }
    return result.sorted { $0.path < $1.path }
  }

  static func validateTree(at root: URL) throws {
    let canonicalRoot = root.resolvingSymlinksInPath().path
    for url in try treeURLs(at: root) {
      let info = try FileManager.default.attributesOfItem(atPath: url.path)
      guard let kind = info[.type] as? FileAttributeType,
        [.typeRegular, .typeDirectory, .typeSymbolicLink].contains(kind)
      else { throw ArchiveError.unsafeEntry(url.lastPathComponent) }
      if kind == .typeSymbolicLink {
        let resolved = url.resolvingSymlinksInPath().path
        guard resolved.hasPrefix(canonicalRoot + "/"), FileManager.default.fileExists(atPath: resolved),
          try FileManager.default.attributesOfItem(atPath: resolved)[.type] as? FileAttributeType != .typeSymbolicLink
        else { throw ArchiveError.unsafeEntry(url.lastPathComponent) }
      }
    }
  }
}
