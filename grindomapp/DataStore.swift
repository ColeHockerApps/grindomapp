//
//  DataStore.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine
import Foundation

@MainActor
final class DataStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var clients: [Client] = []
    @Published private(set) var orders: [Order] = []

    // UI filters / preferences
    @Published var searchQuery: String = ""
    @Published var selectedStatuses: Set<OrderStatus> = Set(OrderStatus.allCases)
    @Published var currencyCode: String = "USD"
    @Published var statusOrder: [OrderStatus] = [.new, .inProgress, .done, .canceled]

    // MARK: - Private

    private let store = LocalStore()

    // MARK: - Lifecycle

    func load() {
        let payload = store.load()
        clients = payload.clients
        orders  = payload.orders
    }

    private func persist() {
        store.save(.init(clients: clients, orders: orders, seededAt: Date()))
        objectWillChange.send()
    }

    // MARK: - Client CRUD

    func addClient(name: String, note: String?) {
        let c = Client(name: name, note: note)
        clients.append(c)
        persist()
    }

    func updateClient(_ client: Client, name: String, note: String?, archived: Bool) {
        guard let i = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[i].name = name
        clients[i].note = note
        clients[i].isArchived = archived
        persist()
    }

    func deleteClient(_ client: Client) {
        // удалить клиента и связанные заказы
        clients.removeAll { $0.id == client.id }
        orders.removeAll { $0.clientId == client.id }
        persist()
    }

    func client(by id: UUID) -> Client? {
        clients.first(where: { $0.id == id })
    }

    // MARK: - Order CRUD

    func addOrder(for client: Client,
                  serviceName: String,
                  serviceIcon: String,
                  serviceColorHex: String,
                  price: Double,
                  date: Date,
                  note: String?,
                  status: OrderStatus)
    {
        let o = Order(clientId: client.id,
                      serviceName: serviceName,
                      serviceIcon: serviceIcon,
                      serviceColorHex: serviceColorHex,
                      price: price,
                      date: date,
                      note: note,
                      status: status)
        orders.append(o)
        persist()
    }

    func addOrder(for client: Client,
                  template: ServiceTemplate,
                  priceOverride: Double? = nil,
                  date: Date,
                  note: String?,
                  status: OrderStatus)
    {
        addOrder(for: client,
                 serviceName: template.name,
                 serviceIcon: template.icon,
                 serviceColorHex: template.colorHex,
                 price: priceOverride ?? template.basePrice,
                 date: date,
                 note: note,
                 status: status)
    }

    func updateOrder(_ order: Order,
                     status: OrderStatus? = nil,
                     price: Double? = nil,
                     date: Date? = nil,
                     note: String? = nil)
    {
        guard let i = orders.firstIndex(where: { $0.id == order.id }) else { return }
        if let s = status { orders[i].status = s }
        if let p = price  { orders[i].price  = p }
        if let d = date   { orders[i].date   = d }
        if let n = note   { orders[i].note   = n }
        persist()
    }

    func deleteOrder(_ order: Order) {
        orders.removeAll { $0.id == order.id }
        persist()
    }

    func duplicateOrder(_ order: Order, newDate: Date) {
        var copy = order
        copy.id = UUID()
        copy.date = newDate
        copy.createdAt = Date()
        orders.append(copy)
        persist()
    }

    // MARK: - Queries / Views

    func orders(for status: OrderStatus) -> [Order] {
        orders
            .filter { $0.status == status }
            .filter { selectedStatuses.contains($0.status) }
            .filter { qMatches($0) }
            .sorted { lhs, rhs in
                // более свежие — ниже в колонке (по возрастанию даты)
                lhs.date < rhs.date
            }
    }

    func allOrdersFiltered() -> [Order] {
        orders
            .filter { selectedStatuses.contains($0.status) }
            .filter { qMatches($0) }
    }

    private func qMatches(_ order: Order) -> Bool {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        let q = searchQuery.lowercased()
        let clientName = client(by: order.clientId)?.name.lowercased() ?? ""
        return clientName.contains(q)
            || order.serviceName.lowercased().contains(q)
            || (order.note?.lowercased().contains(q) ?? false)
    }

    // MARK: - Status helpers

    func cycleStatusForward(_ order: Order) {
        let seq = statusOrder
        guard let idx = seq.firstIndex(of: order.status) else { return }
        let next = seq[(idx + 1) % seq.count]
        updateOrder(order, status: next)
    }

    func move(_ order: Order, to status: OrderStatus) {
        updateOrder(order, status: status)
    }

    // MARK: - Analytics

    func totals(periodDays: Int) -> (count: Int, revenue: Double, avg: Double) {
        let from = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? .distantPast
        let done = orders.filter { $0.status == .done && $0.date >= from }
        let sum = done.reduce(0) { $0 + $1.price }
        let c   = done.count
        let avg = c > 0 ? sum / Double(c) : 0
        return (c, sum, avg)
    }

    struct ServiceTotal: Identifiable {
        let id = UUID()
        let name: String
        let total: Double
    }

    func serviceBreakdown(periodDays: Int) -> [ServiceTotal] {
        let from = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? .distantPast
        let done = orders.filter { $0.status == .done && $0.date >= from }
        let grouped = Dictionary(grouping: done, by: { $0.serviceName })
        return grouped
            .map { (k, v) in ServiceTotal(name: k, total: v.reduce(0) { $0 + $1.price }) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Utilities

    func formatCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    func resetSearch() {
        searchQuery = ""
        selectedStatuses = Set(OrderStatus.allCases)
    }
}
