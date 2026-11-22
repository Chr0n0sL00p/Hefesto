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
                    BlueprintPart(id: "PIEZA 01", key: "Serpentin_Cobre", name: "Serpentín de Cobre & Aletas", subsystem: "Intercambiador de Calor Primario", material: "Cobre electrolítico Cu-DHP (~99.9% pureza). Soldadura fuerte de plata para soportar 800°C en aletas disipadoras.", function: "Transfiere instantáneamente la energía calorífica del quemador hacia el caudal de agua en régimen turbulento forzado, elevando la temperatura de 15°C a 44°C en 4 segundos.", failure: "Incrustación de Sarro / Caudal Pobre: El carbonato de calcio crea una película aislante que reduce el caudal y sobrecalienta el cobre. Requiere desincrustado con ácido cítrico recirculado.", posAssembled: [0.0, 1.25, 0.0], posExploded: [0.0, 2.6, 0.0]),
                    BlueprintPart(id: "PIEZA 02", key: "Campana_TiroNatural", name: "Deflector de Tiro Natural", subsystem: "Campana de Evacuación de Humos", material: "Chapa de acero galvanizado o aluminizado resistente a condensados ácidos y humos de escape hasta 220°C.", function: "Canaliza los gases de combustión hacia el ducto de escape exterior y frena corrientes de viento descendentes para evitar retorno de monóxido.", failure: "Ducto Obstruido / Apagado por Sensor de Tiro: Si los gases se acumulan en la campana, el sensor térmico corta el paso de gas a los 90 segundos.", posAssembled: [0.0, 2.7, 0.0], posExploded: [0.0, 4.6, 0.0]),
                    BlueprintPart(id: "PIEZA 03", key: "Quemador_Atmosferico", name: "Quemador Multi-Rampa (Toberas)", subsystem: "Cámara de Combustión Atmosférica", material: "Inyectores de latón maquinado y rampas difusoras en acero inoxidable AISI 304 estampadas para evitar corrosión.", function: "Mezcla el gas licuado o natural con el aire primario (efecto Bunsen) y genera una cortina de llamas cortas, estables y azuladas a ~1.200°C debajo del serpentín.", failure: "Llama Amarilla y Hollín Negro: Inyectores sucios o toberas con polvo. Genera combustión incompleta peligrosa (monóxido) y mancha el serpentín.", posAssembled: [0.0, 0.1, 0.0], posExploded: [0.0, 0.1, 0.0]),
                    BlueprintPart(id: "PIEZA 04", key: "Electrodos_Ignicion", name: "Chispero & Sensor de Ionización", subsystem: "Ignición Electrónica & Monitoreo de Llama", material: "Varilla de aleación Kanthal resistente a 1.300°C montada en aislador cerámico de alúmina con cable de silicona de alta tensión.", function: "La bujía izquierda genera un arco eléctrico de 12.000V para encender el gas. La bujía derecha detecta el plasma de la llama mediante micro-corriente continua.", failure: "Prende y se apaga exactamente a los 3 segundos: El sensor de ionización no detecta la corriente iónica porque está cubierto de carbón o desalineado.", posAssembled: [-0.3, 0.5, 0.55], posExploded: [-0.6, 0.8, 1.8]),
                    BlueprintPart(id: "PIEZA 05", key: "Cuerpo_Agua_Laton", name: "Cuerpo de Agua & Membrana Venturi", subsystem: "Activador Hidromecánico", material: "Cuerpo de latón forjado / polímero técnico con membrana elástica de caucho EPDM y vástago de empuje de acero inoxidable.", function: "Al abrir una canilla, la caída de presión en el Venturi deforma la membrana elástica y empuja el vástago 4 mm hacia arriba para habilitar el paso de gas.", failure: "No chispea ni prende al dar el agua: Membrana perforada, estirada o rota. Es la falla mecánica más común en Chile; no genera fuerza para mover el eje.", posAssembled: [-0.85, -1.25, 0.0], posExploded: [-2.5, -1.8, 0.0]),
                    BlueprintPart(id: "PIEZA 06", key: "Valvula_Gas_Aluminio", name: "Válvula de Gas con Solenoide", subsystem: "Regulación y Corte de Combustible", material: "Cuerpo de aluminio inyectado a presión con electroimán (solenoide) de bobina doble de apertura rápida y retención.", function: "Control de seguridad de doble etapa: el vástago de agua abre mecánicamente la primera compuerta, y el solenoide abre la segunda etapa si la electrónica valida chispa.", failure: "Chispea pero no prende / Sin olor a gas: Solenoide quemado, cables cortados o batería baja (menor a 1.3V) que no alcanza a vencer el resorte del solenoide.", posAssembled: [0.85, -1.25, 0.0], posExploded: [2.5, -1.8, 0.0]),
                    BlueprintPart(id: "PIEZA 07", key: "Modulo_Encendido_3V", name: "Módulo Electrónico & Caja Portapilas", subsystem: "Unidad de Control Inteligente (CPU)", material: "Circuito impreso encapsulado en resina epóxica IP54 contra humedad ambiental y chispas parásitas.", function: "Controla la secuencia de tiempo: recibe señal del microswitch, activa oscilador de alto voltaje por 7 segundos y monitorea retorno del sensor de llama.", failure: "Calefont mudo (no hace clic ni chispea): Sulfatación de contactos en portapilas o microswitch con óxido interno por goteo de agua previo.", posAssembled: [-0.5, -2.2, 0.0], posExploded: [-1.2, -3.8, 0.0]),
                    BlueprintPart(id: "PIEZA 08", key: "Sensor_Klixon_85C", name: "Sensor Térmico Bimetálico (Klixon 85°C)", subsystem: "Seguridad por Sobrecalentamiento", material: "Disco bimetálico sellado herméticamente de acción rápida con contactos de plata normalmente cerrados (NC).", function: "Corta instantáneamente el circuito eléctrico hacia el solenoide si la temperatura del agua de salida supera 85°C para evitar quemaduras graves o vapor en tuberías.", failure: "El calefont se apaga a los 3-5 minutos de uso: Klixon descalibrado, tiro tapado o serpentín tapado con sarro que eleva la temperatura súbitamente.", posAssembled: [0.95, 1.3, 0.0], posExploded: [2.2, 1.8, 0.0])
                ]
            ),
            Blueprint(
                id: "router",
                title: "Router Wi-Fi 6 AX3000 (MIMO 4x4)",
                subtitle: "Enrutador de Telecomunicaciones y Fibra Óptica",
                norm: "Norma IEEE 802.11ax · MU-MIMO OFDMA · WPA3",
                usdzUrl: "http://100.117.169.38:4550/blueprint/router.usdz",
                htmlUrl: "http://100.117.169.38:4550/blueprint/router",
                flowBtnLabel: "Tráfico Gigabit",
                flowStateOn: "TRÁFICO ACTIVO (PAQUETES RX/TX EN 5GHz)",
                flowStateOff: "STANDBY (RED CONECTADA SIN TRÁFICO)",
                stat1Label: "THROUGHPUT",
                stat1ValOn: "2402 Mbps",
                stat1ValOff: "0.0 Mbps",
                stat2Label: "LATENCIA",
                stat2ValOn: "3.8 ms",
                stat2ValOff: "1.2 ms",
                phases: [
                    "Recepción RF: Ondas electromagnéticas captadas por arreglo dipolo 5dBi con ganancia LNA.",
                    "Conversión en Banda Base: Filtrado analógico pasabanda y demodulación OFDMA en FEM.",
                    "Enrutamiento SoC: Conmutación de paquetes por hardware ARM y consulta en tabla NAT.",
                    "Transmisión Gigabit: Aislamiento magnético y salida balanceada por cableado Ethernet."
                ],
                parts: [
                    BlueprintPart(id: "PIEZA 01", key: "Chasis_Superior", name: "Chasis Superior & Ventilación Nido de Abeja", subsystem: "Envolvente Térmica & Blindaje Estructural", material: "Termoplástico ABS/PC retardante de llama (UL94-V0) electrogalvanizado con patrón convectivo.", function: "Protege los circuitos internos contra impactos físicos y facilita la disipación pasiva de aire caliente generado por el SoC.", failure: "Deformación por sobrecalentamiento / Bloqueo de ranuras por polvo: Incrementa la temperatura de unión del SoC sobre 95°C activando throttling térmico.", posAssembled: [0.0, 1.1, 0.0], posExploded: [0.0, 2.8, 0.0]),
                    BlueprintPart(id: "PIEZA 02", key: "Disipador_SoC", name: "Disipador de Aluminio Anodizado", subsystem: "Gestión Térmica del Procesador", material: "Aleación de aluminio 6063 extruido con microaletas y almohadilla térmica de silicona de 6.0 W/mK.", function: "Conduce instantáneamente el flujo de calor de 15W del procesador ARM hacia el aire circulante dentro del chasis.", failure: "Almohadilla térmica seca o degradada: Causa reinicios aleatorios del router bajo tráfico pesado o transferencias sostenidas de 1 Gbps.", posAssembled: [-0.6, 0.55, 0.2], posExploded: [-1.2, 1.8, 0.5]),
                    BlueprintPart(id: "PIEZA 03", key: "Blindaje_RF", name: "Blindaje Metálico EMI / RFI", subsystem: "Inmunidad Electromagnética", material: "Chapa de alpaca (níquel-plata) soldada al plano de masa perimetral de la placa base.", function: "Aísla los amplificadores de bajo ruido (LNA) de 5GHz contra armónicos generados por el reloj de la CPU y la fuente conmutada.", failure: "Soldadura fría en masa: Desensibilización de recepción (pérdida de cobertura a distancias mayores a 8 metros).", posAssembled: [1.1, 0.45, -0.1], posExploded: [2.6, 1.6, 0.3]),
                    BlueprintPart(id: "PIEZA 04", key: "Placa_PCB", name: "Placa Base Multicapa (PCB FR-4)", subsystem: "Plataforma Electrónica Principal", material: "Laminado de fibra de vidrio epóxica de 6 capas con terminación de oro de inmersión químico (ENIG).", function: "Interconecta mediante pistas de impedancia controlada de 50 ohms la CPU, memorias DDR4, radios FEM y puertos Ethernet.", failure: "Microfisuras por estrés térmico o pistas quemadas por sobretensión en línea WAN durante tormentas eléctricas.", posAssembled: [0.0, 0.0, 0.0], posExploded: [0.0, 0.0, 0.0]),
                    BlueprintPart(id: "PIEZA 05", key: "Antenas_RF", name: "Arreglo de 4 Antenas Dipolo 5dBi", subsystem: "Transmisión RF & Beamforming 4x4", material: "Radiador de cobre encapsulado en radomo de polipropileno con conector U.FL de baja pérdida.", function: "Forma los haces de señal directiva (Beamforming) y multiplexación espacial en bandas concurrentes de 2.4GHz y 5GHz.", failure: "Cable coaxial interno U.FL estrangulado por rotación excesiva: Caída drástica de velocidad en la banda de 5 GHz.", posAssembled: [0.0, 1.2, -1.6], posExploded: [0.0, 2.2, -3.2]),
                    BlueprintPart(id: "PIEZA 06", key: "Puertos_RJ45", name: "Módulo de Puertos RJ45 Blindados", subsystem: "Conectividad WAN / LAN Gigabit", material: "Carcasa de aleación de zinc niquelada con contactos chapados en oro de 50 micropulgadas y transformador magnético pulse.", function: "Aislamiento galvánico de 1.500V RMS y acoplamiento balanceado para tramas Ethernet 10/100/1000/2.5G Base-T.", failure: "Contactos sulfatados o dañados: El puerto negocia a 100 Mbps en lugar de 1000 Mbps por pérdida de continuidad en pares 4-5 o 7-8.", posAssembled: [-1.4, 0.3, -1.3], posExploded: [-3.0, 0.6, -2.6]),
                    BlueprintPart(id: "PIEZA 07", key: "Chasis_Inferior", name: "Chasis Inferior & Topes Antivibración", subsystem: "Base Mecánica & Anclaje Mural", material: "Base de ABS inyectado con patas de goma de silicona antideslizante y ranuras VESA para montaje vertical.", function: "Soporta el ensamble completo, provee soporte estructural y disipa el calor residual por convección natural inferior.", failure: "Topes degradados por calor, vibraciones transmitidas a la mesa de trabajo.", posAssembled: [0.0, -0.6, 0.0], posExploded: [0.0, -2.2, 0.0])
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
    public func fetchBlueprints() async {
        isLoading = true
        errorMessage = nil

        let url = baseUrl.appendingPathComponent("api/blueprints")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

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
    public func getLocalUsdzUrl(for blueprint: Blueprint) async throws -> URL {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let localFile = cacheDir.appendingPathComponent("\(blueprint.id).usdz")

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
