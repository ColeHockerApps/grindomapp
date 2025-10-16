//
//  Models.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import Foundation
import Combine

// MARK: - Order Status

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case new = "New"
    case inProgress = "In Progress"
    case done = "Done"
    case canceled = "Canceled"

    var id: String { rawValue }
}

// MARK: - Client

struct Client: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var note: String?
    var createdAt: Date = Date()
    var isArchived: Bool = false
}

// MARK: - Order

struct Order: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var clientId: UUID
    var serviceName: String
    var serviceIcon: String
    var serviceColorHex: String
    var price: Double
    var date: Date
    var note: String?
    var status: OrderStatus
    var createdAt: Date = Date()
}

// MARK: - Service Template

struct ServiceTemplate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var basePrice: Double
    var icon: String
    var colorHex: String
}

// MARK: - Helpers

extension Order {
    var color: String { serviceColorHex }
}

extension ServiceTemplate {
    static func defaultTemplates() -> [ServiceTemplate] {
        return [
            ServiceTemplate(name: "Haircut", basePrice: 30, icon: "scissors", colorHex: "#FFA500"),
            ServiceTemplate(name: "Manicure", basePrice: 25, icon: "hand.raised.fill", colorHex: "#FF66B2"),
            ServiceTemplate(name: "Consulting", basePrice: 50, icon: "person.text.rectangle", colorHex: "#40E0D0"),
            ServiceTemplate(name: "Photo", basePrice: 70, icon: "camera.fill", colorHex: "#A55EFF"),
            ServiceTemplate(name: "Training", basePrice: 40, icon: "dumbbell.fill", colorHex: "#6FFF7B")
        ]
    }
}
