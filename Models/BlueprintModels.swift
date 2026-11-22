//
//  BlueprintModels.swift
//  Hefesto - Receptor Holográfico de Ingeniería para iPhone 16
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

    public init(
        id: String,
        title: String,
        subtitle: String,
        norm: String,
        usdzUrl: String,
        htmlUrl: String,
        flowBtnLabel: String,
        flowStateOn: String,
        flowStateOff: String,
        stat1Label: String,
        stat1ValOn: String,
        stat1ValOff: String,
        stat2Label: String,
        stat2ValOn: String,
        stat2ValOff: String,
        phases: [String],
        parts: [BlueprintPart]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.norm = norm
        self.usdzUrl = usdzUrl
        self.htmlUrl = htmlUrl
        self.flowBtnLabel = flowBtnLabel
        self.flowStateOn = flowStateOn
        self.flowStateOff = flowStateOff
        self.stat1Label = stat1Label
        self.stat1ValOn = stat1ValOn
        self.stat1ValOff = stat1ValOff
        self.stat2Label = stat2Label
        self.stat2ValOn = stat2ValOn
        self.stat2ValOff = stat2ValOff
        self.phases = phases
        self.parts = parts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Modelo CAD"
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? "Subconjunto de Ingeniería"
        self.norm = try container.decodeIfPresent(String.self, forKey: .norm) ?? "ISO 9001 / SEC Chile"
        self.usdzUrl = try container.decodeIfPresent(String.self, forKey: .usdzUrl) ?? ""
        self.htmlUrl = try container.decodeIfPresent(String.self, forKey: .htmlUrl) ?? ""
        self.flowBtnLabel = try container.decodeIfPresent(String.self, forKey: .flowBtnLabel) ?? "Simular Flujo"
        self.flowStateOn = try container.decodeIfPresent(String.self, forKey: .flowStateOn) ?? "ESTADO: ACTIVO"
        self.flowStateOff = try container.decodeIfPresent(String.self, forKey: .flowStateOff) ?? "ESTADO: REPOSO"
        self.stat1Label = try container.decodeIfPresent(String.self, forKey: .stat1Label) ?? "ESTADO"
        self.stat1ValOn = try container.decodeIfPresent(String.self, forKey: .stat1ValOn) ?? "100%"
        self.stat1ValOff = try container.decodeIfPresent(String.self, forKey: .stat1ValOff) ?? "0%"
        self.stat2Label = try container.decodeIfPresent(String.self, forKey: .stat2Label) ?? "SERVICIO"
        self.stat2ValOn = try container.decodeIfPresent(String.self, forKey: .stat2ValOn) ?? "OPTIMO"
        self.stat2ValOff = try container.decodeIfPresent(String.self, forKey: .stat2ValOff) ?? "REPOSO"
        self.phases = try container.decodeIfPresent([String].self, forKey: .phases) ?? []
        self.parts = try container.decodeIfPresent([BlueprintPart].self, forKey: .parts) ?? []
    }
}

public struct BlueprintPart: Identifiable, Codable, Hashable {
    public let id: String
    public let key: String
    public let name: String
    public let subsystem: String
    public let material: String
    public let function: String
    public let failure: String
    public let posAssembled: [Float]
    public let posExploded: [Float]

    enum CodingKeys: String, CodingKey {
        case id, key, name, subsystem, material, function, funcKey = "func", failure
        case posAssembled = "pos_assembled"
        case posExploded = "pos_exploded"
    }

    public init(
        id: String,
        key: String,
        name: String,
        subsystem: String,
        material: String,
        function: String,
        failure: String,
        posAssembled: [Float],
        posExploded: [Float]
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.subsystem = subsystem
        self.material = material
        self.function = function
        self.failure = failure
        self.posAssembled = posAssembled
        self.posExploded = posExploded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decodeIfPresent(String.self, forKey: .key) ?? UUID().uuidString
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "PIEZA"
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? self.key
        self.subsystem = try container.decodeIfPresent(String.self, forKey: .subsystem) ?? "Subsistema Funcional"
        self.material = try container.decodeIfPresent(String.self, forKey: .material) ?? "Aleación Metálica / Polímero"
        
        let funcDirect = try container.decodeIfPresent(String.self, forKey: .function)
        let funcAlt = try container.decodeIfPresent(String.self, forKey: .funcKey)
        self.function = funcDirect ?? funcAlt ?? "Componente de precisión para operación mecánica."
        
        self.failure = try container.decodeIfPresent(String.self, forKey: .failure) ?? "Desgaste normal por fatiga mecánica o térmica."
        self.posAssembled = try container.decodeIfPresent([Float].self, forKey: .posAssembled) ?? [0.0, 0.0, 0.0]
        self.posExploded = try container.decodeIfPresent([Float].self, forKey: .posExploded) ?? [0.0, 1.0, 0.0]
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
