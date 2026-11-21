//
//  OdiseoAPIService.swift
//  StarkHUD - Cliente de Red Tailscale & Gestor de Modelos 3D
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

    private var cancellables = Set<AnyCancellable>()

    public init() {
        let saved = UserDefaults.standard.string(forKey: "odiseo_server_host")
        self.serverHost = saved?.isEmpty == false ? saved! : "100.117.169.38:4550"
    }

    public var baseUrl: URL {
        let clean = serverHost.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        return URL(string: "http://\(clean)")!
    }

    /// Carga el catálogo dinámico de planos 3D desde Odiseo
    @MainActor
    public func fetchBlueprints() async {
        isLoading = true
        errorMessage = nil

        let url = baseUrl.appendingPathComponent("api/blueprints")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode([Blueprint].self, from: data)
            self.blueprints = decoded
            self.isConnected = true
            self.isLoading = false
        } catch {
            self.isConnected = false
            self.errorMessage = "No se pudo conectar con Odiseo (\(serverHost)). Verifica que Tailscale esté activo."
            self.isLoading = false
        }
    }

    /// Descarga y almacena en caché local el archivo USDZ nativo
    public func getLocalUsdzUrl(for blueprint: Blueprint) async throws -> URL {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let localFile = cacheDir.appendingPathComponent("\(blueprint.id).usdz")

        // Si ya existe en caché, devolverlo directamente
        if fileManager.fileExists(atPath: localFile.path) {
            return localFile
        }

        // Descargar desde Odiseo
        guard let remoteUrl = URL(string: blueprint.usdzUrl) else {
            throw URLError(.badURL)
        }

        let (tempUrl, _) = try await URLSession.shared.download(from: remoteUrl)
        if fileManager.fileExists(atPath: localFile.path) {
            try fileManager.removeItem(at: localFile)
        }
        try fileManager.moveItem(at: tempUrl, to: localFile)
        return localFile
    }
}
