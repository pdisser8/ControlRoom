//
//  AppIcon.swift
//  ControlRoom
//
//  Created by Paul Hudson on 28/01/2021.
//  Copyright © 2021 Paul Hudson. All rights reserved.
//

import SwiftUI

struct AppIcon: View {
    let application: Application
    var iconOverride: NSImage? = nil
    let width: CGFloat

    var body: some View {
        if let icon = iconOverride ?? application.icon {
            Image(nsImage: icon)
                .resizable()
                .cornerRadius(width / 5)
                .frame(width: width, height: width)
        } else {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: width / 5)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 0.5, dash: [width / 20 + 1]))
                )
                .frame(width: width, height: width)
        }
    }
}

struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AppIcon(application: Application.default, width: 100)
    }
}
