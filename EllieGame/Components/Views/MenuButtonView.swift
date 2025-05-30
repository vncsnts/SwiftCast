//
//  MenuButtonView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import Foundation
import SwiftUI

struct MenuButtonRow: View {
    var title: String
    var body: some View {
        HStack
        {
            Text(title)
        }
    }
}
