// SPDX-License-Identifier: 0BSD
import Foundation
import Synchronization
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public protocol DownloadTransport: Sendable {
  func download(_ spec: DownloadSpec, to destination: URL,
    progress: @escaping @Sendable (SetupProgress) -> Void) async throws
}

public protocol DownloadHasher: Sendable {
  func sha256(of url: URL) async throws -> String
}

public struct SHA256DownloadHasher: DownloadHasher {
  public init() {}
  @concurrent public func sha256(of url: URL) async throws -> String {
    #if canImport(CryptoKit)
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
      try Task.checkCancellation()
      hash.update(data: chunk)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
    #else
    throw SetupError.unsupportedHost
    #endif
  }
}

public struct URLSessionDownloadTransport: DownloadTransport {
  public init() {}
  public func download(_ spec: DownloadSpec, to destination: URL,
    progress: @escaping @Sendable (SetupProgress) -> Void) async throws {
    try spec.validate()
    let delegate = DownloadDelegate(spec: spec, progress: progress)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 1800
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    progress(.init(phase: .downloading, received: 0, expected: spec.size))
    let (temporary, response) = try await session.download(from: spec.url)
    defer { try? FileManager.default.removeItem(at: temporary) }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      let finalURL = http.url, spec.permits(finalURL)
    else { throw SetupError.rejectedResponse }
    if response.expectedContentLength >= 0 && response.expectedContentLength != spec.size {
      throw SetupError.unexpectedSize
    }
    try Task.checkCancellation()
    try FileManager.default.moveItem(at: temporary, to: destination)
  }
}

// Mutable timing state is protected by Mutex. UI progress is capped to ~10 updates/sec,
// while every size/redirect check still runs and completion is delivered immediately.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
  let spec: DownloadSpec
  let progress: @Sendable (SetupProgress) -> Void
  private let lastProgress = Mutex(ContinuousClock.now)
  init(spec: DownloadSpec, progress: @escaping @Sendable (SetupProgress) -> Void) {
    self.spec = spec; self.progress = progress
  }
  func urlSession(_ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    guard let url = request.url, spec.permits(url) else {
      completionHandler(nil); task.cancel(); return
    }
    completionHandler(request)
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard totalBytesWritten <= spec.size,
      totalBytesExpectedToWrite < 0 || totalBytesExpectedToWrite == spec.size
    else { downloadTask.cancel(); return }
    let emit = lastProgress.withLock { last in
      let now = ContinuousClock.now
      guard totalBytesWritten == spec.size || last.duration(to: now) >= .milliseconds(100) else { return false }
      last = now
      return true
    }
    if emit { progress(.init(phase: .downloading, received: totalBytesWritten, expected: spec.size)) }
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL) {}
}
