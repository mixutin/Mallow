// SPDX-License-Identifier: 0BSD
import AppKit
import Foundation
import MallowKit

@MainActor final class AppModel: ObservableObject {
  @Published private(set) var report: SetupReport?
  @Published private(set) var progress: SetupProgress?
  @Published private(set) var busy = false
  @Published private(set) var messages: [String] = []
  @Published var downloadSelected = true
  @Published var rosettaSelected = false
  @Published var downloadApproved = false
  @Published var appleLicenseAccepted = false
  private let service = SetupService()
  private var operation: Task<Void, Never>?

  var revision: String { Bundle.main.object(forInfoDictionaryKey: "MallowSourceRevision") as? String ?? "local build" }
  var canSetUp: Bool {
    !busy && report?.host.supported == true && (downloadSelected || rosettaSelected)
      && (!downloadSelected || downloadApproved) && (!rosettaSelected || appleLicenseAccepted)
  }

  func refresh() async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      report = try await service.report()
      rosettaSelected = report?.host.supported == true && report?.host.rosettaInstalled == false
      log("Prerequisites checked. Downloading an archive does not enable Windows launching.")
    } catch { log(error.localizedDescription) }
  }

  func startSetup() {
    guard canSetUp else { return }
    let rosetta = rosettaSelected
    let download = downloadSelected
    let accepted = appleLicenseAccepted
    let approved = downloadApproved
    busy = true
    operation = Task {
      defer { busy = false; operation = nil }
      do {
        if rosetta {
          log("Requesting Rosetta installation from Apple's softwareupdate service…")
          try await Rosetta.install(licenseAccepted: accepted)
          log("Rosetta installation completed and its marker was detected.")
        }
        if download {
          log("Acquiring the pinned Wine 11.0_1 archive. It will not be unpacked or executed.")
          _ = try await service.downloadRuntime(approved: approved) { [weak self] update in
            Task { @MainActor [weak self] in self?.progress = update }
          }
          log("Wine archive SHA-256 verified. Runtime activation is still not implemented.")
        }
        report = try await service.report()
        if report?.host.rosettaInstalled == true { rosettaSelected = false }
      } catch is CancellationError {
        progress = nil
        log("Setup cancelled. Recheck prerequisites; an OS installation already started may continue independently.")
      } catch {
        progress = nil
        log(error.localizedDescription)
      }
    }
  }

  func cancel() { operation?.cancel() }
  func revealArchive() {
    guard report?.runtimeArchiveVerified == true else { return }
    let url = SetupService.defaultCacheDirectory.appendingPathComponent(BuiltinComponents.standardWine.fileName)
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  func copyReport() {
    guard let report else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(report) else { return }
    let text = "Mallow source: \(revision)\n" + String(decoding: data, as: UTF8.self)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    log("Copied a report containing build revision and prerequisite status, not personal file paths.")
  }
  private func log(_ message: String) {
    messages.append(message)
    if messages.count > 80 { messages.removeFirst(messages.count - 80) }
  }
}
