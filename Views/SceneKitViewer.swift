//
//  SceneKitViewer.swift
//  Hefesto - Visor 3D Metal / SceneKit con Despiece, Rayos-X y Simulación de Flujo / Encendido
//

import SwiftUI
import SceneKit
import UIKit

public struct SceneKitViewer: UIViewRepresentable {
    public let blueprint: Blueprint
    @Binding public var selectedPart: BlueprintPart?
    public let isHologram: Bool
    public let isExploded: Bool
    public let isXRayActive: Bool
    public let isSimulating: Bool
    public let cameraResetTrigger: Int

    public init(
        blueprint: Blueprint,
        selectedPart: Binding<BlueprintPart?>,
        isHologram: Bool,
        isExploded: Bool,
        isXRayActive: Bool,
        isSimulating: Bool,
        cameraResetTrigger: Int
    ) {
        self.blueprint = blueprint
        self._selectedPart = selectedPart
        self.isHologram = isHologram
        self.isExploded = isExploded
        self.isXRayActive = isXRayActive
        self.isSimulating = isSimulating
        self.cameraResetTrigger = cameraResetTrigger
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 5/255, green: 8/255, blue: 14/255, alpha: 1.0)
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false

        let scene = SCNScene()
        scnView.scene = scene

        // Cámara principal optimizada
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.05
        cameraNode.camera?.zFar = 1000
        cameraNode.position = SCNVector3(0, 0.4, 8.5)
        cameraNode.name = "MainCamera"
        scene.rootNode.addChildNode(cameraNode)

        // Iluminación de estudio PBR multicapa
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.65, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.color = UIColor.white
        dirLight.light?.intensity = 2200
        dirLight.position = SCNVector3(5, 10, 8)
        dirLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(dirLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1.0)
        fillLight.light?.intensity = 900
        fillLight.position = SCNVector3(-6, -4, -4)
        scene.rootNode.addChildNode(fillLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        rimLight.light?.intensity = 600
        rimLight.position = SCNVector3(0, -6, -8)
        scene.rootNode.addChildNode(rimLight)

        // Gestor de toques para selección de partes y deselección
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        context.coordinator.scnView = scnView

        // Cargar modelo USDZ nativo
        context.coordinator.loadModel()

        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.currentBlueprintId != blueprint.id {
            context.coordinator.currentBlueprintId = blueprint.id
            context.coordinator.loadModel()
        }

        context.coordinator.updateExplosion(isExploded: isExploded)
        context.coordinator.updateHighlight(selectedPart: selectedPart, isHologram: isHologram, isXRayActive: isXRayActive)
        context.coordinator.updateSimulation(isSimulating: isSimulating)

        if context.coordinator.lastResetTrigger != cameraResetTrigger {
            context.coordinator.lastResetTrigger = cameraResetTrigger
            context.coordinator.resetCamera()
        }
    }

    public class Coordinator: NSObject {
        var parent: SceneKitViewer
        weak var scnView: SCNView?
        var modelRootNode: SCNNode?
        var partNodes: [String: SCNNode] = [:]
        var originalTransforms: [String: SCNVector3] = [:]
        var lastResetTrigger: Int = 0
        var currentBlueprintId: String = ""
        var isCurrentlySimulating: Bool = false

        init(_ parent: SceneKitViewer) {
            self.parent = parent
            self.currentBlueprintId = parent.blueprint.id
        }

        func loadModel() {
            modelRootNode?.removeFromParentNode()
            partNodes.removeAll()
            originalTransforms.removeAll()
            isCurrentlySimulating = false

            Task { @MainActor in
                do {
                    let localUrl = try await OdiseoAPIService.shared.getLocalUsdzUrl(for: parent.blueprint)
                    let loadedScene = try SCNScene(url: localUrl, options: nil)

                    let root = SCNNode()
                    root.name = "ModelRoot"

                    for child in loadedScene.rootNode.childNodes {
                        root.addChildNode(child)
                    }

                    // 1. Centrar pivote y normalizar escala de cualquier modelo USDZ importado
                    let (minVec, maxVec) = root.boundingBox
                    let dx = maxVec.x - minVec.x
                    let dy = maxVec.y - minVec.y
                    let dz = maxVec.z - minVec.z
                    let maxDim = max(dx, max(dy, dz))

                    if maxDim > 0.001 {
                        let centerX = (minVec.x + maxVec.x) / 2.0
                        let centerY = (minVec.y + maxVec.y) / 2.0
                        let centerZ = (minVec.z + maxVec.z) / 2.0

                        // Centrar pivote en el centro real de la masa del objeto
                        root.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

                        // Escalar para que quepa en un cubo visible de ~5.0 unidades
                        let targetSize: Float = 5.0
                        let scaleFactor = targetSize / maxDim
                        root.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
                    }

                    self.scnView?.scene?.rootNode.addChildNode(root)
                    self.modelRootNode = root

                    // 2. Mapear nodos del modelo con las partes del plano y guardar sus coordenadas reales
                    self.mapNodes(node: root)

                    // 3. Aplicar estado visual inicial
                    self.updateExplosion(isExploded: self.parent.isExploded)
                    self.updateHighlight(selectedPart: self.parent.selectedPart, isHologram: self.parent.isHologram, isXRayActive: self.parent.isXRayActive)
                    self.updateSimulation(isSimulating: self.parent.isSimulating)
                } catch {
                    print("Error cargando USDZ local: \(error)")
                }
            }
        }

