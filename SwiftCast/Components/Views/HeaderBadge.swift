//
//  HeaderBadge.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct HeaderBadge: View {
    @Environment(\.appTheme) private var t
    var title: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(t.font.pillLabel)
                .foregroundColor(t.color.foreground.secondary)
        }
        .padding(.horizontal, t.padding.small)
        .padding(.vertical, t.padding.xs)
        .glassCapsule()
    }
}

struct HeaderBadge_Previews: PreviewProvider {
    static var previews: some View {
        HeaderBadge(title: "BETA")
    }
}
