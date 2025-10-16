//
//  ClientsView.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

struct ClientsView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var query: String = ""
    @State private var showNewClient: Bool = false

    private var filtered: [Client] {
        let base = store.clients.filter { !$0.isArchived }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return base
            .filter { $0.name.localizedCaseInsensitiveContains(query) || ($0.note ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filtered) { client in
                                NavigationLink(destination: ClientDetailView(client: client)) {
                                    ClientRow(client: client)
                                        .listRowBackground(theme.colors.surface)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        store.updateClient(client, name: client.name, note: client.note, archived: true)
                                        haptics.success()
                                    } label: {
                                        Label("Archive", systemImage: "archivebox.fill")
                                    }
                                    .tint(.gray)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }

                addButton
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showNewClient) {
            NewClientSheet { name, note in
                store.addClient(name: name, note: note)
                haptics.success()
            }
        }
    }

    private var header: some View {
        HStack(spacing: theme.metrics.spacing) {
            Text("Clients")
                .font(.title2).bold()
                .foregroundColor(theme.colors.textPrimary)

            Spacer()

            TextField("Search…", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
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
                    showNewClient = true
                    haptics.light()
                } label: {
                    Image(systemName: "person.badge.plus")
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

    private var emptyState: some View {
        VStack(spacing: theme.metrics.spacing) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(theme.colors.textSecondary)
                .padding(.top, 40)
            Text("No clients yet")
                .foregroundColor(theme.colors.textPrimary)
                .font(.headline)
            Text("Tap the + button to add your first client.")
                .foregroundColor(theme.colors.textSecondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Row

private struct ClientRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let client: Client

    var body: some View {
        HStack(spacing: theme.metrics.spacing) {
            ZStack {
                Circle()
                    .fill(theme.colors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .foregroundColor(theme.colors.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .foregroundColor(theme.colors.textPrimary)
                    .font(.headline)
                    .lineLimit(1)
                if let note = client.note, !note.isEmpty {
                    Text(note)
                        .foregroundColor(theme.colors.textSecondary)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(theme.colors.textSecondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Detail



private struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var showEdit: Bool = false
    let client: Client

    private var orders: [Order] {
        store.orders
            .filter { $0.clientId == client.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if let note = client.note, !note.isEmpty {
                    Text(note)
                        .foregroundColor(theme.colors.textSecondary)
                        .padding(.horizontal, theme.metrics.spacingL)
                        .padding(.vertical, theme.metrics.spacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.colors.surface)
                }

                if orders.isEmpty {
                    VStack(spacing: theme.metrics.spacing) {
                        Spacer(minLength: 40)
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 42))
                            .foregroundColor(theme.colors.textSecondary)
                        Text("No orders yet")
                            .foregroundColor(theme.colors.textPrimary)
                            .font(.headline)
                        Text("Create an order from the Board tab.")
                            .foregroundColor(theme.colors.textSecondary)
                            .font(.subheadline)
                        Spacer()
                    }
                } else {
                    List {
                        Section("Orders") {
                            ForEach(orders) { o in
                                HStack(spacing: theme.metrics.spacing) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.colors.forStatus(o.status).opacity(0.18))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: o.serviceIcon)
                                            .foregroundColor(theme.colors.forStatus(o.status))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(o.serviceName) · \(store.formatCurrency(o.price))")
                                            .foregroundColor(theme.colors.textPrimary)
                                        Text(o.date, style: .date)
                                            .foregroundColor(theme.colors.textSecondary)
                                            .font(.footnote)
                                    }
                                    Spacer()
                                    Text(o.status.rawValue)
                                        .foregroundColor(theme.colors.forStatus(o.status))
                                        .font(.footnote)
                                }
                                .listRowBackground(theme.colors.surface)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditClientSheet(client: client) { name, note, archived in
                store.updateClient(client, name: name, note: note, archived: archived)
                haptics.success()
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(spacing: theme.metrics.spacing) {
            // КНОПКА НАЗАД / ЗАКРЫТЬ
            Button {
                haptics.selectionChanged()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(theme.colors.textPrimary)
            }

            Spacer()

            Text(client.name)
                .font(.title3).bold()
                .foregroundColor(theme.colors.textPrimary)

            Spacer()

            Button {
                showEdit = true
                haptics.selectionChanged()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.accent)
        }
        .padding(.horizontal, theme.metrics.spacingL)
        .padding(.vertical, theme.metrics.spacing)
        .background(theme.colors.surface)
    }
}

// MARK: - New Client Sheet (без дублирования в других файлах)


