// SPDX-License-Identifier: 0BSD
import Foundation

/// Bounded architecture-header inspection, not signature verification or a loader.
/// Layout: Apple's mach-o/loader.h and mach-o/fat.h in apple-oss-distributions/cctools.
public enum MachOHeader {
  public enum HeaderError: Error { case malformed }
  public static let x86_64: UInt32 = 0x0100_0007
  public static let arm64: UInt32 = 0x0100_000c

  public static func cpuTypes(in data: Data) throws -> Set<UInt32> {
    let bytes = Array(data.prefix(4096))
    func word(_ offset: Int, little: Bool = false) throws -> UInt32 {
      guard offset >= 0, offset <= bytes.count - 4 else { throw HeaderError.malformed }
      let slice = bytes[offset..<offset + 4]
      return (little ? Array(slice.reversed()) : Array(slice)).reduce(0) { ($0 << 8) | UInt32($1) }
    }
    let magic = try word(0)
    switch magic {
    case 0xfeed_face, 0xcefa_edfe, 0xfeed_facf, 0xcffa_edfe:
      let is64 = magic == 0xfeed_facf || magic == 0xcffa_edfe
      guard bytes.count >= (is64 ? 32 : 28) else { throw HeaderError.malformed }
      return [try word(4, little: magic == 0xcefa_edfe || magic == 0xcffa_edfe)]
    case 0xcafe_babe, 0xbeba_feca, 0xcafe_babf, 0xbfba_feca:
      let little = magic == 0xbeba_feca || magic == 0xbfba_feca
      let count = Int(try word(4, little: little))
      let stride = magic == 0xcafe_babf || magic == 0xbfba_feca ? 32 : 20
      guard count > 0, count <= 64, bytes.count >= 8 + count * stride else {
        throw HeaderError.malformed
      }
      var result = Set<UInt32>()
      for index in 0..<count { result.insert(try word(8 + index * stride, little: little)) }
      return result
    default: throw HeaderError.malformed
    }
  }

  static func readCPUTypeHeader(at url: URL) throws -> Set<UInt32> {
    let info = try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)
    guard info[.type] as? FileAttributeType == .typeRegular else { throw HeaderError.malformed }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    return try cpuTypes(in: handle.read(upToCount: 4096) ?? Data())
  }
}