        private func mapNodes(node: SCNNode) {
            if let name = node.name {
                let lowerName = name.lowercased()
                for part in parent.blueprint.parts {
                    let lowerKey = part.key.lowercased()
                    if lowerName == lowerKey || lowerName.contains(lowerKey) || lowerKey.contains(lowerName) {
                        partNodes[part.key] = node
                        if originalTransforms[part.key] == nil {
                            originalTransforms[part.key] = node.position
                        }
                        break
                    }
                }
            }
            for child in node.childNodes {
                mapNodes(node: child)
            }
        }

        func updateExplosion(isExploded: Bool) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.65
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            for part in parent.blueprint.parts {
                guard let node = partNodes[part.key] else { continue }
                let base = originalTransforms[part.key] ?? SCNVector3Zero
                if isExploded {
                    let offset = part.explodedVector
                    node.position = SCNVector3(base.x + offset.x, base.y + offset.y, base.z + offset.z)
                } else {
                    node.position = base
                }
            }

            SCNTransaction.commit()
        }

        func updateSimulation(isSimulating: Bool) {
            guard let root = modelRootNode else { return }
            if isCurrentlySimulating == isSimulating { return }
            isCurrentlySimulating = isSimulating

            if isSimulating {
                // 1. Agregar luz dinámica operativa en el núcleo del modelo
                let omniLight = SCNNode()
                omniLight.name = "OperationalLight"
                omniLight.light = SCNLight()
                omniLight.light?.type = .omni
                omniLight.light?.color = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0)
                omniLight.light?.intensity = 1800
                omniLight.position = SCNVector3(0, 0, 0)

                let pulse = CABasicAnimation(keyPath: "light.intensity")
                pulse.fromValue = 1000
                pulse.toValue = 2800
                pulse.duration = 0.22
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                omniLight.addAnimation(pulse, forKey: "pulse")
                root.addChildNode(omniLight)

                // 2. Activar efectos en las piezas
                root.enumerateHierarchy { (node, _) in
                    let name = (node.name ?? "").lowercased()

                    // Rotación continua en piezas rotativas (rotores, poleas, ventiladores, ejes)
                    if name.contains("rotor") || name.contains("fan") || name.contains("ventilador") ||
                       name.contains("polea") || name.contains("shaft") || name.contains("eje") ||
                       name.contains("gear") || name.contains("ailes") || name.contains("object_2") ||
                       name.contains("object_3") || name.contains("object_5") {
                        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.75)
                        node.runAction(SCNAction.repeatForever(rotate), forKey: "op_rotation")
                    }

                    // Pulsación térmica / chispa / ignición
                    if name.contains("quemador") || name.contains("spark") || name.contains("electrodo") ||
                       name.contains("fuego") || name.contains("ignicion") || name.contains("calefon") {
                        let heatPulse = CABasicAnimation(keyPath: "emission.contents")
                        heatPulse.fromValue = UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 0.8)
                        heatPulse.toValue = UIColor(red: 1.0, green: 0.95, blue: 0.1, alpha: 1.0)
                        heatPulse.duration = 0.18
                        heatPulse.autoreverses = true
                        heatPulse.repeatCount = .infinity
                        node.geometry?.firstMaterial?.addAnimation(heatPulse, forKey: "op_heat")
                    }

