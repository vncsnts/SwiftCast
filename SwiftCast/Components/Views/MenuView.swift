//
//  MenuView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/30/23.
//

import SwiftUI

/// A System Settings–style row: leading symbol and label, with a native
/// pop-up button on the trailing edge showing the current selection.
/// Designed to be stacked inside a grouped glass card.
struct MenuView<Content : View>: View {
    @Environment(\.appTheme) private var t
    var content: () -> Content
    var label: String
    var systemImage: String
    var value: String
    var isDisabled: Bool

    var body: some View {
        HStack(spacing: t.spacing.medium) {
            Image(systemName: systemImage)
                .font(t.font.body)
                .foregroundColor(t.color.foreground.accent)
                .frame(width: 20)
            Text(label)
                .font(t.font.body)
                .foregroundColor(t.color.foreground.default)
            Spacer(minLength: t.spacing.small)
            Menu {
                content()
            } label: {
                Text(value)
                    .font(t.font.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 190, alignment: .trailing)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
        }
        .padding(.horizontal, t.padding.medium)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(content: {
            EmptyView()
        }, label: "Camera", systemImage: "video.fill", value: "FaceTime HD Camera", isDisabled: false)
    }
}
