// SPDX-License-Identifier: 0BSD
import AppKit
import Foundation
import MallowKit
import UniformTypeIdentifiers

@MainActor final class AppModel: ObservableObject {
  @Published private(set) var clientReport: ClientReport?
  private var recentOperations: [ClientOperation] = []
  private var integrityObservedAt: Date?
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

  var revision: String {
    Bundle.main.object(forInfoDictionaryKey: "MallowSourceRevision") as? String ?? "local build"
  }
  var canCancel: Bool { operation != nil }
  var canSetUp: Bool {
    !busy && report?.host.supported == true && (runtimeSelected || rosettaSelected)
      && (!runtimeSelected || downloadApproved) && (!rosettaSelected || appleLicenseAccepted)
  }

  func refresh() async {
    guard !busy else { return }
    let started = ContinuousClock.now
    var outcome = ClientOperation.Outcome.failed
    busy = true
    activity = "Checking prerequisites"
    clientReport = nil
    report = nil
    progress = nil
    defer {
      busy = false
      record(.prerequisites, outcome, started)
    }
    do {
      report = try await service.report()
      rosettaSelected = report?.host.supported == true && report?.host.rosettaInstalled == false
      runtimeSelected = report?.runtimeActivated == false
      outcome = .succeeded
      log(
        "Prerequisites checked using metadata. Full runtime verification is available on request.")
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
    let id = UUID()
    operationID = id
    busy = true
    progress = nil
    integrity = nil
    integrityObservedAt = nil
    clientReport = nil
    activity = "Preparing setup"
    operation = Task {
      let start = ContinuousClock.now
      var outcome = ClientOperation.Outcome.failed
      defer {
        busy = false
        operation = nil
        operationID = nil
        record(.install, outcome, start)
      }
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
          log(
            "Wine runtime installed and registered. The bundle layout and file hashes were recorded."
          )
        }
        report = try await service.report()
        if report?.host.rosettaInstalled == true { rosettaSelected = false }
        if report?.runtimeActivated == true { runtimeSelected = false }
        let elapsed = start.duration(to: .now).components
        outcome = .succeeded
        log(
          "Setup finished in \(elapsed.seconds) seconds. Windows launching still requires the bottle and sandbox work."
        )
      } catch is CancellationError {
        outcome = .cancelled
        log(
          "Setup cancelled. Staging is cleaned; a published runtime is kept. An Apple OS installation may continue independently."
        )
      } catch {
        log(error.localizedDescription)
      }
      progress = nil
    }
  }

  func verifyRuntime() {
    guard !busy, report?.runtimeActivated == true else { return }
    let id = UUID()
    operationID = id
    busy = true
    progress = nil
    clientReport = nil
    integrity = nil
    integrityObservedAt = nil
    activity = "Checking runtime files"
    operation = Task {
      let started = ContinuousClock.now
      var outcome = ClientOperation.Outcome.failed
      defer {
        busy = false
        operation = nil
        operationID = nil
        progress = nil
        record(.verifyRuntime, outcome, started)
      }
      do {
        let result = try await service.verifyRuntime(progress: callback(for: id))
        integrity = result
        integrityObservedAt = Date()
        outcome = result.passed ? .succeeded : .failed
        log(
          "Integrity \(result.passed ? "passed" : "FAILED"): \(result.checkedFiles) files, \(result.checkedBytes / 1_000_000) MB in \(String(format: "%.2f", result.elapsedSeconds)) seconds."
        )
        for problem in result.problems.prefix(20) { log(problem) }
      } catch is CancellationError {
        outcome = .cancelled
        log("Verification cancelled. No runtime files were changed.")
      } catch { log(error.localizedDescription) }
    }
  }

  func cancel() { operation?.cancel() }
  func revealRuntime() {
    Task {
      do {
        NSWorkspace.shared.activateFileViewerSelecting([try await service.installedRuntimeURL()])
      } catch { log(error.localizedDescription) }
    }
  }
  private func record(
    _ action: ClientOperation.Action, _ outcome: ClientOperation.Outcome,
    _ start: ContinuousClock.Instant
  ) {
    recentOperations.append(
      .init(
        action: action, outcome: outcome,
        elapsedMilliseconds: ClientDiagnostics.milliseconds(since: start)))
    if recentOperations.count > 32 { recentOperations.removeFirst(recentOperations.count - 32) }
  }
  func runClientChecks(copy: Bool = false, selfTests: Bool = true) {
    guard !busy else { return }
    busy = true
    activity = "Collecting client diagnostics"
    progress = nil
    clientReport = nil
    let last = integrity.map { ClientIntegrity($0, observedAt: integrityObservedAt ?? Date()) }
    let operations = recentOperations
    operation = Task {
      defer {
        busy = false
        operation = nil
      }
      do {
        let result = try await ClientDiagnostics().capture(
          runSelfTests: selfTests,
          lastIntegrity: last, operations: operations)
        clientReport = result
        log(
          "Client report captured in \(String(format: "%.2f", result.captureMilliseconds)) ms. No network access or vendor code execution."
        )
        if selfTests {
          log(
            result.selfTestsPassed
              ? "Local client self-tests passed. Windows launch remains blocked."
              : "Some client self-tests did not pass. Review the report.")
        }
        if copy { putOnClipboard(result) }
      } catch is CancellationError { log("Client checks cancelled.") } catch {
        log("Client report could not be collected. No report was uploaded.")
      }
    }
  }
  func copyReport() {
    if let clientReport {
      putOnClipboard(clientReport)
    } else {
      runClientChecks(copy: true, selfTests: false)
    }
  }
  private func putOnClipboard(_ result: ClientReport) {
    guard let data = try? result.json() else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string)
    log(
      "Copied allowlisted diagnostics: build, checks, timings and counts. No raw logs, paths or environment variables."
    )
  }
  func exportReport() {
    guard let clientReport, !busy else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue =
      "Mallow-client-\(String(revision.prefix(12)))-\(Int(Date().timeIntervalSince1970)).json"
    panel.message =
      "Choose a new file. This report excludes raw logs, personal paths and environment variables. Nothing is uploaded."
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      Task { @MainActor [weak self] in
        do {
          try await clientReport.writeNewFile(to: url)
          self?.log("Client report saved locally. Review it before sharing.")
        } catch {
          self?.log(
            "Could not save report. Choose a new writable filename; existing files are never overwritten."
          )
        }
      }
    }
  }
  private func log(_ message: String) {
    guard messages.last != message else { return }
    messages.append(message)
    if messages.count > 80 { messages.removeFirst(messages.count - 80) }
  }
}
