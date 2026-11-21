//
//  HefestoApp.swift
//  Hefesto - Receptor Holográfico de Ingeniería para iPhone 16
//

import SwiftUI

@main
public struct HefestoApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            CatalogView()
                .preferredColorScheme(.dark)
        }
    }
}
