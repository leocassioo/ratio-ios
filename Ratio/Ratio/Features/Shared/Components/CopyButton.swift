//
//  CopyButton.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import UIKit

struct CopyButton: View {
    let textToCopy: String
    @State private var isCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = textToCopy
            withAnimation {
                isCopied = true
            }
            
            // Revert back after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isCopied = false
                }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(isCopied ? .green : .blue)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        Text("Code to copy")
        Spacer()
        CopyButton(textToCopy: "Code to copy")
    }
    .padding()
}
