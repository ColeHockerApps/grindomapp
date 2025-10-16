//
//  BoardView.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct BoardView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var showSearch = false
    @State private var showQuickAdd = false

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // ВЕРТИКАЛЬНАЯ ДОСКА: колонки идут друг за другом
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: theme.metrics.spacingL) {
                        ForEach(store.statusOrder, id: \.self) { status in
                            ColumnView(status: status)
                                .padding(.horizontal, theme.metrics.spacingL)
                        }
                    }
                    .padding(.vertical, theme.metrics.spacingL)
                }
            }

            addButton
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddOrderSheet()
        }
    }

    private var header: some View {
        HStack(spacing: theme.metrics.spacing) {
            Text("Orders Board")
                .font(.title2).bold()
                .foregroundColor(theme.colors.textPrimary)

            Spacer()

            if showSearch {
                TextField("Search…", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation { showSearch.toggle() }
                haptics.selectionChanged()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.colors.textPrimary)
            }
        }
        .padding(.horizontal, theme.metrics.spacingL)
        .padding(.vertical, theme.metrics.spacing)
        .background(theme.colors.surface)
    }

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showQuickAdd = true
                    haptics.light()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2).bold()
                        .padding(14)
                        .background(theme.colors.accent)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .padding()
            }
        }
    }
}

// MARK: - Column

private struct ColumnView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    let status: OrderStatus

    var items: [Order] { store.orders(for: status) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacingS) {
            // Заголовок колонки
            HStack(spacing: theme.metrics.spacingS) {
                Image(systemName: ThemeIcons.forStatus(status))
                    .foregroundColor(theme.colors.forStatus(status))
                Text(status.rawValue)
                    .foregroundColor(theme.colors.textPrimary)
                    .font(.headline)
                Spacer()
                Text("\(items.count)")
                    .foregroundColor(theme.colors.textSecondary)
                    .font(.subheadline)
            }
            .padding(.horizontal, theme.metrics.spacingS)

            // Карточки
            LazyVStack(spacing: theme.metrics.spacing) {
                ForEach(items) { order in
                    OrderCard(order: order)
                        // Перетаскивание: активируется нажатием и удержанием
                        .onDrag {
                            haptics.medium()
                            return NSItemProvider(object: order.id.uuidString as NSString)
                        }
                        .contextMenu {
                            Button {
                                store.move(order, to: .new)
                            } label: { Label("Move to New", systemImage: ThemeIcons.forStatus(.new)) }

                            Button {
                                store.move(order, to: .inProgress)
                            } label: { Label("Move to In Progress", systemImage: ThemeIcons.forStatus(.inProgress)) }

                            Button {
                                store.move(order, to: .done)
                            } label: { Label("Move to Done", systemImage: ThemeIcons.forStatus(.done)) }

                            Button {
                                store.move(order, to: .canceled)
                            } label: { Label("Move to Canceled", systemImage: ThemeIcons.forStatus(.canceled)) }

                            Divider()

                            Button {
                                let next = Calendar.current.date(byAdding: .day, value: 1, to: order.date) ?? Date()
                                store.duplicateOrder(order, newDate: next)
                            } label: { Label("Duplicate for Tomorrow", systemImage: "plus.square.on.square") }

                            Button(role: .destructive) {
                                store.deleteOrder(order)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        // Доп. визуальный/тактильный отклик на long press
                        .onLongPressGesture(minimumDuration: 0.25) {
                            haptics.medium()
                        }
                }
            }
            .padding(theme.metrics.spacing)
            .background(theme.colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cornerRadius))
            // Приём дропа в конкретный статус
            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard
                        let s = object as? String,
                        let id = UUID(uuidString: s),
                        let dragged = store.allOrdersFiltered().first(where: { $0.id == id })
                    else { return }
                    Task { @MainActor in
                        store.move(dragged, to: status)
                    }
                }
                return true
            }
        }
    }
}

// MARK: - Card

private struct OrderCard: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    let order: Order

    var clientName: String {
        store.client(by: order.clientId)?.name ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacingS) {
            HStack(alignment: .center, spacing: theme.metrics.spacing) {
                ZStack {
                    Circle()
                        .fill(theme.colors.forStatus(order.status).opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: order.serviceIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.forStatus(order.status))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(clientName)
                        .foregroundColor(theme.colors.textPrimary)
                        .font(.headline)
                        .lineLimit(1)

                    Text(order.serviceName)
                        .foregroundColor(theme.colors.textSecondary)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Spacer()

                Text(store.formatCurrency(order.price))
                    .foregroundColor(theme.colors.textPrimary)
                    .fontWeight(.semibold)
            }

            HStack(spacing: theme.metrics.spacing) {
                Label {
                    Text(order.date, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .foregroundColor(theme.colors.textSecondary)
                .font(.footnote)

                Spacer()

                Circle()
                    .fill(theme.colors.forStatus(order.status))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(theme.metrics.spacingL)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cornerRadius))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .onTapGesture {
            store.cycleStatusForward(order)
            haptics.selectionChanged()
        }
    }
}

// MARK: - Quick Add Sheet



private struct QuickAddOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var selectedClientId: UUID?
    @State private var serviceName: String = ""
    @State private var icon: String = "scissors"
    @State private var priceText: String = ""
    @State private var date: Date = Date()
    @State private var status: OrderStatus = .new
    @State private var note: String = ""


    private struct IconOption: Identifiable, Hashable {
        let id: String      // SF Symbols id
        let title: String   //
    }
    private let iconOptions: [IconOption] = [
        .init(id: "scissors",                 title: "Haircut"),
        .init(id: "hand.raised.fill",         title: "Massage"),
        .init(id: "person.text.rectangle",    title: "Consulting"),
        .init(id: "camera.fill",              title: "Photo"),
        .init(id: "dumbbell.fill",            title: "Training"),
        .init(id: "sparkles",                 title: "Cleaning"),
        .init(id: "bag.fill",                 title: "Shopping"),
        .init(id: "wand.and.stars",           title: "Makeup")
    ]
    private var currentIconTitle: String {
        iconOptions.first(where: { $0.id == icon })?.title ?? icon
    }
    private var knownTitles: Set<String> { Set(iconOptions.map { $0.title }) }

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

                Section("Service") {
                    TextField("Name", text: $serviceName)


                    Picker("Icon: \(currentIconTitle)",
                           selection: Binding(
                            get: { iconOptions.first(where: { $0.id == icon }) ?? iconOptions[0] },
                            set: { new in
                                icon = new.id
                                // автоподстановка имени, если ещё не задано пользователем
                                let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.isEmpty || knownTitles.contains(trimmed) {
                                    serviceName = new.title
                                }
                            })) {
                        ForEach(iconOptions) { opt in
                            Label(opt.title, systemImage: opt.id).tag(opt)
                        }
                    }

                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                }

                Section("Details") {
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
                        let price = Double(normalized) ?? 0

                        guard !serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              price > 0
                        else { return }

                        store.addOrder(for: client,
                                       serviceName: serviceName,
                                       serviceIcon: icon,
                                       serviceColorHex: "",
                                       price: price,
                                       date: date,
                                       note: note.isEmpty ? nil : note,
                                       status: status)
                        haptics.success()
                        dismiss()
                    }
                }
            }
            .onAppear {

                if serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    serviceName = currentIconTitle
                }
            }
        }
    }
}
