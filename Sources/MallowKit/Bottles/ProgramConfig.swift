// SPDX-License-Identifier: 0BSD

/// DESIGN.md §3.7.0: payload-free cases are strings; payloads use a single-key object.
public enum ProgramSource: Sendable, Equatable, Codable {
  case startMenu(lnkPath: String)
  case desktop(lnkPath: String)
  case manual
  case recipe(id: String)
  case steamLibrary(appID: String)

  public init(from decoder: any Decoder) throws {
    if let tag = try? decoder.singleValueContainer().decode(String.self) {
      guard tag == "manual" else {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: decoder.codingPath, debugDescription: "Unknown ProgramSource tag: \(tag)"
          ))
      }
      self = .manual
      return
    }
    let (key, container) = try WireCoding.taggedContainer(from: decoder)
    switch key.stringValue {
    case "startMenu": self = .startMenu(lnkPath: try container.decode(String.self, forKey: key))
    case "desktop": self = .desktop(lnkPath: try container.decode(String.self, forKey: key))
    case "recipe": self = .recipe(id: try container.decode(String.self, forKey: key))
    case "steamLibrary": self = .steamLibrary(appID: try container.decode(String.self, forKey: key))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container,
        debugDescription: "Unknown ProgramSource tag: \(key.stringValue)"
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .manual:
      var container = encoder.singleValueContainer()
      try container.encode("manual")
    case .startMenu(let path): try WireCoding.encodeTagged(path, as: "startMenu", to: encoder)
    case .desktop(let path): try WireCoding.encodeTagged(path, as: "desktop", to: encoder)
    case .recipe(let id): try WireCoding.encodeTagged(id, as: "recipe", to: encoder)
    case .steamLibrary(let id): try WireCoding.encodeTagged(id, as: "steamLibrary", to: encoder)
    }
  }
}
