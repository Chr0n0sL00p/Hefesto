//
//  BlueprintModels.swift
//  StarkHUD - Receptor Holográfico de Ingeniería para iPhone 16
//

import Foundation
import SceneKit

public struct Blueprint: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let norm: String
    public let usdzUrl: String
    public let htmlUrl: String
    public let flowBtnLabel: String
    public let flowStateOn: String
    public let flowStateOff: String
    public let stat1Label: String
    public let stat1ValOn: String
    public let stat1ValOff: String
    public let stat2Label: String
    public let stat2ValOn: String
    public let stat2ValOff: String
    public let phases: [String]
    public let parts: [BlueprintPart]

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, norm
        case usdzUrl = "usdz_url"
        case htmlUrl = "html_url"
        case flowBtnLabel = "flow_btn_label"
        case flowStateOn = "flow_state_on"
        case flowStateOff = "flow_state_off"
        case stat1Label = "stat1_label"
        case stat1ValOn = "stat1_val_on"
        case stat1ValOff = "stat1_val_off"
        case stat2Label = "stat2_label"
        case stat2ValOn = "stat2_val_on"
        case stat2ValOff = "stat2_val_off"
        case phases, parts
    }
}

public struct BlueprintPart: Identifiable, Codable, Hashable {
    public let id: String        // "PIEZA 01"
    public let key: String       // "Serpentin_Cobre"
    public let name: String      // "Serpentín de Cobre & Aletas"
    public let subsystem: String // "Intercambiador de Calor Primario"
    public let material: String  // "Cobre electrolítico Cu-DHP..."
    public let function: String  // "Transfiere instantáneamente..."
    public let failure: String   // "Incrustación de sarro..."
    public let posAssembled: [Float] // [x, y, z]
    public let posExploded: [Float]  // [x, y, z]

    enum CodingKeys: String, CodingKey {
        case id, key, name, subsystem, material, function, failure
        case posAssembled = "pos_assembled"
        case posExploded = "pos_exploded"
    }

    public var assembledVector: SCNVector3 {
        guard posAssembled.count >= 3 else { return SCNVector3Zero }
        return SCNVector3(posAssembled[0], posAssembled[1], posAssembled[2])
    }

    public var explodedVector: SCNVector3 {
        guard posExploded.count >= 3 else { return SCNVector3Zero }
        return SCNVector3(posExploded[0], posExploded[1], posExploded[2])
    }
}
