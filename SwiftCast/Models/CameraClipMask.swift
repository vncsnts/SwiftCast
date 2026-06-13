//
//  CameraClipMask.swift
//  SwiftCast
//

import SwiftUI

enum CameraClipMask: String, CaseIterable, Identifiable {
    case none = "None"
    case circle = "Circle"
    case roundedRectangle = "Rounded"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case capsule = "Capsule"
    case squircle = "Squircle"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .none: return "square.dashed"
        case .circle: return "circle.fill"
        case .roundedRectangle: return "rectangle.roundedtop.fill"
        case .rectangle: return "rectangle.fill"
        case .ellipse: return "oval.fill"
        case .capsule: return "capsule.fill"
        case .squircle: return "app.fill"
        }
    }
}

struct CameraClipMaskShape: Shape {
    let mode: CameraClipMask

    func path(in rect: CGRect) -> Path {
        let short = min(rect.width, rect.height)
        switch mode {
        case .none:
            return Path(rect)
        case .rectangle:
            return Path(rect)
        case .roundedRectangle:
            return Path(roundedRect: rect, cornerRadius: short * 0.18)
        case .circle:
            return Path(ellipseIn: CGRect(
                x: rect.midX - short / 2,
                y: rect.midY - short / 2,
                width: short,
                height: short
            ))
        case .ellipse:
            return Path(ellipseIn: rect)
        case .capsule:
            return Capsule().path(in: rect)
        case .squircle:
            return Path(roundedRect: rect, cornerRadius: short * 0.38)
        }
    }
}
