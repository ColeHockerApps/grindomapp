//
//  LocalStore.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class LocalStore {

    private let fileName = "grindomapp.data.json"

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    struct Payload: Codable {
        var clients: [Client]
        var orders: [Order]
        var seededAt: Date?
    }

    // MARK: - Load

    func load() -> Payload {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode(Payload.self, from: data)
                return decoded
            } catch {
                print("⚠️ Load error:", error)
                return seed()
            }
        } else {
            return seed()
        }
    }

    // MARK: - Save

    func save(_ payload: Payload) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ Save error:", error)
        }
    }

    // MARK: - Seed data

    private func seed() -> Payload {
        let templates = ServiceTemplate.defaultTemplates()

        let c1 = Client(name: "Anna", note: "Prefers short style")
        let c2 = Client(name: "Mark", note: "Frequent visitor")
        let c3 = Client(name: "Sofia", note: "Wedding shoot package")

        func order(for client: Client, template: ServiceTemplate, price: Double, status: OrderStatus, offset: Int) -> Order {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            return Order(
                clientId: client.id,
                serviceName: template.name,
                serviceIcon: template.icon,
                serviceColorHex: template.colorHex,
                price: price,
                date: date,
                note: nil,
                status: status
            )
        }

        let o1 = order(for: c1, template: templates[0], price: 30, status: .new, offset: 0)
        let o2 = order(for: c2, template: templates[1], price: 25, status: .inProgress, offset: -1)
        let o3 = order(for: c3, template: templates[3], price: 70, status: .done, offset: -2)

        let payload = Payload(clients: [c1, c2, c3], orders: [o1, o2, o3], seededAt: Date())
        save(payload)
        return payload
    }

    // MARK: - Clear (optional)

    func clear() {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("⚠️ Clear error:", error)
        }
    }
}
