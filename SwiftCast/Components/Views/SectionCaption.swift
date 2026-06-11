//
//  SectionCaption.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import SwiftUI

/// Uppercase grouped-section header, like System Settings.
struct SectionCaption: View {
    @Environment(\.appTheme) private var t
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(t.font.caption)
            .kerning(0.6)
            .foregroundColor(t.color.foreground.secondary)
    }
}

struct SectionCaption_Previews: PreviewProvider {
    static var previews: some View {
        SectionCaption(title: "Sources")
    }
}
