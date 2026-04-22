//
//  Icons.swift
//  Flashcards
//
//  Purpose: Stroke-drawn shape structs for the ten MWIconName cases.
//  Dependencies: SwiftUI, MWColor, MWBorder.
//  Key concepts: Each icon renders into a square frame; path points are
//                expressed as a fraction of the smaller side so the icon scales
//                cleanly at any MWIcon size. Stroke weight stays consistent
//                (MWBorder.defaultWidth) for visual parity with MW surfaces.
//

import SwiftUI

private let strokeStyle = StrokeStyle(
    lineWidth: MWBorder.defaultWidth,
    lineCap: .round,
    lineJoin: .round
)

struct HomeIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.1, y: side * 0.5))
                path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.15))
                path.addLine(to: CGPoint(x: side * 0.9, y: side * 0.5))
                path.move(to: CGPoint(x: side * 0.2, y: side * 0.45))
                path.addLine(to: CGPoint(x: side * 0.2, y: side * 0.9))
                path.addLine(to: CGPoint(x: side * 0.8, y: side * 0.9))
                path.addLine(to: CGPoint(x: side * 0.8, y: side * 0.45))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct SearchIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side * 0.3
            ZStack {
                Circle()
                    .stroke(MWColor.ink, style: strokeStyle)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: side * 0.4, y: side * 0.4)
                Path { path in
                    path.move(to: CGPoint(x: side * 0.65, y: side * 0.65))
                    path.addLine(to: CGPoint(x: side * 0.9, y: side * 0.9))
                }
                .stroke(MWColor.ink, style: strokeStyle)
            }
        }
    }
}

struct SettingsIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.15, y: side * 0.25))
                path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.25))
                path.move(to: CGPoint(x: side * 0.15, y: side * 0.5))
                path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.5))
                path.move(to: CGPoint(x: side * 0.15, y: side * 0.75))
                path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.75))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct AddIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.5, y: side * 0.15))
                path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.85))
                path.move(to: CGPoint(x: side * 0.15, y: side * 0.5))
                path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.5))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct DeleteIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.2, y: side * 0.3))
                path.addLine(to: CGPoint(x: side * 0.8, y: side * 0.3))
                path.move(to: CGPoint(x: side * 0.3, y: side * 0.3))
                path.addLine(to: CGPoint(x: side * 0.32, y: side * 0.85))
                path.addLine(to: CGPoint(x: side * 0.68, y: side * 0.85))
                path.addLine(to: CGPoint(x: side * 0.7, y: side * 0.3))
                path.move(to: CGPoint(x: side * 0.4, y: side * 0.2))
                path.addLine(to: CGPoint(x: side * 0.6, y: side * 0.2))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct BackIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.6, y: side * 0.2))
                path.addLine(to: CGPoint(x: side * 0.3, y: side * 0.5))
                path.addLine(to: CGPoint(x: side * 0.6, y: side * 0.8))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct MoreIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side * 0.06
            HStack(spacing: side * 0.18) {
                Circle().fill(MWColor.ink).frame(width: radius * 2, height: radius * 2)
                Circle().fill(MWColor.ink).frame(width: radius * 2, height: radius * 2)
                Circle().fill(MWColor.ink).frame(width: radius * 2, height: radius * 2)
            }
            .frame(width: side, height: side)
        }
    }
}

struct CheckIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.15, y: side * 0.55))
                path.addLine(to: CGPoint(x: side * 0.4, y: side * 0.8))
                path.addLine(to: CGPoint(x: side * 0.85, y: side * 0.25))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct CloseIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.2, y: side * 0.2))
                path.addLine(to: CGPoint(x: side * 0.8, y: side * 0.8))
                path.move(to: CGPoint(x: side * 0.8, y: side * 0.2))
                path.addLine(to: CGPoint(x: side * 0.2, y: side * 0.8))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}

struct ChevronRightIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: side * 0.4, y: side * 0.2))
                path.addLine(to: CGPoint(x: side * 0.7, y: side * 0.5))
                path.addLine(to: CGPoint(x: side * 0.4, y: side * 0.8))
            }
            .stroke(MWColor.ink, style: strokeStyle)
        }
    }
}
