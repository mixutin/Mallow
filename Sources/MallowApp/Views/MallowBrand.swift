// SPDX-License-Identifier: 0BSD
import SwiftUI

// Geometry and flower colors match docs/assets/logo.svg and favicon.svg (the existing website mark).
enum MallowTheme {
  static let background = Color(red: 0.075, green: 0.039, blue: 0.082)
  static let surface = Color(red: 0.14, green: 0.075, blue: 0.15)
  static let accent = Color(red: 0.95, green: 0.58, blue: 0.77)
  static let ink = Color(red: 0.14, green: 0.05, blue: 0.10)
  static let secondary = Color(red: 0.80, green: 0.67, blue: 0.76)
}

private struct MallowPetal: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 24, y: 24))
    path.addCurve(to: CGPoint(x: 24, y: 4.5), control1: CGPoint(x: 16.5, y: 19.5), control2: CGPoint(x: 15.5, y: 9))
    path.addCurve(to: CGPoint(x: 24, y: 24), control1: CGPoint(x: 32.5, y: 9), control2: CGPoint(x: 31.5, y: 19.5))
    path.closeSubpath()
    return path.applying(CGAffineTransform(scaleX: rect.width / 48, y: rect.height / 48))
  }
}

struct MallowFlower: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(0..<5) { index in
          MallowPetal().fill(Color(red: 253/255, green: 243/255, blue: 249/255))
            .rotationEffect(.degrees(Double(index) * 72))
        }
        Circle().fill(Color(red: 242/255, green: 163/255, blue: 207/255))
          .frame(width: geometry.size.width * 10/48, height: geometry.size.height * 10/48)
        Circle().fill(Color(red: 194/255, green: 64/255, blue: 138/255))
          .frame(width: geometry.size.width * 4.4/48, height: geometry.size.height * 4.4/48)
      }
    }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
  }
}

struct MallowMark: View {
  var body: some View {
    MallowFlower().padding(9)
      .background(LinearGradient(colors: [Color(red: 142/255, green: 91/255, blue: 161/255),
        Color(red: 90/255, green: 49/255, blue: 105/255)], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 18))
      .accessibilityLabel("Mallow flower logo")
  }
}

/// Mounted only while work is active. No artificial delay; motion pauses when the app is inactive.
struct MallowLoader: View {
  let label: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  var body: some View {
    HStack(spacing: 14) {
      TimelineView(.animation(minimumInterval: 1.0/30, paused: reduceMotion || scenePhase != .active)) { context in
        ZStack {
          Circle().stroke(MallowTheme.accent.opacity(0.16), lineWidth: 3)
          Circle().trim(from: 0, to: 0.72)
            .stroke(MallowTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4 * 360))
          MallowFlower().padding(8)
        }
      }.frame(width: 42, height: 42)
      Text(label).font(.callout.weight(.medium))
    }.accessibilityElement(children: .ignore).accessibilityLabel(label)
  }
}

struct PinkActionStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.body.weight(.semibold)).padding(.horizontal, 18).padding(.vertical, 11)
      .foregroundStyle(enabled ? MallowTheme.ink : MallowTheme.secondary)
      .background(enabled ? MallowTheme.accent.opacity(configuration.isPressed ? 0.8 : 1) : Color.white.opacity(0.08),
        in: RoundedRectangle(cornerRadius: 11))
  }
}
