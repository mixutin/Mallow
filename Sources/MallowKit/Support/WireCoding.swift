// SPDX-License-Identifier: 0BSD
import Foundation

public protocol DefaultValueProvider {
  associatedtype Value: Codable & Sendable
  static var value: Value { get }
}

public protocol DefaultConstructible {
  init()
}

/// Missing or null keys use the provider; malformed non-null values still throw.
@propertyWrapper
public struct Defaulted<Provider: DefaultValueProvider>: Codable, Sendable {
  public var wrappedValue: Provider.Value

  public init() { wrappedValue = Provider.value }
  public init(wrappedValue: Provider.Value) { self.wrappedValue = wrappedValue }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    wrappedValue =
      container.decodeNil() ? Provider.value : try container.decode(Provider.Value.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wrappedValue)
  }
}

extension Defaulted: Equatable where Provider.Value: Equatable {}

public enum True: DefaultValueProvider { public static var value: Bool { true } }
public enum False: DefaultValueProvider { public static var value: Bool { false } }
public enum SchemaV1: DefaultValueProvider { public static var value: Int { 1 } }
public enum Init<T: DefaultConstructible & Codable & Sendable>: DefaultValueProvider {
  public static var value: T { T() }
}
public enum EmptyArray<T: Codable & Sendable>: DefaultValueProvider {
  public static var value: [T] { [] }
}
public enum EmptyDictionary<K: Hashable & Codable & Sendable, V: Codable & Sendable>:
  DefaultValueProvider
{
  public static var value: [K: V] { [:] }
}

/// Open-ended keys let a tagged union reject extra keys, including unknown ones.
public struct WireKey: CodingKey, Hashable, Sendable {
  public let stringValue: String
  public var intValue: Int? { nil }
  public init(_ value: String) { stringValue = value }
  public init?(stringValue: String) { self.init(stringValue) }
  public init?(intValue: Int) { return nil }
}

public enum WireCoding {
  public static func taggedContainer(from decoder: any Decoder) throws
    -> (key: WireKey, container: KeyedDecodingContainer<WireKey>)
  {
    let container = try decoder.container(keyedBy: WireKey.self)
    guard container.allKeys.count == 1, let key = container.allKeys.first else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "A tagged union must contain exactly one key."
        ))
    }
    return (key, container)
  }

  public static func encodeTagged<T: Encodable>(_ value: T, as tag: String, to encoder: any Encoder)
    throws
  {
    var container = encoder.container(keyedBy: WireKey.self)
    try container.encode(value, forKey: WireKey(tag))
  }

  static func isAbsolutePath(_ path: String) -> Bool {
    path.hasPrefix("/") && !path.utf8.contains(0)
  }
}

extension KeyedDecodingContainer {
  public func decode<P>(_ type: Defaulted<P>.Type, forKey key: Key) throws -> Defaulted<P> {
    try decodeIfPresent(type, forKey: key) ?? Defaulted<P>()
  }

  public func decodePath(forKey key: Key) throws -> URL {
    let path = try decode(String.self, forKey: key)
    guard WireCoding.isAbsolutePath(path) else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: self,
        debugDescription: "Expected an absolute POSIX path without NUL bytes."
      )
    }
    return URL(filePath: path)
  }

  public func decodePathIfPresent(forKey key: Key) throws -> URL? {
    guard contains(key), try !decodeNil(forKey: key) else { return nil }
    return try decodePath(forKey: key)
  }
}

extension KeyedEncodingContainer {
  public mutating func encodePath(_ url: URL, forKey key: Key) throws {
    let path = url.path(percentEncoded: false)
    guard url.isFileURL, WireCoding.isAbsolutePath(path),
      url.host == nil || url.host == "" || url.host == "localhost"
    else {
      throw EncodingError.invalidValue(
        url,
        .init(
          codingPath: codingPath + [key], debugDescription: "Expected a local absolute file URL."
        ))
    }
    try encode(path, forKey: key)
  }

  public mutating func encodePathIfPresent(_ url: URL?, forKey key: Key) throws {
    if let url { try encodePath(url, forKey: key) }
  }
}
