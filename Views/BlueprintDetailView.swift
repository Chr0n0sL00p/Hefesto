//
//  BlueprintDetailView.swift
//  StarkHUD - Vista Principal del Plano 3D Interactivo
//

import SwiftUI

public struct BlueprintDetailView: View {
    public let blueprint: Blueprint

    @State private var selectedPart: BlueprintPart? = nil
    @State private var isHologram: Bool = false
    @State private var isExploded: Bool = false
    @State private var isFlowActive: Bool = false
    @State private var cameraResetTrigger: Int = 0

    @State private var showAR: Bool = false
    @State private var localArUrl: URL? = nil
    @State private var isPreparingAR: Bool = false

    public init(blueprint: Blueprint) {
        self.blueprint = blueprint
    }

    public var body: some View {
        ZStack {
            // Fondo oscuro con rejilla
            Color(red: 7/255, green: 11/255, blue: 18/255)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Barra de Controles Superiores
                controlsBar

                // Selector de Partes (Pills horizontales)
                pillsBar

                // Viewport 3D Principal con HUD
                ZStack(alignment: .topLeading) {
                    SceneKitViewer(
                        blueprint: blueprint,
                        selectedPart: $selectedPart,
                        isHologram: isHologram,
                        isExploded: isExploded,
                        isFlowActive: isFlowActive,
                        cameraResetTrigger: cameraResetTrigger
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
                    )

                    // HUD Superior Flotante
                    hudTopOverlay

                    // HUD Inferior (Centrar Cámara)
                    VStack {
                        Spacer()
                        HStack {
                            Text("Arrastra para rotar 360° · Pellizca para zoom · Toca una pieza")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.55))

                            Spacer()

                            Button(action: { cameraResetTrigger += 1 }) {
                                Text("Centrar Cámara")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(red: 26/255, green: 38/255, blue: 61/255).opacity(0.9))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Ficha Técnica / Inspector
                if let part = selectedPart {
                    ScrollView {
                        InspectorCardView(part: part, phases: blueprint.phases) {
                            withAnimation(.spring()) {
                                self.selectedPart = nil
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxHeight: 280)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAR) {
            if let arUrl = localArUrl {
                ARQuickLookPresenter(fileUrl: arUrl)
            }
        }
        .onAppear {
            if selectedPart == nil {
                selectedPart = blueprint.parts.first
            }
        }
    }

    // MARK: - Subvistas

    private var controlsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Estilo Holográfico vs Real
                Button(action: {
                    isHologram.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: isHologram ? "sparkles" : "cube.fill")
                        Text(isHologram ? "Vista Holográfica" : "Materiales Reales")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isHologram ? Color(red: 2/255, green: 132/255, blue: 199/255) : Color(red: 26/255, green: 38/255, blue: 61/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHologram ? Color(red: 0, green: 240/255, blue: 1.0) : Color(white: 0.2), lineWidth: 1)
                    )
                }

                // Despiece Explotado
                Button(action: {
                    isExploded.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: isExploded ? "arrow.up.left.and.down.right.magnifyingglass" : "square.split.diagonal.2x2")
                        Text(isExploded ? "Despiece: Explotado" : "Despiece: Normal")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isExploded ? Color(red: 2/255, green: 132/255, blue: 199/255) : Color(red: 26/255, green: 38/255, blue: 61/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isExploded ? Color(red: 0, green: 240/255, blue: 1.0) : Color(white: 0.2), lineWidth: 1)
                    )
                }

                // Simular Flujo
                Button(action: {
                    isFlowActive.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: isFlowActive ? "bolt.fill" : "bolt")
                        Text(isFlowActive ? "\(blueprint.flowBtnLabel): Activo" : "\(blueprint.flowBtnLabel): Reposo")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isFlowActive ? Color(red: 0, green: 240/255, blue: 1.0).opacity(0.3) : Color(red: 26/255, green: 38/255, blue: 61/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFlowActive ? Color(red: 0, green: 240/255, blue: 1.0) : Color(white: 0.2), lineWidth: 1)
                    )
                }

                // Botón Realidad Aumentada (AR)
                Button(action: {
                    prepareAndOpenAR()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arkit")
                        Text(isPreparingAR ? "Cargando..." : "Modo AR")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 16/255, green: 185/255, blue: 129/255), lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var pillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(blueprint.parts) { part in
                    let isSelected = (selectedPart?.key == part.key)
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            self.selectedPart = part
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }) {
                        Text(part.name)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : Color(white: 0.65))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color(red: 0, green: 240/255, blue: 1.0).opacity(0.18) : Color(red: 14/255, green: 22/255, blue: 38/255))
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(isSelected ? Color(red: 0, green: 240/255, blue: 1.0) : Color(white: 0.15), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var hudTopOverlay: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isFlowActive ? Color(red: 0, green: 240/255, blue: 1.0) : Color(red: 16/255, green: 185/255, blue: 129/255))
                    .frame(width: 8, height: 8)
                Text(isFlowActive ? blueprint.flowStateOn : blueprint.flowStateOff)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.85))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(red: 14/255, green: 22/255, blue: 38/255).opacity(0.85))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
            )

            Spacer()

            HStack(spacing: 4) {
                Text(blueprint.stat1Label + ":")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.6))
                Text(isFlowActive ? blueprint.stat1ValOn : blueprint.stat1ValOff)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Text("|")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.4))
                Text(blueprint.stat2Label + ":")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.6))
                Text(isFlowActive ? blueprint.stat2ValOn : blueprint.stat2ValOff)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(red: 14/255, green: 22/255, blue: 38/255).opacity(0.85))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
            )
        }
        .padding(12)
    }

    private func prepareAndOpenAR() {
        isPreparingAR = true
        Task {
            do {
                let localUrl = try await OdiseoAPIService.shared.getLocalUsdzUrl(for: blueprint)
                await MainActor.run {
                    self.localArUrl = localUrl
                    self.isPreparingAR = false
                    self.showAR = true
                }
            } catch {
                await MainActor.run {
                    self.isPreparingAR = false
                }
                print("Error descargando USDZ para AR: \(error)")
            }
        }
    }
}
