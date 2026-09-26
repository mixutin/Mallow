// SPDX-License-Identifier: 0BSD
import Foundation
import MallowKit
import Testing

@Suite struct JSONStoreTests {
  private func inTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "mallow-tests-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
  }

  @Test func createAndReplace() throws {
    try inTemporaryDirectory { directory in
      let url = directory.appendingPathComponent("settings.json")
      try JSONStore.writeAtomically(SandboxSettings(), to: url)
      #expect(try JSONStore.read(SandboxSettings.self, from: url) == SandboxSettings())
      var changed = SandboxSettings()
      changed.hideHostRoot = false
      try JSONStore.writeAtomically(changed, to: url)
      #expect(try JSONStore.readIfPresent(SandboxSettings.self, from: url) == changed)
      #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["settings.json"])
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }
  }

  @Test func missingIsOptionalButCorruptionIsNot() throws {
    try inTemporaryDirectory { directory in
      let url = directory.appendingPathComponent("settings.json")
      #expect(try JSONStore.readIfPresent(SandboxSettings.self, from: url) == nil)
      try Data("{broken".utf8).write(to: url)
      #expect(throws: DecodingError.self) {
        try JSONStore.readIfPresent(SandboxSettings.self, from: url)
      }
      try Data(#"{"hideHostRoot":"false"}"#.utf8).write(to: url)
      #expect(throws: DecodingError.self) {
        try JSONStore.readIfPresent(SandboxSettings.self, from: url)
      }
    }
  }

  @Test func encodingFailurePreservesPreviousFile() throws {
    try inTemporaryDirectory { directory in
      let url = directory.appendingPathComponent("settings.json")
      try JSONStore.writeAtomically(["value": 42], to: url)
      let original = try Data(contentsOf: url)
      #expect(throws: EncodingError.self) {
        try JSONStore.writeAtomically(["value": Double.nan], to: url)
      }
      #expect(try Data(contentsOf: url) == original)
      #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["settings.json"])
    }
  }

  @Test func replacementFailureCleansTemporaryFile() throws {
    try inTemporaryDirectory { directory in
      let target = directory.appendingPathComponent("nonempty-directory")
      try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
      try Data("keep".utf8).write(to: target.appendingPathComponent("original"))
      #expect(throws: POSIXError.self) {
        try JSONStore.writeAtomically(SandboxSettings(), to: target)
      }
      #expect(
        try FileManager.default.contentsOfDirectory(atPath: directory.path) == [
          "nonempty-directory"
        ])
      #expect(
        try String(contentsOf: target.appendingPathComponent("original"), encoding: .utf8) == "keep"
      )
    }
  }

  @Test func missingParentIsNotCreatedImplicitly() throws {
    try inTemporaryDirectory { directory in
      let url = directory.appendingPathComponent("missing/settings.json")
      #expect(throws: POSIXError.self) { try JSONStore.writeAtomically(SandboxSettings(), to: url) }
      let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      #expect(remaining.isEmpty)
    }
  }

  @Test func replacingASymlinkDoesNotWriteThroughIt() throws {
    try inTemporaryDirectory { directory in
      let original = directory.appendingPathComponent("original")
      let link = directory.appendingPathComponent("settings.json")
      try Data("keep".utf8).write(to: original)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
      try JSONStore.writeAtomically(SandboxSettings(), to: link)
      #expect(try String(contentsOf: original, encoding: .utf8) == "keep")
      #expect(try JSONStore.read(SandboxSettings.self, from: link) == SandboxSettings())
      #expect(
        try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType
          == .typeRegular)
    }
  }

  @Test func remoteLocationsAreRejectedWithoutNetworking() throws {
    let url = try #require(URL(string: "https://example.invalid/settings.json"))
    #expect(throws: CocoaError.self) {
      try JSONStore.readIfPresent(SandboxSettings.self, from: url)
    }
    #expect(throws: CocoaError.self) { try JSONStore.writeAtomically(SandboxSettings(), to: url) }
  }
}