                    // Pulsación de flujo / radiofrecuencia / agua / gas
                    if name.contains("serpentin") || name.contains("agua") || name.contains("gas") ||
                       name.contains("tubo") || name.contains("antena") || name.contains("estator") ||
                       name.contains("bobin") || name.contains("soc") || name.contains("wifi") ||
                       name.contains("object_6") {
                        let flowPulse = CABasicAnimation(keyPath: "emission.contents")
                        flowPulse.fromValue = UIColor(red: 0.0, green: 0.4, blue: 1.0, alpha: 0.3)
                        flowPulse.toValue = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9)
                        flowPulse.duration = 0.55
                        flowPulse.autoreverses = true
                        flowPulse.repeatCount = .infinity
                        node.geometry?.firstMaterial?.addAnimation(flowPulse, forKey: "op_flow")
                    }
                }
            } else {
                // Detener efectos operativos
                root.childNode(withName: "OperationalLight", recursively: false)?.removeFromParentNode()
                root.enumerateHierarchy { (node, _) in
                    node.removeAction(forKey: "op_rotation")
                    node.geometry?.firstMaterial?.removeAnimation(forKey: "op_heat")
                    node.geometry?.firstMaterial?.removeAnimation(forKey: "op_flow")
                    node.geometry?.firstMaterial?.emission.contents = UIColor.black
                }
            }
        }

        func updateHighlight(selectedPart: BlueprintPart?, isHologram: Bool, isXRayActive: Bool) {
            guard let root = modelRootNode else { return }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35

            if let selected = selectedPart {
                // Modo Aislamiento: pieza seleccionada al 100% destacada, resto atenuado al 20%
                for part in parent.blueprint.parts {
                    guard let node = partNodes[part.key] else { continue }
                    let isSelected = (part.key == selected.key)

                    node.enumerateHierarchy { (child, _) in
                        if isSelected {
                            child.opacity = 1.0
                            child.geometry?.firstMaterial?.transparency = 1.0
                            if isHologram {
                                child.geometry?.firstMaterial?.emission.contents = UIColor.cyan
                            } else {
                                child.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.35)
                            }
                        } else {
                            child.opacity = isHologram ? 0.12 : 0.22
                            child.geometry?.firstMaterial?.transparency = 0.22
                            child.geometry?.firstMaterial?.emission.contents = UIColor.black
                        }
                    }
                }
            } else if isXRayActive {
                // Modo Rayos X: ver el interior del modelo translúcido
                root.enumerateHierarchy { (child, _) in
                    child.opacity = 0.35
                    child.geometry?.firstMaterial?.transparency = 0.35
                    child.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.4)
                }
            } else if isHologram {
                // Modo Visión Holográfica Stark: resplandor cian general
                root.enumerateHierarchy { (child, _) in
                    child.opacity = 0.9
                    child.geometry?.firstMaterial?.transparency = 0.9
                    child.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.75)
                }
            } else {
                // Materiales Reales PBR: restaurar texturas originales sin emisión parásita
                root.enumerateHierarchy { (child, _) in
                    child.opacity = 1.0
                    child.geometry?.firstMaterial?.transparency = 1.0
                    child.geometry?.firstMaterial?.emission.contents = UIColor.black
                }
            }

            SCNTransaction.commit()
        }

        func resetCamera() {
            guard let camera = scnView?.scene?.rootNode.childNode(withName: "MainCamera", recursively: false) else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            camera.position = SCNVector3(0, 0.4, 8.5)
            camera.eulerAngles = SCNVector3Zero
            SCNTransaction.commit()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView, let root = modelRootNode else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [
                .rootNode: root,
                .boundingBoxOnly: false,
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])

            if let firstHit = hits.first {
                var current: SCNNode? = firstHit.node
                var matchedPart: BlueprintPart? = nil

                // 1. Buscar hacia arriba en la jerarquía si coincide con el nombre de alguna pieza
                while current != nil && current != root {
                    if let name = current?.name {
                        let lowerName = name.lowercased()
                        for part in parent.blueprint.parts {
                            let lowerKey = part.key.lowercased()
                            if lowerName == lowerKey || lowerName.contains(lowerKey) || lowerKey.contains(lowerName) {
                                matchedPart = part
                                break
                            }
                        }
                    }
                    if matchedPart != nil { break }
                    current = current?.parent
                }

                // 2. Si no hubo coincidencia directa por nombre, buscar por nodo en partNodes
                if matchedPart == nil {
                    for (key, pNode) in partNodes {
                        if pNode == firstHit.node || pNode == firstHit.node.parent || pNode == firstHit.node.parent?.parent {
                            matchedPart = parent.blueprint.parts.first(where: { $0.key == key })
                            break
                        }
                    }
                }

                // 3. Fallback inteligente: asignar por índice de malla
                if matchedPart == nil && !parent.blueprint.parts.isEmpty {
                    let hitName = firstHit.node.name ?? firstHit.node.parent?.name ?? ""
                    let idx = abs(hitName.hashValue) % parent.blueprint.parts.count
                    matchedPart = parent.blueprint.parts[idx]
                }

                if let found = matchedPart {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    DispatchQueue.main.async {
                        if self.parent.selectedPart?.key == found.key {
                            self.parent.selectedPart = nil
                        } else {
                            self.parent.selectedPart = found
                        }
                    }
                }
            } else {
                // Tocar en el espacio vacío deselecciona
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                DispatchQueue.main.async {
                    self.parent.selectedPart = nil
                }
            }
        }
    }
}
