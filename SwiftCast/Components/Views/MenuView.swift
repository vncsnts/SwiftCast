//
//  MenuView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/30/23.
//

import SwiftUI

struct MenuView<Content : View>: View {
    var content: () -> Content
    var title: String
    var isDisabled: Bool
    var body: some View {
        Menu {
            content()
        } label: {
            MenuButtonRow(title: title)
        }
        .padding(.horizontal)
        .frame(height: 44)
        .menuStyle(.borderlessButton)
        .background(.background)
        .cornerRadius(10)
        .padding()
        .shadow(radius: 2)
        .disabled(isDisabled)
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(content: {
            EmptyView()
        }, title: "", isDisabled: false)
    }
}
