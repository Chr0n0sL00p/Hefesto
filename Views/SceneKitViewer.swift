//
//  SceneKitViewer.swift
//  StarkHUD - Visor 3D Metal / SceneKit con Despiece y Aislamiento Rayos-X
//

import SwiftUI
import SceneKit
import UIKit

public struct SceneKitViewer: UIViewRepresentable {
    public let blueprint: Blueprint
    @Binding public var selectedPart: BlueprintPart?
    public let isHologram: Bool
    public let isExploded: Bool
    public let isFlowActive: Bool
    public let cameraResetTrigger: Int

    public init(
        blueprint: Blueprint,
        selectedPart: Binding<BlueprintPart?>,
        isHologram: Bool,
        isExploded: Bool,
        isFlowActive: Bool,
        cameraResetTrigger: Int
    ) {
        self.blueprint = blueprint
        self._selectedPart = selectedPart
        self.isHologram = isHologram
        self.isExploded = isExploded
        self.isFlowActive = isFlowActive
        self.cameraResetTrigger = cameraResetTrigger
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 4/255, green: 7/255, blue: 13/255, alpha: 1.0)
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false

        let scene = SCNScene()
        scnView.scene = scene

        // Cámara
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 0.5, 10.5)
        cameraNode.name = "MainCamera"
        scene.rootNode.addChildNode(cameraNode)

        // Iluminación
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.45, alpha: 1.0)
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

        // Gestor de toques (Tap Raycasting)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        context.coordinator.scnView = scnView

        // Cargar modelo USDZ nativo
        context.coordinator.loadModel()

        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateExplosion(isExploded: isExploded)
        context.coordinator.updateHighlight(selectedPart: selectedPart, isHologram: isHologram)
        context.coordinator.updateFlow(isFlowActive: isFlowActive)

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
        var selectionBoxNode: SCNNode?

        init(_ parent: SceneKitViewer) {
            self.parent = parent
        }

        func loadModel() {
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
                    self.updateHighlight(selectedPart: self.parent.selectedPart, isHologram: self.parent.isHologram)
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

        func updateHighlight(selectedPart: BlueprintPart?, isHologram: Bool) {
            guard let root = modelRootNode else { return }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35

            if let selected = selectedPart {
                // Aislamiento / Ghosting: atenuar todas las demás al 20%
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
                                child.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.6)
                                child.geometry?.firstMaterial?.fillMode = .fill
                            }
                        } else {
                            // Ghosting atenuado
                            child.opacity = isHologram ? 0.12 : 0.22
                            child.geometry?.firstMaterial?.transparency = 0.22
                            child.geometry?.firstMaterial?.emission.contents = UIColor.black
                            if isHologram {
                                child.geometry?.firstMaterial?.fillMode = .lines
                            } else {
                                child.geometry?.firstMaterial?.fillMode = .fill
                            }
                        }
                    }
                }
            } else {
                // Sin selección: todo 100% visible
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

        func updateFlow(isFlowActive: Bool) {
            // Animación suave de pulsación operativa
            guard isFlowActive, let root = modelRootNode else { return }
            let pulse = CABasicAnimation(keyPath: "scale")
            pulse.duration = 0.8
            pulse.fromValue = NSValue(scnVector3: SCNVector3(1.0, 1.0, 1.0))
            pulse.toValue = NSValue(scnVector3: SCNVector3(1.02, 1.02, 1.02))
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            root.addAnimation(pulse, forKey: "flowPulse")
        }

        func resetCamera() {
            guard let camera = scnView?.scene?.rootNode.childNode(withName: "MainCamera", recursively: false) else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            camera.position = SCNVector3(0, 0.5, 10.5)
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
                                // Taptic feedback nativo de iPhone 16
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()

                                DispatchQueue.main.async {
                                    self.parent.selectedPart = part
                                }
                                return
                            }
                        }
                    }
                    current = current?.parent
                }
            }
        }
    }
}
