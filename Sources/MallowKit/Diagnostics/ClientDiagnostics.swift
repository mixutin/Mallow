// SPDX-License-Identifier: 0BSD
import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

public struct ClientCheck: Codable, Sendable, Equatable, Identifiable {
  public enum Status: String, Codable, Sendable { case passed, warning, failed, notImplemented }
  public let id: String
  public let status: Status
  public let summary: String
  public let elapsedMilliseconds: Double?
}

public struct ClientOperation: Codable, Sendable, Equatable {
  public enum Action: String, Codable, Sendable { case prerequisites, install, verifyRuntime }
  public enum Outcome: String, Codable, Sendable { case succeeded, failed, cancelled }
  public let action: Action
  public let outcome: Outcome
  public let elapsedMilliseconds: Double
  public init(action: Action, outcome: Outcome, elapsedMilliseconds: Double) {
    self.action = action
    self.outcome = outcome
    self.elapsedMilliseconds = elapsedMilliseconds.isFinite ? max(0, elapsedMilliseconds) : 0
  }
}

public struct ClientBuild: Codable, Sendable, Equatable {
  public let revision: String
  public let number: String
  public let configuration: String

  public init(revision: String, number: String, configuration: String) {
    self.revision =
      revision.count == 40 && revision.allSatisfy({ "0123456789abcdef".contains($0) })
      ? revision : "unknown"
    self.number =
      !number.isEmpty && number.count <= 20 && number.allSatisfy({ "0123456789".contains($0) })
      ? number : "unknown"
    self.configuration = ["debug", "release"].contains(configuration) ? configuration : "unknown"
  }

  public static func current() -> ClientBuild {
    var info = Bundle.main.infoDictionary ?? [:]
    // The bundled CLI is not itself a bundle. Read only its enclosing app's bounded Info.plist.
    if info["MallowSourceRevision"] == nil,
      let executable = Bundle.main.executableURL,
      executable.deletingLastPathComponent().lastPathComponent == "Helpers"
    {
      let plist = executable.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Info.plist")
      if let size = try? plist.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 16384,
        let data = try? Data(contentsOf: plist),
        let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil)
          as? [String: Any]
      {
        info = dictionary
      }
    }
    #if DEBUG
      let configuration = "debug"
    #else
      let configuration = "release"
    #endif
    return ClientBuild(
      revision: info["MallowSourceRevision"] as? String ?? "unknown",
      number: info["CFBundleVersion"] as? String ?? "unknown", configuration: configuration)
  }
}

public struct ClientMachine: Codable, Sendable, Equatable {
  public let system: String
  public let version: String
  public let appleSilicon: Bool
  public let logicalProcessors: Int
  public let physicalMemoryBytes: UInt64
  public static func current() -> ClientMachine {
    let host = SetupHost.current()
    return ClientMachine(
      system: host.system, version: host.version, appleSilicon: host.isAppleSilicon,
      logicalProcessors: ProcessInfo.processInfo.activeProcessorCount,
      physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory)
  }
}

public struct ClientIntegrity: Codable, Sendable, Equatable {
  public let observedAt: Date
  public let checkedFiles: Int
  public let checkedBytes: Int64
  public let elapsedSeconds: Double
  public let problemCount: Int
  public init(_ report: RuntimeIntegrityReport, observedAt: Date = Date()) {
    self.observedAt = observedAt
    checkedFiles = report.checkedFiles
    checkedBytes = report.checkedBytes
    elapsedSeconds = report.elapsedSeconds
    problemCount = report.problems.count
  }
}

/// A deliberately small, allowlisted report. It contains no log text, paths, environment,
/// usernames, serial numbers, installed-program inventory or vendor payloads.
public struct ClientReport: Codable, Sendable {
  public let schemaVersion: Int
  public let generatedAt: Date
  public let build: ClientBuild
  public let machine: ClientMachine
  public let captureMilliseconds: Double
  public let peakResidentBytes: UInt64?
  public let checks: [ClientCheck]
  public let selfTests: [ClientCheck]?
  public let lastIntegrity: ClientIntegrity?
  public let recentOperations: [ClientOperation]
  public let windowsLaunching: Bool
  public let sandboxImplemented: Bool
  public var selfTestsPassed: Bool {
    guard let selfTests, !selfTests.isEmpty else { return false }
    return selfTests.allSatisfy { $0.status == .passed }
  }
  public func json() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(self)
    guard data.count <= 262144 else { throw CocoaError(.fileWriteOutOfSpace) }
    return data
  }

  /// Explicit export only. Never follows or overwrites an existing destination.
  @concurrent public func writeNewFile(to url: URL) async throws {
    try MallowPaths.requireLocal(url)
    let data = try json()
    try Task.checkCancellation()
    let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var completed = false
    defer {
      _ = close(fd)
      if !completed { _ = unlink(url.path) }
    }
    try data.withUnsafeBytes { buffer in
      var position = 0
      while position < buffer.count {
        try Task.checkCancellation()
        let count = write(fd, buffer.baseAddress!.advanced(by: position), buffer.count - position)
        if count < 0 && errno == EINTR { continue }
        guard count > 0 else { throw POSIXError(.EIO) }
        position += count
      }
    }
    guard fsync(fd) == 0 else { throw POSIXError(.EIO) }
    completed = true
  }
}

