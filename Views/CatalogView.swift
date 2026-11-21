//
//  CatalogView.swift
//  Hefesto - Catálogo Dinámico de Modelos 3D de Odiseo
//

import SwiftUI

public struct CatalogView: View {
    @StateObject private var apiService = OdiseoAPIService.shared
    @State private var searchText: String = ""
    @State private var showSettings: Bool = false
    @State private var tempHost: String = ""

    public init() {}

    private var filteredBlueprints: [Blueprint] {
        if searchText.isEmpty {
            return apiService.blueprints
        } else {
            return apiService.blueprints.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.subtitle.localizedCaseInsensitiveContains(searchText) ||
                $0.norm.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 7/255, green: 11/255, blue: 18/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Barra de estado de conexión con Odiseo
                    connectionStatusBanner

                    // Lista de Dispositivos / Planos 3D
                    if apiService.isLoading && apiService.blueprints.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0, green: 240/255, blue: 1.0)))
                                .scaleEffect(1.3)
                            Text("Sincronizando modelos con Odiseo...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.6))
                        }
                        .frame(maxHeight: .infinity)
                    } else if let error = apiService.errorMessage, apiService.blueprints.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 38))
                                .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Button(action: {
                                Task { await apiService.fetchBlueprints() }
                            }) {
                                Text("Reintentar Conexión")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 2/255, green: 132/255, blue: 199/255))
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredBlueprints) { bp in
                                    NavigationLink(destination: BlueprintDetailView(blueprint: bp)) {
                                        BlueprintCard(blueprint: bp)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(14)
                        }
                        .refreshable {
                            await apiService.fetchBlueprints()
                        }
                    }
                }
            }
            .navigationTitle("HEFESTO // 3D HUD")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        tempHost = apiService.serverHost
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .task {
                await apiService.fetchBlueprints()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subvistas

    private var connectionStatusBanner: some View {
        HStack {
            Circle()
                .fill(apiService.isConnected ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 239/255, green: 68/255, blue: 68/255))
                .frame(width: 8, height: 8)

            Text(apiService.isConnected ? "CONECTADO A ODISEO (TAILSCALE)" : "DESCONECTADO DE ODISEO")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(Color(white: 0.75))

            Spacer()

            Text(apiService.serverHost)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 14/255, green: 22/255, blue: 38/255))
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color(red: 30/255, green: 46/255, blue: 74/255)),
            alignment: .bottom
        )
    }

    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Servidor Odiseo")) {
                    TextField("IP o Host:Puerto", text: $tempHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(footer: Text("Hefesto se conecta por Tailscale a Odiseo. Cuando pidas un aparato en Telegram, aparecerá automáticamente aquí al refrescar.")) {
                    Button("Guardar y Probar Conexión") {
                        apiService.serverHost = tempHost
                        showSettings = false
                        Task { await apiService.fetchBlueprints() }
                    }
                    .foregroundColor(Color(red: 2/255, green: 132/255, blue: 199/255))
                }
            }
            .navigationTitle("Configuración")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showSettings = false }
                }
            }
        }
    }
}

public struct BlueprintCard: View {
    public let blueprint: Blueprint

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(blueprint.norm)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0, green: 240/255, blue: 1.0).opacity(0.12))
                    .cornerRadius(4)

                Spacer()

                Text("\(blueprint.parts.count) PIEZAS 3D")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(blueprint.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(blueprint.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 11))
                    Text("Despiece y Rayos-X")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(white: 0.5))

                Spacer()

                HStack(spacing: 4) {
                    Text("Explorar")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
            }
        }
        .padding(14)
        .background(Color(red: 14/255, green: 22/255, blue: 38/255))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
        )
    }
}
