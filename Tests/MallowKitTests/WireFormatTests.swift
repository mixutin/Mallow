// SPDX-License-Identifier: 0BSD
import Foundation
import MallowKit
import Testing

@Suite struct WireFormatTests {
  private static let directory = URL(filePath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Fixtures/wire")

  private func fixture<T: Codable & Equatable>(_ value: T, named name: String) throws {
    let encoded = try JSONStore.encoder.encode(value)
    let url = Self.directory.appendingPathComponent("\(name).json")
    if ProcessInfo.processInfo.environment["MALLOW_UPDATE_GOLDENS"] == "1" {
      try (encoded + Data([0x0A])).write(to: url, options: .atomic)
    }
    let expected = try Data(contentsOf: url)
    #expect(encoded + Data([0x0A]) == expected)
    #expect(try JSONStore.decoder.decode(T.self, from: expected) == value)
    #expect(
      try JSONStore.encoder.encode(JSONStore.decoder.decode(T.self, from: expected)) == encoded)
  }

  private func defaults<T: Codable & Equatable & DefaultConstructible>(_ type: T.Type) throws {
    let value = try JSONStore.decoder.decode(type, from: Data("{}".utf8))
    #expect(value == T())
    try fixture(value, named: String(describing: type))
  }

  @Test func settingsDefaultFixtures() throws {
    try defaults(DXVKOptions.self)
    try defaults(DXMTOptions.self)
    try defaults(D3DMetalOptions.self)
    try defaults(WineD3DOptions.self)
    try defaults(GraphicsSettings.self)
    try defaults(WindowsSettings.self)
    try defaults(CPUSettings.self)
    try defaults(DisplaySettings.self)
    try defaults(InputSettings.self)
    try defaults(DebugSettings.self)
    try defaults(SandboxSettings.self)
    try defaults(RuntimeSelection.self)
  }

  @Test func populatedGraphicsFixture() throws {
    var settings = GraphicsSettings()
    settings.backend = .dxmt
    settings.hideD3D12 = false
    settings.dxvk.async = false
    settings.dxvk.hud = "fps"
    settings.dxmt.metalFXSpatial = true
    settings.dxmt.spatialUpscaleFactor = 1.5
    settings.dxmt.nvext = true
    settings.d3dmetal.dxr = false
    settings.d3dmetal.metalFX = true
    settings.d3dmetal.nvapi = true
    settings.wined3d.renderer = .vulkan
    settings.wined3d.csmt = false
    settings.imageOverrides = [ImageOverride(match: "steam.exe", backend: .wined3d)]
    try fixture(settings, named: "GraphicsSettings.populated")
    try fixture(settings.imageOverrides[0], named: "ImageOverride")
  }

