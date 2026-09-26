// SPDX-License-Identifier: 0BSD
import SwiftUI
import Darwin

@main struct MallowApp: App {
  @StateObject private var model = AppModel()

  init() {
    // Binary/linker smoke check only, not evidence that the graphical UI was tested.
    if CommandLine.arguments.contains("--smoke-test") {
      print("mallow-app-bootstrap-ok")
      exit(0)
    }
  }

  var body: some Scene {
    WindowGroup("Mallow") {
      OnboardingView(model: model)
        .frame(minWidth: 760, minHeight: 620)
        .task { await model.refresh() }
    }
    .defaultSize(width: 880, height: 760)
  }
}
