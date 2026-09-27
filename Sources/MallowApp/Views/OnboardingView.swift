// SPDX-License-Identifier: 0BSD
import SwiftUI
import MallowKit

struct OnboardingView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(MallowTheme.accent.opacity(0.15))
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("A softer landing for your Windows apps.")
            .font(.title2.weight(.semibold))
          Text("Let's prepare your Mac. You stay in control of what gets installed.")
            .foregroundStyle(MallowTheme.secondary)
          hostCard
          setupCard
          activityCard
          Label("Development preview: Wine can be installed, but Windows launching, bottles and the kernel sandbox are not implemented yet.", systemImage: "exclamationmark.shield")
            .font(.callout).foregroundStyle(MallowTheme.secondary)
          HStack {
            Text("Local setup. Explicit consent. No telemetry.")
            Spacer()
            Text(String(model.revision.prefix(12))).font(.caption.monospaced())
          }.font(.caption).foregroundStyle(MallowTheme.secondary)
        }.padding(28).frame(maxWidth: 880)
      }
    }.background(MallowTheme.background).tint(MallowTheme.accent).preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: 16) {
      MallowMark().frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: 2) {
        Text("Mallow").font(.system(size: 32, weight: .bold, design: .rounded))
        Text("Your Mac, ready for the next step.").font(.callout).foregroundStyle(MallowTheme.secondary)
      }
      Spacer()
      Text("PRE-ALPHA").font(.caption2.weight(.bold)).tracking(1.5)
        .padding(9).background(MallowTheme.surface, in: Capsule())
      Link("Roadmap ↗", destination: URL(string: "https://mixutin.github.io/Mallow/roadmap/")!)
    }.padding(.horizontal, 28).padding(.vertical, 22)
  }

  private var hostCard: some View {
    card("01", "Your Mac", icon: "desktopcomputer") {
      if let report = model.report {
        HStack(alignment: .top, spacing: 24) {
          status("Platform", report.host.supported ? "Apple Silicon · macOS \(report.host.version)" : "Unsupported host", okay: report.host.supported)
          Spacer()
          status("Rosetta", report.host.rosettaInstalled ? "Detected" : "Not installed", okay: report.host.rosettaInstalled)
          Spacer()
          status("Wine runtime", report.runtimeActivated ? "Installed" : "Not installed", okay: report.runtimeActivated)
        }
        if report.runtimeArchiveCached && !report.runtimeActivated {
          Label("Your cached Wine archive will be checked and reused—no unnecessary download.", systemImage: "arrow.down.circle")
            .font(.caption).foregroundStyle(MallowTheme.secondary)
        }
        HStack {
          Button("Recheck prerequisites") { Task { await model.refresh() } }.disabled(model.busy)
          Button("Copy test report") { model.copyReport() }
          if report.runtimeActivated {
            Button("Show runtime in Finder") { model.revealRuntime() }.disabled(model.busy)
          }
        }.buttonStyle(.bordered)
      } else if model.busy {
        MallowLoader(label: "Checking your Mac")
      } else {
        Text("The prerequisite check did not complete. See the activity log below.")
        Button("Retry check") { Task { await model.refresh() } }
      }
    }
  }

  private var setupCard: some View {
    card("02", "Prepare your runtime", icon: "shippingbox") {
      if model.report?.runtimeActivated == true {
        Label("Wine 11.0_1 is installed in Mallow's own runtime directory.", systemImage: "checkmark.seal.fill")
          .foregroundStyle(MallowTheme.accent)
        Text("A lightweight check keeps startup fast. Run a full integrity check whenever you need to verify the installed files.")
          .font(.callout).foregroundStyle(MallowTheme.secondary)
        Button("Verify runtime") { model.verifyRuntime() }.buttonStyle(PinkActionStyle()).disabled(model.busy)
        if let result = model.integrity {
          Label(result.passed ? "Integrity verified · \(result.checkedFiles) files" : "Integrity check failed · review the log", systemImage: result.passed ? "checkmark.shield" : "exclamationmark.shield")
        }
      } else {
        Toggle("Install Wine 11.0_1", isOn: $model.runtimeSelected).font(.body.weight(.semibold))
        Text("185 MB download, at least 2 GB free space for setup. The app verifies, unpacks and registers Wine for you.")
          .font(.caption).foregroundStyle(MallowTheme.secondary)
        if model.runtimeSelected {
          Link("Review the upstream release, source and licence ↗", destination: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1")!)
          Text("Wine: LGPL-2.1-or-later. Source hosts: GitHub and its release-asset CDN. Mono and Gecko are included in the upstream bundle. GStreamer setup is a separate, unfinished step.")
            .font(.caption).foregroundStyle(MallowTheme.secondary)
          Toggle("I approve downloading and installing this runtime", isOn: $model.downloadApproved)
        }
      }
      if model.report?.host.rosettaInstalled == false {
        Divider().padding(.vertical, 4)
        Toggle("Install Rosetta through Apple", isOn: $model.rosettaSelected)
        if model.rosettaSelected {
          Link("Read Apple's software licence ↗", destination: Rosetta.licenseURL)
          Toggle("I have reviewed and agree to Apple's Rosetta licence", isOn: $model.appleLicenseAccepted)
        }
      }
      if model.report?.runtimeActivated != true || model.rosettaSelected {
        Button("Install selected dependencies") { model.startSetup() }
          .buttonStyle(PinkActionStyle()).disabled(!model.canSetUp)
      }
      Text("Opening Mallow alone does not install anything. Setup never installs Homebrew, downloads D3DMetal or disables Gatekeeper.")
        .font(.caption).foregroundStyle(MallowTheme.secondary)
    }.disabled(model.busy)
  }

  private var activityCard: some View {
    card("03", "Activity", icon: "waveform.path") {
      if model.busy && model.report != nil {
        HStack {
          MallowLoader(label: model.activity)
          Spacer()
          if model.canCancel { Button("Cancel") { model.cancel() }.buttonStyle(.bordered) }
        }
        if let progress = model.progress, progress.phase == .downloading || progress.phase == .verifying {
          ProgressView(value: progress.fraction).tint(MallowTheme.accent)
          Text("\(progress.received / 1_000_000) / \(progress.expected / 1_000_000) MB")
            .font(.caption.monospaced()).foregroundStyle(MallowTheme.secondary)
        }
      }
      if model.messages.isEmpty {
        Text("Setup events and verification results appear here.").foregroundStyle(MallowTheme.secondary)
      } else {
        ScrollView {
          Text(model.messages.joined(separator: "\n"))
            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(minHeight: 80, maxHeight: 140)
      }
    }
  }

  private func status(_ title: String, _ detail: String, okay: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.caption).foregroundStyle(MallowTheme.secondary)
      Label(detail, systemImage: okay ? "checkmark.circle.fill" : "circle.dashed")
        .font(.callout.weight(.medium))
    }
  }

  private func card<Content: View>(_ number: String, _ title: String, icon: String,
    @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Text(number).font(.caption.monospaced().weight(.bold)).foregroundStyle(MallowTheme.accent)
        Label(title, systemImage: icon).font(.headline)
      }
      content()
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
      .background(MallowTheme.surface, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(MallowTheme.accent.opacity(0.14), lineWidth: 1))
  }
}
