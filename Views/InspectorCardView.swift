//
//  InspectorCardView.swift
//  Hefesto - Ficha Técnica de Ingeniería y Diagnóstico
//

import SwiftUI

public struct InspectorCardView: View {
    public let part: BlueprintPart
    public let phases: [String]
    public let onClose: () -> Void

    public init(part: BlueprintPart, phases: [String], onClose: @escaping () -> Void) {
        self.part = part
        self.phases = phases
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cabecera de la pieza
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.id)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0, green: 240/255, blue: 1.0).opacity(0.15))
                        .cornerRadius(4)

                    Text(part.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(part.subsystem)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.65))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(white: 0.5))
                }
            }

            Divider().background(Color(white: 0.2))

            // Material y Fabricación
            VStack(alignment: .leading, spacing: 4) {
                Text("MATERIAL & FABRICACIÓN INDUSTRIAL")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.55))
                    .tracking(0.5)

                Text(part.material)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 7/255, green: 11/255, blue: 18/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.15), lineWidth: 1)
                    )
            }

            // Función y Principio Físico
            VStack(alignment: .leading, spacing: 4) {
                Text("FUNCIÓN MECÁNICA & PRINCIPIO FÍSICO")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.55))
                    .tracking(0.5)

                Text(part.function)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 7/255, green: 11/255, blue: 18/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.15), lineWidth: 1)
                    )
            }

            // Diagnóstico y Fallas
            VStack(alignment: .leading, spacing: 4) {
                Text("DIAGNÓSTICO & FALLA FRECUENTE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                    .tracking(0.5)

                Text(part.failure)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.92))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 30/255, green: 10/255, blue: 15/255))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.4), lineWidth: 1)
                    )
            }

            // Ciclo Operativo en 4 Fases
            VStack(alignment: .leading, spacing: 6) {
                Text("CICLO OPERATIVO EN 4 FASES")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(white: 0.55))
                    .tracking(0.5)

                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color(red: 0, green: 240/255, blue: 1.0))
                            .frame(width: 18, height: 18)
                            .background(Color(red: 2/255, green: 132/255, blue: 199/255).opacity(0.3))
                            .clipShape(Circle())

                        Text(phase)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 14/255, green: 22/255, blue: 38/255))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 30/255, green: 46/255, blue: 74/255), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)
    }
}
