// SPDX-License-Identifier: 0BSD
import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

public enum JSONStore {
  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  public static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    try requireLocalFile(url)
    return try decoder.decode(type, from: Data(contentsOf: url))
  }

  public static func readIfPresent<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
    do { return try read(type, from: url) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
    {
      return nil
    } catch let error as POSIXError where error.code == .ENOENT { return nil }
  }

  /// Atomic replacement only. Callers must lock the entire read-modify-write transaction.
  /// Schema compatibility and model validation belong to the owning store, not this generic IO helper.
  public static func writeAtomically<T: Encodable>(_ value: T, to url: URL) throws {
    try requireLocalFile(url)
    let data = try encoder.encode(value)
    let destination = url.path(percentEncoded: false)
    let temporary = url.deletingLastPathComponent()
      .appendingPathComponent(".mallow-\(UUID().uuidString).tmp").path(percentEncoded: false)
    let descriptor = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o600))
    guard descriptor >= 0 else { throw posixError(path: temporary) }
    defer {
      _ = close(descriptor)
      _ = unlink(temporary)
    }
    try data.withUnsafeBytes { bytes in
      var offset = 0
      while offset < bytes.count {
        let count = write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
        if count < 0 {
          if errno == EINTR { continue }
          throw posixError(path: temporary)
        }
        guard count > 0 else { throw POSIXError(.EIO) }
        offset += count
      }
    }
    while fsync(descriptor) != 0 {
      if errno == EINTR { continue }
      throw posixError(path: temporary)
    }
    guard rename(temporary, destination) == 0 else { throw posixError(path: destination) }
  }

  private static func posixError(path: String) -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO, userInfo: [NSFilePathErrorKey: path])
  }

  private static func requireLocalFile(_ url: URL) throws {
    guard url.isFileURL, WireCoding.isAbsolutePath(url.path(percentEncoded: false)),
      url.host == nil || url.host == "" || url.host == "localhost"
    else { throw CocoaError(.fileReadUnsupportedScheme, userInfo: [NSURLErrorKey: url]) }
  }
}
