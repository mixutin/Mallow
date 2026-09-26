// SPDX-License-Identifier: 0BSD
import Foundation
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
    // Production acquisition is macOS-only. Do not substitute an unverified hash implementation.
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

// Immutable configuration only; delegate callbacks can arrive on URLSession's delegate queue.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
  let spec: DownloadSpec
  let progress: @Sendable (SetupProgress) -> Void
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
    progress(.init(phase: .downloading, received: totalBytesWritten, expected: spec.size))
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL) {}
}
