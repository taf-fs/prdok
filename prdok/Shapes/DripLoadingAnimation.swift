//
//  DripLoadingAnimation.swift
//  prdok
//
//  Created by David Horňák on 11.09.2026.
//

import SwiftUI


/// 4
/// the blocks stack up in the cup.
///
/// Drawn in the pixel coordinates of the 518 x 550 cpLogo asset and scaled to
/// whatever frame you give it. Edges snap to device pixels so adjacent blocks
/// stay flush at any size. Pure SwiftUI — no assets, no packages.
///
/// Determinate:   DripLoadingAnimation(progress: Double(done) / Double(total))
/// Indeterminate: DripLoadingAnimation()
struct DripLoadingAnimation: View {

    /// nil follows the logo assets: black in light mode, white in dark mode.
    var ink: Color? = nil
    var accent: Color = Color(red: 0.761, green: 0.341, blue: 0.122)
    /// 0...1 fills the cup deterministically; nil loops forever.
    var progress: Double? = nil

    private static let gridW: CGFloat = 518
    private static let gridH: CGFloat = 550

    private static let spout = CGRect(x: 150, y: 113, width: 51, height: 40)
    private static let cupInterior = CGRect(x: 113, y: 397, width: 116, height: 99)

    /// The static parts of the mark, measured from cpLogo.
    private static let mark: [CGRect] = [
        CGRect(x: 76, y: 0, width: 51, height: 113),   // left tine
        CGRect(x: 221, y: 0, width: 50, height: 113),  // right tine
        CGRect(x: 76, y: 62, width: 195, height: 51),  // basket
        CGRect(x: 271, y: 37, width: 247, height: 51), // handle
        spout,
        CGRect(x: 59, y: 346, width: 221, height: 51), // cup lip
        CGRect(x: 59, y: 346, width: 54, height: 150), // cup left wall
        CGRect(x: 229, y: 346, width: 51, height: 150),// cup right wall
        CGRect(x: 280, y: 411, width: 54, height: 54), // cup ear
        CGRect(x: 0, y: 496, width: 351, height: 54)   // slab
    ]

    // Drops fall through fixed slots spanning the logo's drip stream (y 176...312),
    // keeping its gaps to the spout (23) and the cup lip (34) so they never touch either.
    private static let dropH: CGFloat = 24
    private static let dropTop: CGFloat = 176
    private static let dropPitch: CGFloat = 28
    private static let dropSlots = 5
    private static let dropSpacing = 2         // a lit slot every other slot
    private static let stepDuration = 0.25     // stepped fall — brutalist, not smooth

    private static let barH: CGFloat = 24
    private static let barSlots = 3
    /// One landing per `dropSpacing` steps; the cup fills, holds, then empties on the next landing.
    private static let cycleSteps = dropSpacing * (barSlots + 1)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let step = Int(timeline.date.timeIntervalSinceReferenceDate / Self.stepDuration)
                let ink = self.ink ?? (ctx.environment.colorScheme == .dark ? .white : .black)

                let s = min(size.width / Self.gridW, size.height / Self.gridH)
                let ox = (size.width - Self.gridW * s) / 2
                let oy = (size.height - Self.gridH * s) / 2
                let scale = ctx.environment.displayScale

                func snap(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }

                func block(_ r: CGRect, _ color: Color) {
                    let x0 = snap(ox + r.minX * s), x1 = snap(ox + r.maxX * s)
                    let y0 = snap(oy + r.minY * s), y1 = snap(oy + r.maxY * s)
                    ctx.fill(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)), with: .color(color))
                }

                for r in Self.mark {
                    block(r, ink)
                }

                // falling drops — each step every lit slot moves down one
                for slot in 0..<Self.dropSlots where (step - slot) % Self.dropSpacing == 0 {
                    let y = Self.dropTop + Self.dropPitch * CGFloat(slot)
                    block(CGRect(x: Self.spout.minX, y: y, width: Self.spout.width, height: Self.dropH), accent)
                }

                // blocks that have landed
                let filled: Int = {
                    if let p = progress {
                        return Int(min(max(p, 0), 1) * Double(Self.barSlots))
                    }
                    // a drop leaves the last slot on steps where (step - dropSlots) % dropSpacing == 0
                    return (step - Self.dropSlots) % Self.cycleSteps / Self.dropSpacing
                }()
                for i in 0..<filled {
                    let y = Self.cupInterior.maxY - Self.barH * CGFloat(i + 1)
                    block(CGRect(x: Self.cupInterior.minX, y: y, width: Self.cupInterior.width, height: Self.barH), accent)
                }
            }
        }
        .accessibilityLabel("Loading")
    }
}

#Preview("Light") {
    DripLoadingAnimation()
        .frame(width: 190, height: 201)
        .padding(40)
        .background(Color.cpBackgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DripLoadingAnimation()
        .frame(width: 190, height: 201)
        .padding(40)
        .background(Color.cpBackgroundPrimary)
        .preferredColorScheme(.dark)
}
