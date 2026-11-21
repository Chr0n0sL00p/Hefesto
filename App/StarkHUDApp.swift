//
//  StarkHUDApp.swift
//  StarkHUD - Receptor Holográfico de Ingeniería para iPhone 16
//

import SwiftUI

@main
public struct StarkHUDApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            CatalogView()
                .preferredColorScheme(.dark)
        }
    }
}