public struct ClientDiagnostics: Sendable {
  public let paths: MallowPaths
  public init(paths: MallowPaths = .standard) { self.paths = paths }

  @concurrent public func capture(
    runSelfTests: Bool = false, build: ClientBuild = .current(),
    lastIntegrity: ClientIntegrity? = nil, operations: [ClientOperation] = []
  ) async throws -> ClientReport {
    let start = ContinuousClock.now
    try Task.checkCancellation()
    let host = SetupHost.current()
    var checks: [ClientCheck] = [
      .init(
        id: "host", status: host.supported ? .passed : .failed,
        summary: host.supported
          ? "Apple Silicon and macOS 15+ detected."
          : "This host is outside the supported Mac target.", elapsedMilliseconds: nil),
      .init(
        id: "rosetta", status: host.rosettaInstalled ? .passed : .warning,
        summary: host.rosettaInstalled
          ? "Rosetta marker found; translation was not executed."
          : "Rosetta marker missing. Review Apple's licence before installation.",
        elapsedMilliseconds: nil),
    ]
    let installer = StandardWineInstaller(paths: paths)
    do {
      let installed = try await installer.isInstalled()
      checks.append(
        .init(
          id: "runtime-metadata", status: installed ? .passed : .warning,
          summary: installed
            ? "Owned runtime receipt and entry points found; not a fresh integrity check."
            : "Runtime not installed. Use the approved setup flow.", elapsedMilliseconds: nil))
      if installed {
        let root = await installer.installationURL
        checks.append(
          Self.architectureCheck(
            id: "wine-header",
            at: root.appendingPathComponent("Wine Stable.app/Contents/Resources/wine/bin/wine")))
      }
    } catch {
      checks.append(
        .init(
          id: "runtime-metadata", status: .failed,
          summary:
            "Runtime metadata could not be validated. Preserve the files and review the local setup error.",
          elapsedMilliseconds: nil))
    }
    // Upstream documents this framework layout. Detection never dlopens vendor code:
    // https://gstreamer.freedesktop.org/documentation/installing/on-mac-osx.html
    checks.append(
      Self.architectureCheck(
        id: "gstreamer-header",
        at: URL(
          filePath:
            "/Library/Frameworks/GStreamer.framework/Versions/1.0/lib/libgstreamer-1.0.0.dylib")))
    checks.append(
      .init(
        id: "windows-launch", status: .notImplemented,
        summary: "Bottle creation and Windows launching remain unavailable.",
        elapsedMilliseconds: nil))
    checks.append(
      .init(
        id: "kernel-sandbox", status: .notImplemented,
        summary:
          "Kernel sandbox integration is not implemented. This app is not a malware sandbox.",
        elapsedMilliseconds: nil))
    let selfTests = runSelfTests ? try await ClientSelfTests.run() : nil
    try Task.checkCancellation()
    return ClientReport(
      schemaVersion: 1, generatedAt: Date(), build: build, machine: .current(),
      captureMilliseconds: Self.milliseconds(since: start),
      peakResidentBytes: Self.peakResidentBytes(),
      checks: checks, selfTests: selfTests, lastIntegrity: lastIntegrity,
      recentOperations: Array(operations.suffix(32)), windowsLaunching: false,
      sandboxImplemented: false)
  }

  static func architectureCheck(id: String, at url: URL) -> ClientCheck {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return .init(
        id: id, status: .warning,
        summary:
          "Required binary not found at the expected location. Dependency installation may be needed.",
        elapsedMilliseconds: nil)
    }
    do {
      let types = try MachOHeader.readCPUTypeHeader(at: url)
      return .init(
        id: id, status: types.contains(MachOHeader.x86_64) ? .passed : .failed,
        summary: types.contains(MachOHeader.x86_64)
          ? "Header declares x86_64. Not a signature, dependency-load or compatibility test."
          : "Header lacks x86_64, which the pinned Wine runtime needs.", elapsedMilliseconds: nil)
    } catch {
      return .init(
        id: id, status: .failed,
        summary: "Binary header is unreadable or unsupported. No code was loaded.",
        elapsedMilliseconds: nil)
    }
  }
  public static func milliseconds(since start: ContinuousClock.Instant) -> Double {
    let elapsed = start.duration(to: .now).components
    return Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
  }
  private static func peakResidentBytes() -> UInt64? {
    var usage = rusage()
    #if canImport(Darwin)
      guard getrusage(RUSAGE_SELF, &usage) == 0, usage.ru_maxrss >= 0 else { return nil }
      return UInt64(usage.ru_maxrss)
    #else
      guard getrusage(Int32(RUSAGE_SELF.rawValue), &usage) == 0, usage.ru_maxrss >= 0 else {
        return nil
      }
      return UInt64(usage.ru_maxrss) * 1024
    #endif
  }
}
