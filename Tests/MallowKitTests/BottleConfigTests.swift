// SPDX-License-Identifier: 0BSD
import Foundation
import MallowKit
import Testing

// Tests for the settings values that will be embedded in BottleConfig; the full model is not implemented yet.
@Suite struct BottleConfigTests {
  @Test func defaultsPreserveTheDocumentedSafetySettings() {
    let sandbox = SandboxSettings()
    #expect(sandbox.hideHostRoot)
    #expect(!sandbox.linkHomeFolders)
    #expect(!CPUSettings().advertiseAVX)
    #expect(WindowsSettings().version == .win10)
    #expect(WindowsSettings().userName == "mallow")
    #expect(GraphicsSettings().backend == .auto)
    #expect(GraphicsSettings().hideD3D12 == nil)
    #expect(D3DMetalOptions().dxr == nil)
    #expect(RuntimeSelection().id == nil && !RuntimeSelection().pinned)
  }

  @Test(arguments: WindowsVersion.allCases)
  func windowsVersionsRoundTrip(version: WindowsVersion) throws {
    let data = try JSONStore.encoder.encode(version)
    #expect(String(decoding: data, as: UTF8.self) == "\"\(version.rawValue)\"")
    #expect(try JSONStore.decoder.decode(WindowsVersion.self, from: data) == version)
  }

  @Test(arguments: GraphicsBackendKind.allCases)
  func graphicsBackendsRoundTrip(backend: GraphicsBackendKind) throws {
    let data = try JSONStore.encoder.encode(backend)
    #expect(String(decoding: data, as: UTF8.self) == "\"\(backend.rawValue)\"")
    #expect(try JSONStore.decoder.decode(GraphicsBackendKind.self, from: data) == backend)
  }
}
