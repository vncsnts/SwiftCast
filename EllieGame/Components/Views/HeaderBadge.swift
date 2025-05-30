//
//  HeaderBadge.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct HeaderBadge: View {
    var title: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.leading, 9)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.1))
        .cornerRadius(4)
    }
}

struct HeaderBadge_Previews: PreviewProvider {
    static var previews: some View {
        HeaderBadge(title: "BETA")
    }
}
