//
//  ImageView.swift
//  SwipeCleaner
//
//  Created by Yılmaz Edis on 14.03.2026.
//

import SwiftUI
import AppKit

struct ImageView: View {
    let fileURL: URL

    var body: some View {
        if let nsImage = NSImage(contentsOf: fileURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 900, maxHeight: 700) // limit size
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            Text("Unable to load image")
                .foregroundColor(.secondary)
        }
    }
}
