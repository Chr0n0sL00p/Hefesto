//
//  OdiseoAPIService.swift
//  Hefesto - Cliente de Red Tailscale & Gestor de Modelos 3D
//

import Foundation
import Combine

public class OdiseoAPIService: ObservableObject {
    public static let shared = OdiseoAPIService()

    @Published public var serverHost: String {
        didSet {
            UserDefaults.standard.set(serverHost, forKey: "odiseo_server_host")
        }
    }

    @Published public var blueprints: [Blueprint] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var isConnected: Bool = false

    public init() {
        let saved = UserDefaults.standard.string(forKey: "odiseo_server_host")
        self.serverHost = saved?.isEmpty == false ? saved! : "100.117.169.38:4550"

        // Modelos base cacheados para arranque en frío inmediato
        self.blueprints = [
            Blueprint(
                id: "calefont",
                title: "Calefont Ionizado Tiro Natural (10L)",
                subtitle: "Intercambiador de Calor a Gas Licuado / Natural",
                norm: "Norma NCh 1932 · SEC Chile · Junkers/Splendid Type",
                usdzUrl: "http://100.117.169.38:4550/blueprint/calefont.usdz",
                htmlUrl: "http://100.117.169.38:4550/blueprint/calefont",
                flowBtnLabel: "Flujo de Agua",
                flowStateOn: "EN SERVICIO (LLAMAS ACTIVAS)",
                flowStateOff: "REPOSO (CANILLA CERRADA)",
                stat1Label: "CAUDAL",
                stat1ValOn: "9.5 L/min",
                stat1ValOff: "0.0 L/min",
                stat2Label: "TEMPERATURA",
                stat2ValOn: "43.8°C",
                stat2ValOff: "18.0°C",
                phases: [
                    "Apertura de llave: Caudal genera caída de presión diferencial en Venturi.",
                    "Membrana se deforma y empuja vástago de latón hacia válvula de gas.",
                    "Microswitch activa módulo 3V: dispara chispa de 12kV y abre solenoide.",
                    "Sensor de ionización valida llama viva y mantiene servicio continuo."
                ],
                parts: [
                    BlueprintPart(id: "PIEZA 01", key: "Serpentin_Cobre", name: "Serpentín de Cobre & Aletas", subsystem: "Intercambiador de Calor Primario", material: "Cobre electrolítico Cu-DHP (~99.9% pureza).", function: "Transfiere instantáneamente la energía calorífica del quemador hacia el caudal de agua.", failure: "Incrustación de Sarro: reduce el caudal y sobrecalienta el cobre.", posAssembled: [0.0, 1.25, 0.0], posExploded: [0.0, 2.6, 0.0]),
                    BlueprintPart(id: "PIEZA 02", key: "Quemador_Atmosferico", name: "Quemador Multi-Rampa", subsystem: "Cámara de Combustión Atmosférica", material: "Inyectores de latón maquinado y acero inoxidable AISI 304.", function: "Genera cortina de llamas cortas y azuladas a ~1.200°C.", failure: "Llama Amarilla y Hollín Negro por toberas sucias.", posAssembled: [0.0, 0.1, 0.0], posExploded: [0.0, 0.1, 0.0]),
                    BlueprintPart(id: "PIEZA 03", key: "Electrodos_Ignicion", name: "Chispero & Sensor de Ionización", subsystem: "Ignición Electrónica", material: "Varilla de aleación Kanthal en aislador cerámico.", function: "Genera arco de 12.000V para encendido y detecta plasma de llama.", failure: "Prende y se apaga a los 3 segundos por sensor sucio.", posAssembled: [0.35, 0.45, 0.0], posExploded: [1.8, 0.45, 0.0])
                ]
            )
        ]
    }

    public var baseUrl: URL {
        let clean = serverHost.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        return URL(string: "http://\(clean)")!
    }

    /// Carga el catálogo dinámico de planos 3D desde Odiseo
    @MainActor
    public func fetchBlueprints(clearCache: Bool = false) async {
        isLoading = true
        errorMessage = nil

        if clearCache {
            let fileManager = FileManager.default
            let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            if let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "usdz" {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        let url = baseUrl.appendingPathComponent("api/blueprints")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode([Blueprint].self, from: data)
            if !decoded.isEmpty {
                self.blueprints = decoded
            }
            self.isConnected = true
            self.isLoading = false
        } catch {
            self.isConnected = false
            self.errorMessage = "Odiseo no alcanzable (\(serverHost)). Usando modelos locales en caché."
            self.isLoading = false
        }
    }

    /// Descarga y almacena en caché local el archivo USDZ nativo
    public func getLocalUsdzUrl(for blueprint: Blueprint, forceRefresh: Bool = false) async throws -> URL {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let localFile = cacheDir.appendingPathComponent("\(blueprint.id).usdz")

        // Si se pide refresco forzado o si el archivo local es menor a 40KB (placeholder viejo de 13KB), eliminarlo
        if fileManager.fileExists(atPath: localFile.path) {
            if forceRefresh {
                try? fileManager.removeItem(at: localFile)
            } else if let attrs = try? fileManager.attributesOfItem(atPath: localFile.path),
                      let size = attrs[.size] as? Int64, size < 40_000 {
                // Eliminar archivo placeholder viejo para forzar descarga de modelo real
                try? fileManager.removeItem(at: localFile)
            } else {
                return localFile
            }
        }

        // Descargar desde Odiseo
        guard let remoteUrl = URL(string: blueprint.usdzUrl) else {
            throw URLError(.badURL)
        }

        let (tempUrl, response) = try await URLSession.shared.download(from: remoteUrl)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            try? fileManager.removeItem(at: tempUrl)
            throw URLError(.badServerResponse)
        }

        if let attrs = try? fileManager.attributesOfItem(atPath: tempUrl.path),
           let size = attrs[.size] as? Int64, size < 5_000 {
            try? fileManager.removeItem(at: tempUrl)
            throw URLError(.cannotParseResponse)
        }

        if fileManager.fileExists(atPath: localFile.path) {
            try? fileManager.removeItem(at: localFile)
        }
        try fileManager.moveItem(at: tempUrl, to: localFile)
        return localFile
    }
}
