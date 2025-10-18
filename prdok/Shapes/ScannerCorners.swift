//
//  ScannerCorners.swift
//  prdok
//
//  Created by David Horňák on 18.10.2025, generated with gpt-5
//

import SwiftUI

/// Draws four L-shaped corner bits around a rounded rect.
/// - cornerRadius: radius of the rounded corner
/// - cornerLength: how far each leg extends along the edges from the corner
///                 (total per edge; the straight part is max(0, cornerLength - cornerRadius))
/// - insetForStroke: usually lineWidth/2 so the stroke stays inside the frame
struct ScannerCorners: Shape {
    var cornerRadius: CGFloat = 24
    var cornerLength: CGFloat = 40
    var insetForStroke: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Keep stroke inside the frame
        let r = rect.insetBy(dx: insetForStroke, dy: insetForStroke)

        // Clamp values
        let cr = max(0, min(cornerRadius, min(r.width, r.height) / 2))
        let cl = max(0, cornerLength)
        let leg = max(0, cl - cr) // straight segment beyond the arc's tangent points

        // Top-left
        if leg > 0 {
            p.move(to: CGPoint(x: r.minX + cr + leg, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + cr, y: r.minY))
        }
        p.move(to: CGPoint(x: r.minX + cr, y: r.minY))
        p.addArc(center: CGPoint(x: r.minX + cr, y: r.minY + cr),
                 radius: cr,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(-180),
                 clockwise: true)
        if leg > 0 {
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + cr + leg))
        }

        // Top-right
        if leg > 0 {
            p.move(to: CGPoint(x: r.maxX - cr - leg, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - cr, y: r.minY))
        }
        p.move(to: CGPoint(x: r.maxX - cr, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - cr, y: r.minY + cr),
                 radius: cr,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(0),
                 clockwise: false)
        if leg > 0 {
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + cr + leg))
        }

        // Bottom-right
        if leg > 0 {
            p.move(to: CGPoint(x: r.maxX, y: r.maxY - cr - leg))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cr))
        }
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - cr))
        p.addArc(center: CGPoint(x: r.maxX - cr, y: r.maxY - cr),
                 radius: cr,
                 startAngle: .degrees(0),
                 endAngle: .degrees(90),
                 clockwise: false)
        if leg > 0 {
            p.addLine(to: CGPoint(x: r.maxX - cr - leg, y: r.maxY))
        }

        // Bottom-left
        if leg > 0 {
            p.move(to: CGPoint(x: r.minX, y: r.maxY - cr - leg))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - cr))
        }
        p.move(to: CGPoint(x: r.minX, y: r.maxY - cr))
        p.addArc(center: CGPoint(x: r.minX + cr, y: r.maxY - cr),
                 radius: cr,
                 startAngle: .degrees(180),
                 endAngle: .degrees(90),
                 clockwise: true)
        if leg > 0 {
            p.addLine(to: CGPoint(x: r.minX + cr + leg, y: r.maxY))
        }

        return p
    }
}

struct QRScannerOverlay: View {
    let boxSize: CGFloat = 260
    let radius: CGFloat = 24
    let lineWidth: CGFloat = 6

    var body: some View {
        // Corner bits
        ScannerCorners(cornerRadius: radius, cornerLength: 42, insetForStroke: lineWidth / 2)
            .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: boxSize, height: boxSize)
    }
}

#Preview {
    QRScannerOverlay()
}
