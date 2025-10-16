//
//  SheetsAndEditors.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

// MARK: - New Client

struct NewClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @State private var name: String = ""
    @State private var note: String = ""

    let onCreate: (String, String?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Client") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, note.isEmpty ? nil : note)
                        haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.colors.accent)
    }
}

// MARK: - Edit Client

struct EditClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var name: String
    @State private var note: String
    @State private var archived: Bool

    let onSave: (String, String?, Bool) -> Void

    init(client: Client, onSave: @escaping (String, String?, Bool) -> Void) {
        _name = State(initialValue: client.name)
        _note = State(initialValue: client.note ?? "")
        _archived = State(initialValue: client.isArchived)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Client") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Note (optional)", text: $note)
                }
                Section("Archive") {
                    Toggle("Archived", isOn: $archived)
                }
            }
            .navigationTitle("Edit Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, note.isEmpty ? nil : note, archived)
                        haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.colors.accent)
    }
}

// MARK: - New Order

struct NewOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var selectedClientId: UUID?
    @State private var useTemplate: Bool = true
    @State private var selectedTemplateIndex: Int = 0

    @State private var serviceName: String = ""
    @State private var serviceIcon: String = "scissors"
    @State private var serviceColorHex: String = "#FFA500"

    @State private var priceText: String = ""
    @State private var date: Date = Date()
    @State private var status: OrderStatus = .new
    @State private var note: String = ""

    let onCreate: (Client, ServiceTemplate?, String, String, String, Double, Date, String?, OrderStatus) -> Void

    init(prefilledClient: Client? = nil,
         prefilledTemplate: ServiceTemplate? = nil,
         onCreate: @escaping (Client, ServiceTemplate?, String, String, String, Double, Date, String?, OrderStatus) -> Void) {
        _selectedClientId = State(initialValue: prefilledClient?.id)
        if let tpl = prefilledTemplate {
            _useTemplate = State(initialValue: true)
            _serviceName = State(initialValue: tpl.name)
            _serviceIcon = State(initialValue: tpl.icon)
            _serviceColorHex = State(initialValue: tpl.colorHex)
            _priceText = State(initialValue: String(format: "%.0f", tpl.basePrice))
        }
        self.onCreate = onCreate
    }

    private var templates: [ServiceTemplate] { ServiceTemplate.defaultTemplates() }

    var body: some View {
        NavigationView {
            Form {
                Section("Client") {
                    Picker("Select", selection: Binding(get: {
                        selectedClientId ?? store.clients.first?.id
                    }, set: { selectedClientId = $0 })) {
                        ForEach(store.clients) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }

                Section("Service Source") {
                    Toggle("Use Template", isOn: $useTemplate)
                        .toggleStyle(SwitchToggleStyle(tint: theme.colors.accent))
                }

                if useTemplate {
                    Section("Template") {
                        Picker("Template", selection: $selectedTemplateIndex) {
                            ForEach(Array(templates.enumerated()), id: \.offset) { i, t in
                                Label(t.name, systemImage: t.icon).tag(i)
                            }
                        }
                        .onChange(of: selectedTemplateIndex) { idx in
                            let t = templates[idx]
                            serviceName = t.name
                            serviceIcon = t.icon
                            serviceColorHex = t.colorHex
                            priceText = String(format: "%.0f", t.basePrice)
                        }
                    }
                } else {
                    Section("Custom Service") {
                       // TextField("Name", text: $serviceName)
                        IconPicker(selection: $serviceIcon, serviceName: $serviceName)
//                        TextField("Color Hex (#RRGGBB)", text: $serviceColorHex)
//                            .textInputAutocapitalization(.never)
//                            .autocorrectionDisabled()
                    }
                }

                Section("Details") {
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Status", selection: $status) {
                        ForEach(OrderStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("New Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let clientId = selectedClientId ?? store.clients.first?.id,
                              let client = store.client(by: clientId)
                        else { return }

                        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
                        guard let price = Double(normalized), price > 0 else { return }

                        let tpl = useTemplate ? templates[safe: selectedTemplateIndex] : nil
                        let svcName = useTemplate ? (tpl?.name ?? serviceName) : serviceName
                        let svcIcon = useTemplate ? (tpl?.icon ?? serviceIcon) : serviceIcon
                        let svcColor = useTemplate ? (tpl?.colorHex ?? serviceColorHex) : serviceColorHex

                        guard !svcName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

                        onCreate(client, tpl, svcName, svcIcon, svcColor, price, date, note.isEmpty ? nil : note, status)
                        haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.colors.accent)
        .onAppear {
            if useTemplate, templates.indices.contains(selectedTemplateIndex) {
                let t = templates[selectedTemplateIndex]
                serviceName = t.name
                serviceIcon = t.icon
                serviceColorHex = t.colorHex
                if priceText.isEmpty { priceText = String(format: "%.0f", t.basePrice) }
            }
        }
    }
}

// MARK: - Edit Order

struct EditOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var serviceName: String
    @State private var serviceIcon: String
    @State private var serviceColorHex: String
    @State private var priceText: String
    @State private var date: Date
    @State private var status: OrderStatus
    @State private var note: String

    let onSave: (String, String, String, Double, Date, String?, OrderStatus) -> Void

    init(order: Order, onSave: @escaping (String, String, String, Double, Date, String?, OrderStatus) -> Void) {
        _serviceName = State(initialValue: order.serviceName)
        _serviceIcon = State(initialValue: order.serviceIcon)
        _serviceColorHex = State(initialValue: order.serviceColorHex)
        _priceText = State(initialValue: String(order.price))
        _date = State(initialValue: order.date)
        _status = State(initialValue: order.status)
        _note = State(initialValue: order.note ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Service") {
                    TextField("Name", text: $serviceName)
                    IconPicker(selection: $serviceIcon, serviceName: $serviceName)
                    TextField("Color Hex (#RRGGBB)", text: $serviceColorHex)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Details") {
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Status", selection: $status) {
                        ForEach(OrderStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Edit Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
                        guard let price = Double(normalized), price > 0 else { return }
                        onSave(trimmed, serviceIcon, serviceColorHex, price, date, note.isEmpty ? nil : note, status)
                        haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.colors.accent)
    }
}

private struct IconPicker: View {
    @EnvironmentObject private var theme: ThemeManager
    @Binding var selection: String
    @Binding var serviceName: String

    struct IconOption: Identifiable, Hashable {
        let id: String       // systemName
        let title: String    // human-friendly
    }

    private let options: [IconOption] = [
        .init(id: "scissors", title: "Haircut"),
        .init(id: "hand.raised.fill", title: "Massage"),
        .init(id: "person.text.rectangle", title: "Consulting"),
        .init(id: "camera.fill", title: "Photo"),
        .init(id: "dumbbell.fill", title: "Training"),
        .init(id: "sparkles", title: "Cleaning"),
        .init(id: "bag.fill", title: "Shopping"),
        .init(id: "wand.and.stars", title: "Makeup"),
        .init(id: "paintbrush.pointed.fill", title: "Painting"),
        .init(id: "leaf.fill", title: "Plants"),
        .init(id: "book.closed.fill", title: "Study"),
        .init(id: "globe", title: "Travel")
    ]

    private var current: IconOption {
        options.first(where: { $0.id == selection }) ?? options.first!
    }

    var body: some View {
        Picker("Icon", selection: Binding(
            get: {
                current
            },
            set: { new in
                selection = new.id
                handleIconChange(new)
            })
        ) {
            ForEach(options) { opt in
                Label(opt.title, systemImage: opt.id)
                    .tag(opt)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            if serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                serviceName = current.title
            }
        }
    }

    private func handleIconChange(_ new: IconOption) {
        let knownTitles = Set(options.map { $0.title })
        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || knownTitles.contains(trimmed) {
            serviceName = new.title
        }
    }
}

// MARK: - Safe subscript helper

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
