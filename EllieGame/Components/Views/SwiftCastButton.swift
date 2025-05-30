//
//  SwiftCastButton.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct SwiftCastButton: View {
    var action: (() -> Void)?
    var cancelAction: (() -> Void)?
    var title: String
    var withCountdown = false
    @State private var onCountdown = false
    @State private var currentCount = 3
    @State private var isCancel = false
    
    var body: some View {
        Button {
            if withCountdown {
                if isCancel {
                    isCancel = false
                    onCountdown = false
                    currentCount = 3
                    onCountdown = false
                    cancelAction?()
                } else {
                    onCountdown = true
                    Task {
                        repeat {
                            currentCount -= 1
                            try? await Task.sleep(nanoseconds: 1000000000)
                            if currentCount == 0 {
                                onCountdown = false
                                currentCount = 3
                                action?()
                            }
                        } while onCountdown
                    }
                }
                
            } else {
                action?()
            }
        } label: {
            if isCancel {
                Text("Cancel")
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(.red)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            } else {
                Text(onCountdown ? "Starting in \(currentCount + 1)" : title)
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
            
        }
        .onHover(perform: { hovered in
            if hovered && onCountdown {
                isCancel = true
            } else {
                isCancel = false
            }
        })
        .animation(.easeInOut, value: onCountdown)
        .animation(.easeInOut, value: isCancel)
        .buttonStyle(.plain)
        .padding()
    }
    
    
}

struct SwiftCastButton_Previews: PreviewProvider {
    static var previews: some View {
        SwiftCastButton(title: "SwiftCast")
    }
}
