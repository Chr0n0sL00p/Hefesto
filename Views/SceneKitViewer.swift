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

        // Cámara principal
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 0.4, 9.5)
        cameraNode.name = "MainCamera"
        scene.rootNode.addChildNode(cameraNode)

        // Iluminación de estudio PBR
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.color = UIColor.white
        dirLight.light?.intensity = 1800
        dirLight.position = SCNVector3(6, 12, 8)
        dirLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(dirLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0)
        fillLight.light?.intensity = 700
        fillLight.position = SCNVector3(-6, -4, -4)
        scene.rootNode.addChildNode(fillLight)

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
            // Limpiar modelo previo si existe
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

                    self.scnView?.scene?.rootNode.addChildNode(root)
                    self.modelRootNode = root

                    // Mapear nodos a las partes del plano
                    self.mapNodes(node: root)

                    // Aplicar estado inicial
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
                for part in parent.blueprint.parts {
                    if name.lowercased().contains(part.key.lowercased()) || part.key.lowercased().contains(name.lowercased()) {
                        partNodes[part.key] = node
                        originalTransforms[part.key] = node.position
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
                node.position = isExploded ? part.explodedVector : part.assembledVector
            }

            SCNTransaction.commit()
        }

        func updateSimulation(isSimulating: Bool) {
            guard let root = modelRootNode else { return }
            if isCurrentlySimulating == isSimulating { return }
            isCurrentlySimulating = isSimulating

            if isSimulating {
                // Activar efectos operativos en tiempo real
                root.enumerateHierarchy { (node, _) in
                    let name = (node.name ?? "").lowercased()

                    // 1. Piezas Rotativas (Rotores, ventiladores, poleas, engranajes, turbinas)
                    if name.contains("rotor") || name.contains("fan") || name.contains("ventilador") ||
                       name.contains("polea") || name.contains("shaft") || name.contains("eje") ||
                       name.contains("gear") || name.contains("ailes") {
                        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.6)
                        node.runAction(SCNAction.repeatForever(rotate), forKey: "op_rotation")
                    }

                    // 2. Fuego / Quemador / Chispa / Ignición
                    if name.contains("quemador") || name.contains("spark") || name.contains("electrodo") ||
                       name.contains("fuego") || name.contains("ignicion") || name.contains("calefon") {
                        let heatPulse = CABasicAnimation(keyPath: "emission.contents")
                        heatPulse.fromValue = UIColor(red: 1.0, green: 0.25, blue: 0.0, alpha: 0.7)
                        heatPulse.toValue = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1.0)
                        heatPulse.duration = 0.2
                        heatPulse.autoreverses = true
                        heatPulse.repeatCount = .infinity
                        node.geometry?.firstMaterial?.addAnimation(heatPulse, forKey: "op_heat")
                    }

                    // 3. Flujo Hidráulico, Conducción Eléctrica, Radiofrecuencia / Antenas
                    if name.contains("serpentin") || name.contains("agua") || name.contains("gas") ||
                       name.contains("tubo") || name.contains("antena") || name.contains("estator") ||
                       name.contains("bobin") || name.contains("soc") || name.contains("wifi") ||
                       name.contains("filter") {
                        let flowPulse = CABasicAnimation(keyPath: "emission.contents")
                        flowPulse.fromValue = UIColor(red: 0.0, green: 0.35, blue: 1.0, alpha: 0.25)
                        flowPulse.toValue = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85)
                        flowPulse.duration = 0.65
                        flowPulse.autoreverses = true
                        flowPulse.repeatCount = .infinity
                        node.geometry?.firstMaterial?.addAnimation(flowPulse, forKey: "op_flow")
                    }
                }
            } else {
                // Detener animación y restaurar estado pasivo
                root.enumerateHierarchy { (node, _) in
                    node.removeAction(forKey: "op_rotation")
                    node.geometry?.firstMaterial?.removeAnimation(forKey: "op_heat")
                    node.geometry?.firstMaterial?.removeAnimation(forKey: "op_flow")
                    node.geometry?.firstMaterial?.emission.contents = UIColor.black
                }
            }
        }

        func updateHighlight(selectedPart: BlueprintPart?, isHologram: Bool, isXRayActive: Bool) {
            guard let _ = modelRootNode else { return }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35

            if let selected = selectedPart {
                // Modo Aislamiento / Ghosting: atenuar no seleccionadas al 20%
                for part in parent.blueprint.parts {
                    guard let node = partNodes[part.key] else { continue }
                    let isSelected = (part.key == selected.key)

                    node.enumerateHierarchy { (child, _) in
                        if isSelected {
                            child.opacity = 1.0
                            child.geometry?.firstMaterial?.transparency = 1.0
                            if isHologram {
                                child.geometry?.firstMaterial?.emission.contents = UIColor.cyan
                                child.geometry?.firstMaterial?.fillMode = .lines
                            } else {
                                child.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.7, blue: 1.0, alpha: 0.6)
                                child.geometry?.firstMaterial?.fillMode = .fill
                            }
                        } else {
                            // Ghosting atenuado al 20%
                            child.opacity = isHologram ? 0.12 : 0.20
                            child.geometry?.firstMaterial?.transparency = 0.20
                            child.geometry?.firstMaterial?.emission.contents = UIColor.black
                            if isHologram {
                                child.geometry?.firstMaterial?.fillMode = .lines
                            } else {
                                child.geometry?.firstMaterial?.fillMode = .fill
                            }
                        }
                    }
                }
            } else if isXRayActive {
                // Rayos X general activo sin selección específica
                for (_, node) in partNodes {
                    node.enumerateHierarchy { (child, _) in
                        child.opacity = 0.35
                        child.geometry?.firstMaterial?.transparency = 0.35
                        child.geometry?.firstMaterial?.emission.contents = UIColor.cyan
                        child.geometry?.firstMaterial?.fillMode = .lines
                    }
                }
            } else {
                // Sin selección ni rayos X: todo al 100% visible
                for (_, node) in partNodes {
                    node.enumerateHierarchy { (child, _) in
                        child.opacity = 1.0
                        child.geometry?.firstMaterial?.transparency = 1.0
                        child.geometry?.firstMaterial?.emission.contents = UIColor.black
                        child.geometry?.firstMaterial?.fillMode = isHologram ? .lines : .fill
                    }
                }
            }

            SCNTransaction.commit()
        }

        func resetCamera() {
            guard let camera = scnView?.scene?.rootNode.childNode(withName: "MainCamera", recursively: false) else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            camera.position = SCNVector3(0, 0.4, 9.5)
            camera.eulerAngles = SCNVector3Zero
            SCNTransaction.commit()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [.rootNode: modelRootNode as Any])

            if let firstHit = hits.first {
                var current: SCNNode? = firstHit.node
                while current != nil {
                    if let name = current?.name {
                        for part in parent.blueprint.parts {
                            if name.lowercased().contains(part.key.lowercased()) || part.key.lowercased().contains(name.lowercased()) {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()

                                DispatchQueue.main.async {
                                    if self.parent.selectedPart?.key == part.key {
                                        self.parent.selectedPart = nil
                                    } else {
                                        self.parent.selectedPart = part
                                    }
                                }
                                return
                            }
                        }
                    }
                    current = current?.parent
                }
            } else {
                // Tocar en el espacio vacío deselecciona la pieza
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                DispatchQueue.main.async {
                    self.parent.selectedPart = nil
                }
            }
        }
    }
}
