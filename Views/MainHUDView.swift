//
//  MainHUDView.swift
//  Hefesto - Receptor Holográfico de Ingeniería 3D para iPhone 16
//

import SwiftUI
import SceneKit

public struct MainHUDView: View {
    @StateObject private var apiService = OdiseoAPIService.shared

    @State private var selectedBlueprintIndex: Int = 0
    @State private var selectedPart: BlueprintPart? = nil
    @State private var isHologram: Bool = false
    @State private var isExploded: Bool = false
    @State private var isXRayActive: Bool = false
    @State private var cameraResetTrigger: Int = 0

    @State private var isFunctionsExpanded: Bool = false
    @State private var isModelPickerPresented: Bool = false
    @State private var infoCardTab: Int = 0
    @State private var showConnectionToast: Bool = false

    public init() {}

    private var activeBlueprint: Blueprint? {
        if apiService.blueprints.indices.contains(selectedBlueprintIndex) {
            return apiService.blueprints[selectedBlueprintIndex]
        }
        return apiService.blueprints.first
    }

    public var body: some View {
        ZStack {
            // Fondo oscuro titanio espacial
            Color(red: 5/255, green: 8/255, blue: 14/255)
                .ignoresSafeArea()

            // 1. Visor 3D en pantalla completa edge-to-edge
            if let blueprint = activeBlueprint {
                SceneKitViewer(
                    blueprint: blueprint,
                    selectedPart: $selectedPart,
                    isHologram: isHologram,
                    isExploded: isExploded,
                    isXRayActive: isXRayActive,
                    cameraResetTrigger: cameraResetTrigger
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(red: 0, green: 240/255, blue: 1.0))
                    Text("Cargando modelo 3D...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }
            }

            // 2. Capa de Controles Flotantes tipo HUD
            VStack(spacing: 0) {
                // Barra superior: Indicador discreto y ficha técnica flotante
                topHUDBar

                Spacer()

                // Barra inferior: Botón "Modelos 3D"
                bottomHUDBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // 3. Barra Vertical Flotante Derecha "Funciones"
            HStack {
                Spacer()
                functionsDock
                    .padding(.trailing, 12)
            }

            // 4. Toast discreto de conexión con Odiseo
            if showConnectionToast {
                VStack {
                    connectionToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 50)
            }
        }
        .sheet(isPresented: $isModelPickerPresented) {
            modelPickerSheet
        }
        .task {
            await apiService.fetchBlueprints()
        }
    }

    // MARK: - Barra Superior & Ficha Deslizable
    @ViewBuilder
    private var topHUDBar: some View {
        VStack(spacing: 10) {
            // Fila de estado discreto
            HStack {
                // Indicador discreto de conexión
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showConnectionToast.toggle()
                    }
                    if showConnectionToast {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { showConnectionToast = false }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(apiService.isConnected ? Color(red: 34/255, green: 197/255, blue: 94/255) : Color(red: 239/255, green: 68/255, blue: 68/255))
                            .frame(width: 8, height: 8)
                            .shadow(color: (apiService.isConnected ? Color.green : Color.red).opacity(0.8), radius: 4)

                        if let bp = activeBlueprint {
                            Text(bp.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 11/255, green: 17/255, blue: 28/255).opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                }

                Spacer()

                // Si hay pieza seleccionada, indicador rápido
                if selectedPart != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedPart = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                }
            }

            // Ficha Técnica Flotante Deslizable (Solo si hay pieza seleccionada)
            if let part = selectedPart, let blueprint = activeBlueprint {
                floatingInfoCard(part: part, blueprint: blueprint)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Tarjeta de Información Deslizable Horizontalmente
    private func floatingInfoCard(part: BlueprintPart, blueprint: Blueprint) -> some View {
        VStack(spacing: 8) {
            // Cabecera compacta con identificador
            HStack(alignment: .center) {
                Text(part.id)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0, green: 240/255, blue: 1.0).opacity(0.15))
                    .cornerRadius(4)

                Text(part.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Indicador de deslizamiento
                HStack(spacing: 3) {
                    ForEach(0..<4) { idx in
                        Circle()
                            .fill(infoCardTab == idx ? Color(red: 0, green: 240/255, blue: 1.0) : Color.white.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            // Paginador horizontal deslizable
            TabView(selection: $infoCardTab) {
                // Pag 1: Función & Qué es
                infoCardPage(
                    tag: 0,
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: Color(red: 0, green: 240/255, blue: 1.0),
                    title: "FUNCIÓN MECÁNICA & OPERACIÓN",
                    text: part.function
                )

                // Pag 2: Material & Fabricación
                infoCardPage(
                    tag: 1,
                    icon: "cube.fill",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    title: "MATERIAL & FABRICACIÓN INDUSTRIAL",
                    text: part.material
                )

                // Pag 3: Diagnóstico & Fallas Comunes
                infoCardPage(
                    tag: 2,
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Color(red: 239/255, green: 68/255, blue: 68/255),
                    title: "DIAGNÓSTICO & FALLA FRECUENTE",
                    text: part.failure
                )

                // Pag 4: Ciclo Operativo
                infoCardPhasesPage(tag: 3, blueprint: blueprint)
            }
            .frame(height: 105)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .padding(12)
        .background(
            Color(red: 11/255, green: 17/255, blue: 28/255).opacity(0.92)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0, green: 240/255, blue: 1.0).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 6)
    }

    private func infoCardPage(tag: Int, icon: String, iconColor: Color, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(iconColor)
                    .tracking(0.5)
                Spacer()
                Text("Desliza →")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .tag(tag)
    }

    private func infoCardPhasesPage(tag: Int, blueprint: Blueprint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 168/255, green: 85/255, blue: 247/255))
                Text("CICLO OPERATIVO EN 4 FASES")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Color(red: 168/255, green: 85/255, blue: 247/255))
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blueprint.phases.enumerated()), id: \.offset) { index, phase in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 14, height: 14)
                                .background(Color(red: 168/255, green: 85/255, blue: 247/255))
                                .clipShape(Circle())

                            Text(phase)
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.9))
                        }
                    }
                }
            }
        }
        .tag(tag)
    }

    // MARK: - Barra Inferior & Botón Modelos 3D
    private var bottomHUDBar: some View {
        HStack(alignment: .bottom) {
            // Botón "Modelos 3D" (inferior izquierdo como en el mockup)
            Button(action: {
                let haptic = UIImpactFeedbackGenerator(style: .medium)
                haptic.impactOccurred()
                isModelPickerPresented = true
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 245/255, green: 158/255, blue: 11/255), Color(red: 217/255, green: 119/255, blue: 6/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)

                        Image(systemName: "cube.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Modelos 3D")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(activeBlueprint?.title ?? "Alternar")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.trailing, 4)
                }
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background(Color(red: 11/255, green: 17/255, blue: 28/255).opacity(0.85))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
            }

            Spacer()
        }
    }

    // MARK: - Dock Vertical Derecho "Funciones"
    private var functionsDock: some View {
        VStack(spacing: 8) {
            if !isFunctionsExpanded {
                // Estado Colapsado: Barra delgada y transparente
                Button(action: {
                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                    haptic.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isFunctionsExpanded = true
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))

                        // Texto vertical "Funciones"
                        Text("F\nU\nN\nC\nI\nO\nN\nE\nS")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(Color.white.opacity(0.75))
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 14)
                    .frame(width: 32)
                    .background(Color(red: 11/255, green: 17/255, blue: 28/255).opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 6)
                }
            } else {
                // Estado Expandido: Botones de Funciones Rápidas
                VStack(spacing: 12) {
                    // Botón para colapsar
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFunctionsExpanded = false
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 38, height: 26)
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // 1. Despiece 3D
                    dockButton(
                        icon: isExploded ? "square.3.layers.3d.down.backward" : "square.3.layers.3d.down.right",
                        label: "Despiece",
                        isActive: isExploded,
                        activeColor: Color(red: 249/255, green: 115/255, blue: 22/255)
                    ) {
                        isExploded.toggle()
                    }

                    // 2. Rayos X / Aislamiento
                    dockButton(
                        icon: isXRayActive ? "viewfinder.circle.fill" : "viewfinder.circle",
                        label: "Rayos X",
                        isActive: isXRayActive,
                        activeColor: Color(red: 0, green: 240/255, blue: 1.0)
                    ) {
                        isXRayActive.toggle()
                    }

                    // 3. Materiales Reales vs Holograma
                    dockButton(
                        icon: isHologram ? "sparkles" : "cube.fill",
                        label: isHologram ? "Holograma" : "Real PBR",
                        isActive: isHologram,
                        activeColor: Color.cyan
                    ) {
                        isHologram.toggle()
                    }

                    // 4. Centrar Cámara
                    dockButton(
                        icon: "scope",
                        label: "Centrar",
                        isActive: false,
                        activeColor: Color.white
                    ) {
                        cameraResetTrigger += 1
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .frame(width: 56)
                .background(Color(red: 11/255, green: 17/255, blue: 28/255).opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 10)
            }
        }
    }

    private func dockButton(icon: String, label: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isActive ? activeColor : Color.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(isActive ? activeColor.opacity(0.2) : Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(isActive ? activeColor : Color.clear, lineWidth: 1)
                    )

                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isActive ? activeColor : Color.white.opacity(0.7))
            }
        }
    }

    // MARK: - Toast Discreto de Conexión
    private var connectionToast: some View {
        HStack(spacing: 8) {
            Image(systemName: apiService.isConnected ? "checkmark.circle.fill" : "wifi.slash")
                .foregroundColor(apiService.isConnected ? .green : .red)
            Text(apiService.isConnected ? "Odiseo Conectado (100.117.169.38)" : "Sin conexión con Odiseo")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(red: 15/255, green: 22/255, blue: 36/255).opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
    }

    // MARK: - Modal de Selección de Modelos 3D
    private var modelPickerSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 7/255, green: 11/255, blue: 18/255)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(apiService.blueprints.enumerated()), id: \.element.id) { index, bp in
                                Button(action: {
                                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                                    haptic.impactOccurred()
                                    selectedBlueprintIndex = index
                                    selectedPart = nil
                                    isModelPickerPresented = false
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedBlueprintIndex == index ? Color(red: 0, green: 240/255, blue: 1.0) : Color.white.opacity(0.08))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "cube.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(selectedBlueprintIndex == index ? .black : .white)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(bp.title)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)

                                            Text(bp.norm)
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))

                                            Text("\(bp.parts.count) Piezas CAD")
                                                .font(.system(size: 10))
                                                .foregroundColor(Color.white.opacity(0.6))
                                        }

                                        Spacer()

                                        if selectedBlueprintIndex == index {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(12)
                                    .background(selectedBlueprintIndex == index ? Color(red: 0, green: 240/255, blue: 1.0).opacity(0.12) : Color(red: 15/255, green: 22/255, blue: 36/255))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedBlueprintIndex == index ? Color(red: 0, green: 240/255, blue: 1.0) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(16)
                    }

                    // Botón de sincronización con Odiseo
                    Button(action: {
                        Task {
                            await apiService.fetchBlueprints()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if apiService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Sincronizar nuevos modelos de Odiseo")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 2/255, green: 132/255, blue: 199/255))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Modelos 3D Disponibles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        isModelPickerPresented = false
                    }
                    .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                }
            }
        }
    }
}