  @Test func programSourceFixtures() throws {
    try fixture(ProgramSource.manual, named: "ProgramSource.manual")
    try fixture(
      ProgramSource.startMenu(lnkPath: #"C:\ProgramData\Start Menu\Game.lnk"#),
      named: "ProgramSource.startMenu")
    try fixture(
      ProgramSource.desktop(lnkPath: #"C:\users\mallow\Desktop\Game.lnk"#),
      named: "ProgramSource.desktop")
    try fixture(ProgramSource.recipe(id: "steam"), named: "ProgramSource.recipe")
    try fixture(ProgramSource.steamLibrary(appID: "620"), named: "ProgramSource.steamLibrary")
  }

  @Test func defaultProvidersAndUnknownFields() throws {
    struct Probe: Codable, Equatable {
      @Defaulted<SchemaV1> var schemaVersion: Int
      @Defaulted<EmptyArray<String>> var names: [String]
      @Defaulted<EmptyDictionary<String, Int>> var counts: [String: Int]
    }
    let empty = try JSONStore.decoder.decode(Probe.self, from: Data("{}".utf8))
    #expect(empty.schemaVersion == 1 && empty.names.isEmpty && empty.counts.isEmpty)
    let data = Data(#"{"schemaVersion":7,"names":["kept"],"counts":{"a":3},"future":true}"#.utf8)
    let populated = try JSONStore.decoder.decode(Probe.self, from: data)
    #expect(
      populated.schemaVersion == 7 && populated.names == ["kept"] && populated.counts == ["a": 3])
    #expect(
      try JSONStore.decoder.decode(Probe.self, from: JSONStore.encoder.encode(populated))
        == populated)
    let settings = try JSONStore.decoder.decode(
      SandboxSettings.self, from: Data(#"{"future":true}"#.utf8))
    #expect(settings == SandboxSettings())
  }

  @Test func explicitValuesAreNotReplacedWithDefaults() throws {
    let data = Data(
      #"{"backend":"dxvk","dxvk":{"async":false},"autoImageRules":false,"hideD3D12":false}"#.utf8)
    let settings = try JSONStore.decoder.decode(GraphicsSettings.self, from: data)
    #expect(settings.backend == .dxvk && !settings.dxvk.async && !settings.autoImageRules)
    #expect(settings.hideD3D12 == false && settings.wined3d.csmt)
    let sandbox = try JSONStore.decoder.decode(
      SandboxSettings.self, from: Data(#"{"hideHostRoot":false,"linkHomeFolders":true}"#.utf8))
    #expect(!sandbox.hideHostRoot && sandbox.linkHomeFolders)
  }

  @Test func nullDefaultsDoNotLeakBackOntoWire() throws {
    let data = Data(#"{"backend":null,"dxvk":null,"hideD3D12":null}"#.utf8)
    let settings = try JSONStore.decoder.decode(GraphicsSettings.self, from: data)
    #expect(settings == GraphicsSettings())
    let text = String(decoding: try JSONStore.encoder.encode(settings), as: UTF8.self)
    #expect(!text.contains("null"))
    #expect(!text.contains("hideD3D12"))
    #expect(!text.contains("dxr"))
  }

  @Test(arguments: [
    #"{"backend":false}"#, #"{"backend":"futureBackend"}"#,
    #"{"dxvk":{"async":"false"}}"#, #"{"dxmt":{"nvext":1}}"#,
    #"{"dxvk":[]}"#, #"{"imageOverrides":{}}"#,
    #"{"d3dmetal":{"dxr":"true"}}"#, #"{"imageOverrides":[{}]}"#,
  ])
  func malformedSettingsThrow(json: String) {
    #expect(throws: DecodingError.self) {
      try JSONStore.decoder.decode(GraphicsSettings.self, from: Data(json.utf8))
    }
  }

  @Test(arguments: [
    "{}", "[]", "null", "true", #""unknown""#,
    #"{"recipe":"steam","manual":null}"#, #"{"recipe":"steam","future":true}"#,
    #"{"manual":{}}"#, #"{"recipe":null}"#, #"{"recipe":17}"#,
    #"{"unknown":"steam"}"#, #"{"recipe":{"id":"steam"}}"#,
  ])
  func malformedTagsThrow(json: String) {
    #expect(throws: DecodingError.self) {
      try JSONStore.decoder.decode(ProgramSource.self, from: Data(json.utf8))
    }
  }

  @Test func datesAndDictionaryKeysAreCanonical() throws {
    struct Record: Codable, Equatable {
      var date: Date
      var values: [String: Int]
      var absent: String?
    }
    let date = Date(timeIntervalSince1970: 1_700_000_000.75)
    let encoded = try JSONStore.encoder.encode(Record(date: date, values: ["z": 1, "a": 2]))
    let text = String(decoding: encoded, as: UTF8.self)
    #expect(text.contains("2023-11-14T22:13:20Z"))
    #expect(!text.contains("absent"))
    let a = try #require(text.range(of: "\"a\""))
    let z = try #require(text.range(of: "\"z\""))
    #expect(a.lowerBound < z.lowerBound)
    #expect(
      try JSONStore.decoder.decode(Record.self, from: encoded).date
        == Date(timeIntervalSince1970: 1_700_000_000))
  }
}

private struct PathRecord: Codable, Equatable {
  var path: URL
  var optional: URL?
  enum CodingKeys: String, CodingKey { case path, optional }
  init(path: URL, optional: URL? = nil) {
    self.path = path
    self.optional = optional
  }
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    path = try container.decodePath(forKey: .path)
    optional = try container.decodePathIfPresent(forKey: .optional)
  }
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodePath(path, forKey: .path)
    try container.encodePathIfPresent(optional, forKey: .optional)
  }
}

extension WireFormatTests {
  @Test func localPathsAreNotURLsOrPercentEncodedStrings() throws {
    let path = "/tmp/Mallow games/ä 100% #1.exe"
    let record = PathRecord(path: URL(filePath: path))
    let data = try JSONStore.encoder.encode(record)
    #expect(try JSONStore.decoder.decode(PathRecord.self, from: data) == record)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    #expect(object == ["path": path])
    let withOptional = PathRecord(
      path: URL(filePath: "/tmp/main"), optional: URL(filePath: "/tmp/other"))
    #expect(
      try JSONStore.decoder.decode(PathRecord.self, from: JSONStore.encoder.encode(withOptional))
        == withOptional)
  }

  @Test(arguments: [
    "relative/game.exe", "~/game.exe", "file:///tmp/game.exe", "https://example.invalid/game.exe",
    "", "/tmp/a\0b",
  ])
  func invalidPathsAreRejected(path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: ["path": path])
    #expect(throws: DecodingError.self) {
      try JSONStore.decoder.decode(PathRecord.self, from: data)
    }
  }

  @Test(arguments: ["https://example.invalid/game.exe", "file://remote-server/game.exe"])
  func nonlocalURLsCannotBeEncodedAsPaths(string: String) throws {
    let url = try #require(URL(string: string))
    #expect(throws: EncodingError.self) { try JSONStore.encoder.encode(PathRecord(path: url)) }
  }
}
