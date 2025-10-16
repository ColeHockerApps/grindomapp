//
//  CalendarView.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

struct CalendarView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var monthAnchor: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var showNewOrder = false

    private let cal = Calendar.current

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 32, maximum: .infinity), spacing: theme.metrics.spacingS), count: 7)
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    weekdayHeader
                        .padding(.horizontal, theme.metrics.spacingL)
                        .padding(.vertical, theme.metrics.spacingS)

                    ScrollView {
                        LazyVGrid(columns: grid, spacing: theme.metrics.spacingS) {
                            ForEach(monthCells(), id: \.self) { cell in
                                DayCell(
                                    cell: cell,
                                    monthAnchor: monthAnchor,
                                    orders: orders(on: cell.date),
                                    selectedDate: selectedDate,
                                    onTap: { date in
                                        selectedDate = date
                                        haptics.selectionChanged()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, theme.metrics.spacingL)
                        .padding(.bottom, theme.metrics.spacingL)

                        if let selected = selectedDate {
                            DayOrdersSection(
                                date: selected,
                                orders: orders(on: selected),
                                onAdd: { showNewOrder = true }
                            )
                            .padding(.horizontal, theme.metrics.spacingL)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                addButton
            }
            .sheet(isPresented: $showNewOrder) {
                NewOrderSheet { client, template, name, icon, colorHex, price, date, note, status in
                    if let tpl = template {
                        store.addOrder(for: client,
                                       template: tpl,
                                       priceOverride: price,
                                       date: date,
                                       note: note,
                                       status: status)
                    } else {
                        store.addOrder(for: client,
                                       serviceName: name,
                                       serviceIcon: icon,
                                       serviceColorHex: colorHex,
                                       price: price,
                                       date: date,
                                       note: note,
                                       status: status)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.metrics.spacing) {
            Button {
                monthAnchor = cal.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                selectedDate = nil
                haptics.selectionChanged()
            } label: { Image(systemName: "chevron.left") }

            Spacer()

            Text(monthTitle(for: monthAnchor))
                .font(.title2).bold()
                .foregroundColor(theme.colors.textPrimary)

            Spacer()

            Button {
                monthAnchor = cal.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                selectedDate = nil
                haptics.selectionChanged()
            } label: { Image(systemName: "chevron.right") }
        }
        .foregroundColor(theme.colors.textPrimary)
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
                    showNewOrder = true
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

    private var weekdayHeader: some View {
        let symbols = cal.shortWeekdaySymbols
        let firstWeekday = cal.firstWeekday
        let rotated = Array(symbols[firstWeekday-1..<symbols.count] + symbols[0..<firstWeekday-1])

        return HStack {
            ForEach(rotated, id: \.self) { s in
                Text(s.uppercased())
                    .font(.caption2)
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Data

    private func monthCells() -> [DayCellModel] {
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let startOfMonth = cal.date(from: comps) else { return [] }

        let weekday = cal.component(.weekday, from: startOfMonth)
        let shift = (weekday - cal.firstWeekday + 7) % 7

        let range = cal.range(of: .day, in: .month, for: startOfMonth) ?? (1..<31)
        let daysCount = range.count

        var cells: [DayCellModel] = []

        for i in 0..<shift {
            let date = cal.date(byAdding: .day, value: i - shift, to: startOfMonth) ?? startOfMonth
            cells.append(.init(date: date, isCurrentMonth: false))
        }

        for d in 0..<daysCount {
            let date = cal.date(byAdding: .day, value: d, to: startOfMonth) ?? startOfMonth
            cells.append(.init(date: date, isCurrentMonth: true))
        }

        while cells.count % 7 != 0 {
            let last = cells.last?.date ?? startOfMonth
            let date = cal.date(byAdding: .day, value: 1, to: last) ?? last
            cells.append(.init(date: date, isCurrentMonth: false))
        }
        return cells
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }

    private func orders(on day: Date) -> [Order] {
        store.orders.filter { cal.isDate($0.date, inSameDayAs: day) }
    }
}

// MARK: - Models

private struct DayCellModel: Hashable {
    let date: Date
    let isCurrentMonth: Bool
}

// MARK: - Day Cell

private struct DayCell: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: DataStore

    let cell: DayCellModel
    let monthAnchor: Date
    let orders: [Order]
    let selectedDate: Date?
    let onTap: (Date) -> Void

    private let cal = Calendar.current

    var isToday: Bool { cal.isDateInToday(cell.date) }
    var isWeekend: Bool {
        let w = cal.component(.weekday, from: cell.date)
        return w == 1 || w == 7
    }
    var isSelected: Bool {
        guard let selectedDate else { return false }
        return cal.isDate(cell.date, inSameDayAs: selectedDate)
    }

    var body: some View {
        Button {
            onTap(cell.date)
        } label: {
            VStack(spacing: 6) {
                Text("\(cal.component(.day, from: cell.date))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(dayTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 3) {
                    if has(.new)        { dot(theme.colors.forStatus(.new)) }
                    if has(.inProgress) { dot(theme.colors.forStatus(.inProgress)) }
                    if has(.done)       { dot(theme.colors.forStatus(.done)) }
                    if has(.canceled)   { dot(theme.colors.forStatus(.canceled)) }
                }
                .frame(height: 8)

                if totalDone > 0 {
                    Text(store.formatCurrency(totalDone))
                        .font(.caption2)
                        .foregroundColor(theme.colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Spacer(minLength: 0).frame(height: 0)
                }
            }
            .padding(10)
            .frame(minHeight: 64)
            .background(backgroundShape)
        }
        .buttonStyle(.plain)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }

    private var backgroundShape: some View {
        let baseFill: Color
        if isSelected {
            baseFill = theme.colors.accent.opacity(0.22)
        } else if cell.isCurrentMonth {
            baseFill = theme.colors.surface.opacity(isToday ? 0.4 : 0.2)
        } else {
            baseFill = theme.colors.surface.opacity(0.08)
        }

        return RoundedRectangle(cornerRadius: 10)
            .fill(baseFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.colors.accent : (isToday ? theme.colors.accent : .clear),
                            lineWidth: isSelected ? 2 : (isToday ? 1 : 0))
            )
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if isToday { return theme.colors.textPrimary }
        if !cell.isCurrentMonth { return theme.colors.textSecondary.opacity(0.5) }
        return isWeekend ? theme.colors.textPrimary.opacity(0.85) : theme.colors.textPrimary
    }

    private func has(_ status: OrderStatus) -> Bool {
        orders.contains { $0.status == status }
    }

    private var totalDone: Double {
        orders.filter { $0.status == .done }.reduce(0) { $0 + $1.price }
    }
}

// MARK: - Day Orders Section

private struct DayOrdersSection: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    let date: Date
    let orders: [Order]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.spacing) {
            HStack {
                Text(dateFormatted(date))
                    .font(.headline)
                    .foregroundColor(theme.colors.textPrimary)
                Spacer()
                Button {
                    onAdd(); haptics.light()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.accent)
            }

            if orders.isEmpty {
                Text("No orders on this day")
                    .foregroundColor(theme.colors.textSecondary)
                    .font(.subheadline)
            } else {
                ForEach(orders.sorted(by: { $0.date < $1.date })) { o in
                    HStack(spacing: theme.metrics.spacing) {
                        ZStack {
                            Circle()
                                .fill(theme.colors.forStatus(o.status).opacity(0.18))
                                .frame(width: 30, height: 30)
                            Image(systemName: o.serviceIcon)
                                .foregroundColor(theme.colors.forStatus(o.status))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clientName(for: o))
                                .foregroundColor(theme.colors.textPrimary)
                                .font(.subheadline.weight(.semibold))
                            Text(o.serviceName)
                                .foregroundColor(theme.colors.textSecondary)
                                .font(.caption)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(store.formatCurrency(o.price))
                                .foregroundColor(theme.colors.textPrimary)
                                .font(.subheadline.weight(.semibold))
                            Text(timeFormatted(o.date))
                                .foregroundColor(theme.colors.textSecondary)
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 6)
                    .background(theme.colors.surface.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.vertical, theme.metrics.spacingL)
        .background(theme.colors.surface.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func clientName(for order: Order) -> String {
        store.client(by: order.clientId)?.name ?? "Unknown"
    }

    private func dateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: date)
    }

    private func timeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
