// SPDX-License-Identifier: 0BSD

// Value types and defaults from DESIGN.md §3.4.2. These do not apply settings to Wine.
public enum GraphicsBackendKind: String, Codable, Sendable, CaseIterable {
  case auto, d3dmetal, dxmt, dxvk, wined3d
}
public enum SyncMode: String, Codable, Sendable { case msync, esync, none }
public enum WineDebugPreset: String, Codable, Sendable { case off, normal, crash, custom }

public struct DXVKOptions: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<True> public var async: Bool
  public var hud: String?
  public init() {}
}

public struct DXMTOptions: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<False> public var metalFXSpatial: Bool
  public var spatialUpscaleFactor: Double?
  @Defaulted<False> public var nvext: Bool
  public init() {}
}

public struct D3DMetalOptions: Codable, Sendable, Equatable, DefaultConstructible {
  public var dxr: Bool?
  @Defaulted<False> public var metalFX: Bool
  @Defaulted<False> public var nvapi: Bool
  public init() {}
}

public struct WineD3DOptions: Codable, Sendable, Equatable, DefaultConstructible {
  public enum Renderer: String, Codable, Sendable { case gl, vulkan }
  @Defaulted<RendererGL> public var renderer: Renderer
  @Defaulted<True> public var csmt: Bool
  public init() {}
}

public struct ImageOverride: Codable, Sendable, Equatable {
  public var match: String
  public var backend: GraphicsBackendKind
  public init(match: String, backend: GraphicsBackendKind) {
    self.match = match
    self.backend = backend
  }
}

public struct GraphicsSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<BackendAuto> public var backend: GraphicsBackendKind
  @Defaulted<False> public var preferD3DMetalForD3D11: Bool
  @Defaulted<False> public var metalHUD: Bool
  public var hideD3D12: Bool?
  @Defaulted<Init<DXVKOptions>> public var dxvk: DXVKOptions
  @Defaulted<Init<DXMTOptions>> public var dxmt: DXMTOptions
  @Defaulted<Init<D3DMetalOptions>> public var d3dmetal: D3DMetalOptions
  @Defaulted<Init<WineD3DOptions>> public var wined3d: WineD3DOptions
  @Defaulted<EmptyArray<ImageOverride>> public var imageOverrides: [ImageOverride]
  @Defaulted<True> public var autoImageRules: Bool
  public init() {}
}

public struct WindowsSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<WinVersion10> public var version: WindowsVersion
  @Defaulted<UserNameMallow> public var userName: String
  public init() {}
}

public struct CPUSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<False> public var advertiseAVX: Bool
  public init() {}
}

public struct DisplaySettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<False> public var retina: Bool
  public var dpi: Int?
  public init() {}
}

public struct InputSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<False> public var leftCommandIsCtrl: Bool
  @Defaulted<False> public var rightCommandIsCtrl: Bool
  @Defaulted<False> public var leftOptionIsAlt: Bool
  @Defaulted<False> public var rightOptionIsAlt: Bool
  public init() {}
}

public struct DebugSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<DebugNormal> public var preset: WineDebugPreset
  public var custom: String?
  public init() {}
}

/// Configuration only; no kernel sandbox or prefix hardening is implemented here.
public struct SandboxSettings: Codable, Sendable, Equatable, DefaultConstructible {
  @Defaulted<False> public var linkHomeFolders: Bool
  @Defaulted<True> public var hideHostRoot: Bool
  public init() {}
}

public struct RuntimeSelection: Codable, Sendable, Equatable, DefaultConstructible {
  public var id: String?
  @Defaulted<False> public var pinned: Bool
  public init() {}
}

// Keep bottle-specific providers in Bottles so Support never depends on a higher layer.
public enum BackendAuto: DefaultValueProvider {
  public static var value: GraphicsBackendKind { .auto }
}
public enum RendererGL: DefaultValueProvider {
  public static var value: WineD3DOptions.Renderer { .gl }
}
public enum WinVersion10: DefaultValueProvider {
  public static var value: WindowsVersion { .win10 }
}
public enum UserNameMallow: DefaultValueProvider { public static var value: String { "mallow" } }
public enum DebugNormal: DefaultValueProvider {
  public static var value: WineDebugPreset { .normal }
}
