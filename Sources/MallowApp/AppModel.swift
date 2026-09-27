// SPDX-License-Identifier: 0BSD
import AppKit
import Foundation
import MallowKit

@MainActor final class AppModel: ObservableObject {
  @Published private(set) var report: SetupReport?
  @Published private(set) var integrity: RuntimeIntegrityReport?
  @Published private(set) var progress: SetupProgress?
  @Published private(set) var busy = false
  @Published private(set) var activity = "Checking prerequisites"
  @Published private(set) var messages: [String] = []
  @Published var runtimeSelected = true
  @Published var rosettaSelected = false
  @Published var downloadApproved = false
  @Published var appleLicenseAccepted = false
  private let service = SetupService()
  private var operation: Task<Void, Never>?
  private var operationID: UUID?

  var revision: String { Bundle.main.object(forInfoDictionaryKey: "MallowSourceRevision") as? String ?? "local build" }
  var canCancel: Bool { operation != nil }
  var canSetUp: Bool {
    !busy && report?.host.supported == true && (runtimeSelected || rosettaSelected)
      && (!runtimeSelected || downloadApproved) && (!rosettaSelected || appleLicenseAccepted)
  }

  func refresh() async {
    guard !busy else { return }
    busy = true; activity = "Checking prerequisites"; progress = nil
    defer { busy = false }
    do {
      report = try await service.report()
      rosettaSelected = report?.host.supported == true && report?.host.rosettaInstalled == false
      runtimeSelected = report?.runtimeActivated == false
      log("Prerequisites checked using metadata. Full runtime verification is available on request.")
    } catch { log(error.localizedDescription) }
  }

  private func callback(for id: UUID) -> @Sendable (SetupProgress) -> Void {
    { [weak self] update in
      Task { @MainActor [weak self] in
        guard let self, self.operationID == id else { return }
        self.progress = update
        self.activity = update.phase.label
      }
    }
  }

  func startSetup() {
    guard canSetUp else { return }
    let rosetta = rosettaSelected
    let runtime = runtimeSelected
    let accepted = appleLicenseAccepted
    let approved = downloadApproved
    let id = UUID(); operationID = id
    busy = true; progress = nil; integrity = nil; activity = "Preparing setup"
    operation = Task {
      defer { busy = false; operation = nil; operationID = nil }
      let start = ContinuousClock.now
      do {
        if rosetta {
          activity = "Installing Rosetta through Apple"
          log("Requesting Rosetta installation after your licence approval…")
          try await Rosetta.install(licenseAccepted: accepted)
          log("Rosetta installation completed and its marker was detected.")
        }
        if runtime {
          activity = "Installing the Wine runtime"
          log("Installing Wine 11.0_1. A verified cached archive will be reused.")
          _ = try await service.installRuntime(approved: approved, progress: callback(for: id))
          log("Wine runtime installed and registered. The bundle layout and file hashes were recorded.")
        }
        report = try await service.report()
        if report?.host.rosettaInstalled == true { rosettaSelected = false }
        if report?.runtimeActivated == true { runtimeSelected = false }
        let elapsed = start.duration(to: .now).components
        log("Setup finished in \(elapsed.seconds) seconds. Windows launching still requires the bottle and sandbox work.")
      } catch is CancellationError {
        log("Setup cancelled. Staging is cleaned; a published runtime is kept. An Apple OS installation may continue independently.")
      } catch {
        log(error.localizedDescription)
      }
      progress = nil
    }
  }

  func verifyRuntime() {
    guard !busy, report?.runtimeActivated == true else { return }
    let id = UUID(); operationID = id
    busy = true; progress = nil; activity = "Checking runtime files"
    operation = Task {
      defer { busy = false; operation = nil; operationID = nil; progress = nil }
      do {
        let result = try await service.verifyRuntime(progress: callback(for: id))
        integrity = result
        log("Integrity \(result.passed ? "passed" : "FAILED"): \(result.checkedFiles) files, \(result.checkedBytes / 1_000_000) MB in \(String(format: "%.2f", result.elapsedSeconds)) seconds.")
        for problem in result.problems.prefix(20) { log(problem) }
      } catch is CancellationError { log("Verification cancelled. No runtime files were changed.") }
      catch { log(error.localizedDescription) }
    }
  }

  func cancel() { operation?.cancel() }
  func revealRuntime() {
    Task {
      do { NSWorkspace.shared.activateFileViewerSelecting([try await service.installedRuntimeURL()]) }
      catch { log(error.localizedDescription) }
    }
  }
  func copyReport() {
    guard let report else { return }
    struct Report: Encodable {
      var revision: String
      var setup: SetupReport
      var integrity: RuntimeIntegrityReport?
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(Report(revision: revision, setup: report, integrity: integrity)) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string)
    log("Copied build, prerequisite and integrity results. No home-folder path is included.")
  }
  private func log(_ message: String) {
    guard messages.last != message else { return }
    messages.append(message)
    if messages.count > 80 { messages.removeFirst(messages.count - 80) }
  }
}
