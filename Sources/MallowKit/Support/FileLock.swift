// SPDX-License-Identifier: 0BSD
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum FileLock {
  // Locks are on an open file description, not actor identity. Keep the fd open across an async download.
  static func acquire(_ url: URL) throws -> Int32 {
    guard url.isFileURL, !url.path.utf8.contains(0) else { throw SetupError.unsafeCache }
    let fd = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
      let code = errno
      _ = close(fd)
      if code == EWOULDBLOCK || code == EAGAIN { throw SetupError.busy }
      throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
    return fd
  }

  static func release(_ descriptor: Int32) { _ = close(descriptor) }

  public static func withExclusiveLock<T>(_ url: URL, timeout: Duration = .seconds(10), _ body: () throws -> T) throws -> T {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while true {
      let descriptor: Int32
      do {
        descriptor = try acquire(url)
      } catch SetupError.busy {
        guard clock.now < deadline else { throw SetupError.busy }
        Thread.sleep(forTimeInterval: 0.02)
        continue
      }
      defer { release(descriptor) }
      return try body()
    }
  }
}
