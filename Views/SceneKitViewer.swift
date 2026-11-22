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
    public let environment: ViewerEnvironment
    public let cameraResetTrigger: Int

    public init(
        blueprint: Blueprint,
        selectedPart: Binding<BlueprintPart?>,
        isHologram: Bool,
        isExploded: Bool,
        isXRayActive: Bool,
        isSimulating: Bool,
        environment: ViewerEnvironment = .studioDark,
        cameraResetTrigger: Int
    ) {
        self.blueprint = blueprint
        self._selectedPart = selectedPart
        self.isHologram = isHologram
        self.isExploded = isExploded
        self.isXRayActive = isXRayActive
        self.isSimulating = isSimulating
        self.environment = environment
        self.cameraResetTrigger = cameraResetTrigger
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 14/255, green: 18/255, blue: 27/255, alpha: 1.0)
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
        ambientLight.light?.color = UIColor(white: 0.70, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        context.coordinator.ambientLight = ambientLight.light

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.color = UIColor.white
        dirLight.light?.intensity = 2200
        dirLight.position = SCNVector3(5, 10, 8)
        dirLight.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(dirLight)
        context.coordinator.dirLight = dirLight.light

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1.0)
        fillLight.light?.intensity = 900
        fillLight.position = SCNVector3(-6, -4, -4)
        scene.rootNode.addChildNode(fillLight)
        context.coordinator.fillLight = fillLight.light

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        rimLight.light?.intensity = 600
        rimLight.position = SCNVector3(0, -6, -8)
        scene.rootNode.addChildNode(rimLight)
        context.coordinator.rimLight = rimLight.light

        // Suelo con cuadrícula técnica CAD
        let gridPlaneNode = Coordinator.createGridPlane()
        gridPlaneNode.isHidden = (environment != .cadGrid)
        scene.rootNode.addChildNode(gridPlaneNode)
        context.coordinator.gridNode = gridPlaneNode

        // Gestor de toques para selección de partes y deselección
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        context.coordinator.scnView = scnView

        // Cargar modelo USDZ nativo y aplicar entorno inicial
        context.coordinator.updateEnvironment(environment)
        context.coordinator.loadModel()

        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.currentBlueprintId != blueprint.id {
            context.coordinator.currentBlueprintId = blueprint.id
            context.coordinator.loadModel()
        }

        if context.coordinator.currentEnvironment != environment {
            context.coordinator.currentEnvironment = environment
            context.coordinator.updateEnvironment(environment)
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
        var currentEnvironment: ViewerEnvironment = .studioDark
        weak var ambientLight: SCNLight?
        weak var dirLight: SCNLight?
        weak var fillLight: SCNLight?
        weak var rimLight: SCNLight?
        var gridNode: SCNNode?

        init(_ parent: SceneKitViewer) {
            self.parent = parent
            self.currentBlueprintId = parent.blueprint.id
            self.currentEnvironment = parent.environment
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

                    // 1. Centrar pivote y normalizar escala de cualquier modelo USDZ importado inspeccionando la jerarquía completa
                    if let bounds = Self.calculateHierarchyBoundingBox(for: root) {
                        let dx = bounds.max.x - bounds.min.x
                        let dy = bounds.max.y - bounds.min.y
                        let dz = bounds.max.z - bounds.min.z
                        let maxDim = max(dx, max(dy, dz))

                        if maxDim > 0.001 {
                            let centerX = (bounds.min.x + bounds.max.x) / 2.0
                            let centerY = (bounds.min.y + bounds.max.y) / 2.0
                            let centerZ = (bounds.min.z + bounds.max.z) / 2.0

                            // Centrar pivote en el centro real de la masa del objeto
                            root.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

                            // Escalar para que quepa en un cubo visible de ~4.5 unidades
                            let targetSize: Float = 4.5
                            let scaleFactor = targetSize / maxDim
                            root.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
                        }
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

        private static func calculateHierarchyBoundingBox(for node: SCNNode) -> (min: SCNVector3, max: SCNVector3)? {
            var minX = Float.greatestFiniteMagnitude
            var minY = Float.greatestFiniteMagnitude
            var minZ = Float.greatestFiniteMagnitude
            var maxX = -Float.greatestFiniteMagnitude
            var maxY = -Float.greatestFiniteMagnitude
            var maxZ = -Float.greatestFiniteMagnitude
            var found = false

            node.enumerateHierarchy { (child, _) in
                if child.geometry != nil {
                    let (cMin, cMax) = child.boundingBox
                    if cMin.x != cMax.x || cMin.y != cMax.y || cMin.z != cMax.z {
                        found = true
                        let corners = [
                            SCNVector3(cMin.x, cMin.y, cMin.z),
                            SCNVector3(cMax.x, cMin.y, cMin.z),
                            SCNVector3(cMin.x, cMax.y, cMin.z),
                            SCNVector3(cMax.x, cMax.y, cMin.z),
                            SCNVector3(cMin.x, cMin.y, cMax.z),
                            SCNVector3(cMax.x, cMin.y, cMax.z),
                            SCNVector3(cMin.x, cMax.y, cMax.z),
                            SCNVector3(cMax.x, cMax.y, cMax.z)
                        ]
                        for corner in corners {
                            let p = child.convertPosition(corner, to: node)
                            minX = min(minX, p.x)
                            minY = min(minY, p.y)
                            minZ = min(minZ, p.z)
                            maxX = max(maxX, p.x)
                            maxY = max(maxY, p.y)
                            maxZ = max(maxZ, p.z)
                        }
                    }
                }
            }

            if found {
                return (min: SCNVector3(minX, minY, minZ), max: SCNVector3(maxX, maxY, maxZ))
            }
            return nil
        }

        private func mapNodes(node: SCNNode) {
            if let name = node.name {
                let lowerName = name.lowercased()
                for part in parent.blueprint.parts {
                    if partNodes[part.key] != nil { continue }
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

        func updateEnvironment(_ env: ViewerEnvironment) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4

            switch env {
            case .studioDark:
                scnView?.backgroundColor = UIColor(red: 14/255, green: 18/255, blue: 27/255, alpha: 1.0)
                gridNode?.isHidden = true
                ambientLight?.color = UIColor(white: 0.70, alpha: 1.0)
                dirLight?.intensity = 2200
                dirLight?.color = UIColor.white
                fillLight?.color = UIColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1.0)
                fillLight?.intensity = 900
                rimLight?.color = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
                rimLight?.intensity = 600

            case .cadGrid:
                scnView?.backgroundColor = UIColor(red: 8/255, green: 13/255, blue: 22/255, alpha: 1.0)
                gridNode?.isHidden = false
                ambientLight?.color = UIColor(white: 0.60, alpha: 1.0)
                dirLight?.intensity = 2400
                dirLight?.color = UIColor(white: 0.95, alpha: 1.0)
                fillLight?.color = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
                fillLight?.intensity = 1100
                rimLight?.color = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
                rimLight?.intensity = 700

            case .workshopWhite:
                scnView?.backgroundColor = UIColor(red: 236/255, green: 240/255, blue: 246/255, alpha: 1.0)
                gridNode?.isHidden = true
                ambientLight?.color = UIColor(white: 0.90, alpha: 1.0)
                dirLight?.intensity = 2600
                dirLight?.color = UIColor.white
                fillLight?.color = UIColor(red: 0.78, green: 0.84, blue: 0.92, alpha: 1.0)
                fillLight?.intensity = 1200
                rimLight?.color = UIColor(white: 0.75, alpha: 1.0)
                rimLight?.intensity = 400
            }

            SCNTransaction.commit()
        }

        static func createGridPlane() -> SCNNode {
            let size = CGSize(width: 512, height: 512)
            let renderer = UIGraphicsImageRenderer(size: size)
            let img = renderer.image { ctx in
                let cg = ctx.cgContext
                // Fondo azul técnico oscuro
                cg.setFillColor(UIColor(red: 9/255, green: 15/255, blue: 26/255, alpha: 0.85).cgColor)
                cg.fill(CGRect(origin: .zero, size: size))

                // Líneas de cuadrícula secundaria cada 32px
                cg.setLineWidth(1.0)
                cg.setStrokeColor(UIColor(red: 0/255, green: 240/255, blue: 1.0, alpha: 0.20).cgColor)
                for x in stride(from: 0, through: 512, by: 32) {
                    cg.move(to: CGPoint(x: CGFloat(x), y: 0))
                    cg.addLine(to: CGPoint(x: CGFloat(x), y: 512))
                }
                for y in stride(from: 0, through: 512, by: 32) {
                    cg.move(to: CGPoint(x: 0, y: CGFloat(y)))
                    cg.addLine(to: CGPoint(x: 512, y: CGFloat(y)))
                }
                cg.strokePath()

                // Líneas maestras cada 128px
                cg.setLineWidth(2.0)
                cg.setStrokeColor(UIColor(red: 0/255, green: 240/255, blue: 1.0, alpha: 0.50).cgColor)
                for x in stride(from: 0, through: 512, by: 128) {
                    cg.move(to: CGPoint(x: CGFloat(x), y: 0))
                    cg.addLine(to: CGPoint(x: CGFloat(x), y: 512))
                }
                for y in stride(from: 0, through: 512, by: 128) {
                    cg.move(to: CGPoint(x: 0, y: CGFloat(y)))
                    cg.addLine(to: CGPoint(x: 512, y: CGFloat(y)))
                }
                cg.strokePath()

                // Círculo concéntrico técnico en el origen
                cg.setLineWidth(2.0)
                cg.setStrokeColor(UIColor(red: 0/255, green: 240/255, blue: 1.0, alpha: 0.65).cgColor)
                cg.strokeEllipse(in: CGRect(x: 128, y: 128, width: 256, height: 256))
            }

            let planeGeom = SCNPlane(width: 25, height: 25)
            planeGeom.cornerRadius = 0.5
            let mat = SCNMaterial()
            mat.diffuse.contents = img
            mat.diffuse.wrapS = .repeat
            mat.diffuse.wrapT = .repeat
            mat.diffuse.contentsTransform = SCNMatrix4MakeScale(5, 5, 1)
            mat.isDoubleSided = true
            mat.lightingModel = .constant
            planeGeom.materials = [mat]

            let node = SCNNode(geometry: planeGeom)
            node.name = "CADFloorGrid"
            node.eulerAngles = SCNVector3(-Float.pi / 2.0, 0, 0)
            node.position = SCNVector3(0, -2.3, 0)
            return node
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
