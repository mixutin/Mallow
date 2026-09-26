// SPDX-License-Identifier: 0BSD
import Foundation

public enum BuiltinComponents {
  // DESIGN.md §3.11.6. Pin verified against the upstream GitHub release-asset API,
  // https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases/assets/397814211
  // on 2026-09-26. Do not replace this pin with a hash fetched alongside a download.
  public static let standardWine = DownloadSpec(
    id: "standard-wine-stable-11.0_1", fileName: "wine-stable-11.0_1-osx64.tar.xz",
    url: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz")!,
    size: 185_303_032,
    sha256: "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388",
    allowedHosts: ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"])
}
