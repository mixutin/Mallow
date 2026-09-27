// SPDX-License-Identifier: 0BSD
import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum SetupError: Error, LocalizedError, Sendable, Equatable {
  case invalidDownload, consentRequired, unsupportedHost, unsafeCache, busy, checksumMismatch
  case unexpectedSize, rejectedResponse, rosettaFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidDownload: "The download descriptor or its HTTPS destination is invalid."
    case .consentRequired: "Review and approve the download or Apple's licence before setup."
    case .unsupportedHost: "This operation requires an Apple Silicon Mac running macOS 15 or later."
    case .unsafeCache: "The setup cache is not an owned, ordinary Mallow directory. Nothing was overwritten."
    case .busy: "Another setup operation owns the lock. Retry when it finishes."
    case .checksumMismatch: "SHA-256 verification failed. The downloaded file was not activated."
    case .unexpectedSize: "The download size does not match the pinned release."
    case .rejectedResponse: "The server response or redirect was not an approved HTTPS download."
    case .rosettaFailed(let message): "Rosetta setup did not complete: \(message)"
    }
  }
}

public struct DownloadSpec: Sendable, Equatable {
  public let id: String
  public let fileName: String
  public let url: URL
  public let size: Int64
  public let sha256: String
  public let allowedHosts: Set<String>

  public init(id: String, fileName: String, url: URL, size: Int64, sha256: String, allowedHosts: Set<String>) {
    self.id = id; self.fileName = fileName; self.url = url; self.size = size
    self.sha256 = sha256; self.allowedHosts = allowedHosts
  }

  public func permits(_ url: URL) -> Bool {
    url.scheme == "https" && url.user == nil && url.password == nil
      && (url.port == nil || url.port == 443) && url.fragment == nil
      && allowedHosts.contains(url.host?.lowercased() ?? "")
  }

  public func validate() throws {
    let hex = Set("0123456789abcdef")
    guard !id.isEmpty, !fileName.isEmpty, ![".", ".."].contains(fileName),
      !fileName.contains("/"), !fileName.contains("\\"), !fileName.utf8.contains(0),
      size > 0, sha256.count == 64, sha256.allSatisfy({ hex.contains($0) }), permits(url)
    else { throw SetupError.invalidDownload }
  }
}

public struct SetupHost: Codable, Sendable, Equatable {
  public var system: String
  public var version: String
  public var majorVersion: Int
  public var isAppleSilicon: Bool
  public var rosettaInstalled: Bool
  public var supported: Bool { system == "macOS" && majorVersion >= 15 && isAppleSilicon }

  public init(system: String, version: String, majorVersion: Int, isAppleSilicon: Bool, rosettaInstalled: Bool) {
    self.system = system; self.version = version; self.majorVersion = majorVersion
    self.isAppleSilicon = isAppleSilicon; self.rosettaInstalled = rosettaInstalled
  }

  public static func current() -> SetupHost {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    #if os(macOS)
    var arm: Int32 = 0
    var size = MemoryLayout.size(ofValue: arm)
    // DESIGN.md §3.4.1: hw.optional.arm64 also identifies hardware under translation.
    let result = sysctlbyname("hw.optional.arm64", &arm, &size, nil, 0)
    return SetupHost(system: "macOS", version: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
      majorVersion: version.majorVersion, isAppleSilicon: result == 0 && arm == 1,
      rosettaInstalled: Rosetta.isInstalled())
    #else
    return SetupHost(system: "unsupported", version: ProcessInfo.processInfo.operatingSystemVersionString,
      majorVersion: version.majorVersion, isAppleSilicon: false, rosettaInstalled: false)
    #endif
  }
}

public struct SetupReport: Encodable, Sendable, Equatable {
  public var host: SetupHost
  public var runtimeArchiveVerified: Bool
  public var runtimeArchiveCached: Bool
  public let runtimeID: String
  public var runtimeActivated: Bool
  public let sandboxImplemented = false
  public let readyToRunWindows = false

  public init(host: SetupHost, runtimeArchiveVerified: Bool, runtimeID: String,
    runtimeArchiveCached: Bool = false, runtimeActivated: Bool = false) {
    self.host = host; self.runtimeArchiveVerified = runtimeArchiveVerified
    self.runtimeID = runtimeID; self.runtimeArchiveCached = runtimeArchiveCached
    self.runtimeActivated = runtimeActivated
  }
}

public struct SetupProgress: Sendable {
  public enum Phase: String, Sendable {
    case downloading, verifying, cached, extracting, checkingFiles, installing, installed
    public var label: String {
      switch self {
      case .downloading: "Downloading Wine"
      case .verifying: "Verifying archive SHA-256"
      case .cached: "Using verified archive"
      case .extracting: "Unpacking the runtime"
      case .checkingFiles: "Checking runtime files"
      case .installing: "Registering the runtime"
      case .installed: "Runtime installed"
      }
    }
  }
  public var phase: Phase
  public var received: Int64
  public var expected: Int64
  public var fraction: Double { expected > 0 ? min(1, max(0, Double(received) / Double(expected))) : 0 }
  public init(phase: Phase, received: Int64, expected: Int64) {
    self.phase = phase; self.received = received; self.expected = expected
  }
}
