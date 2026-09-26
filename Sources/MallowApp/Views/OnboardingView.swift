// SPDX-License-Identifier: 0BSD
import SwiftUI
import MallowKit

struct OnboardingView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 16) {
        Image(systemName: "shippingbox.fill").font(.system(size: 40)).foregroundStyle(.tint)
        VStack(alignment: .leading) {
          Text("Welcome to Mallow").font(.largeTitle.bold())
          Text("Development preview · first-run setup").foregroundStyle(.secondary)
        }
        Spacer()
        Link("Roadmap", destination: URL(string: "https://mixutin.github.io/Mallow/roadmap/")!)
      }.padding(24)
      Form {
        Section("What this build can do") {
          Text("Inspect your Mac, request Rosetta installation with your consent, and download and verify the pinned Wine archive.")
          Label("Windows launching is disabled. Runtime activation, bottles and the kernel sandbox are not implemented.", systemImage: "exclamationmark.shield")
            .foregroundStyle(.orange)
          LabeledContent("Build", value: String(model.revision.prefix(12))).font(.caption.monospaced())
        }
        Section("Your Mac") {
          if let report = model.report {
            LabeledContent("System", value: "\(report.host.system) \(report.host.version)")
            LabeledContent("Apple Silicon / macOS 15+", value: report.host.supported ? "Detected" : "Not supported")
            LabeledContent("Rosetta", value: report.host.rosettaInstalled ? "Detected (not Wine-tested)" : "Not detected")
            LabeledContent("Wine archive", value: report.runtimeArchiveVerified ? "Verified cache · not installed" : "Not verified / not downloaded")
          } else { Text("Checking prerequisites…").foregroundStyle(.secondary) }
          HStack {
            Button("Recheck") { Task { await model.refresh() } }.disabled(model.busy)
            Button("Copy test report") { model.copyReport() }.disabled(model.report == nil)
          }
        }
        Section("Set up dependencies") {
          Toggle("Download Wine 11.0_1 (185 MB)", isOn: $model.downloadSelected)
          if model.downloadSelected {
            Link("Review upstream release and source", destination: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1")!)
            Text("Wine is LGPL-2.1-or-later. Download hosts: github.com and GitHub's release-asset CDN. The archive includes Mono and Gecko. GStreamer setup and runtime activation remain pending.").font(.caption).foregroundStyle(.secondary)
            Toggle("I approve this download and have reviewed its source and licence information", isOn: $model.downloadApproved)
          }
          Toggle("Install Rosetta if missing", isOn: $model.rosettaSelected)
            .disabled(model.report?.host.rosettaInstalled == true)
          if model.rosettaSelected {
            Link("Read Apple's software licence", destination: Rosetta.licenseURL)
            Toggle("I have reviewed and agree to Apple's licence for Rosetta", isOn: $model.appleLicenseAccepted)
          }
          Text("Nothing is downloaded or installed merely by opening Mallow. Setup uses Apple's own installer for Rosetta; it never installs Homebrew, changes Gatekeeper, or downloads D3DMetal.")
            .font(.caption).foregroundStyle(.secondary)
        }.disabled(model.busy)
        Section("Setup progress") {
          if let progress = model.progress {
            ProgressView(value: progress.fraction)
            Text("\(progress.phase.rawValue.capitalized) · \(progress.received / 1_000_000) / \(progress.expected / 1_000_000) MB")
              .font(.caption.monospaced())
          } else if model.busy { ProgressView() }
          HStack {
            Button("Set up selected dependencies") { model.startSetup() }
              .buttonStyle(.borderedProminent).disabled(!model.canSetUp)
            if model.busy { Button("Cancel setup") { model.cancel() } }
            if model.report?.runtimeArchiveVerified == true {
              Button("Reveal archive") { model.revealArchive() }.disabled(model.busy)
            }
          }
          ScrollView {
            Text(model.messages.joined(separator: "\n"))
              .font(.caption.monospaced()).textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }.frame(minHeight: 60, maxHeight: 110)
        }
      }.formStyle(.grouped)
    }
  }
}
