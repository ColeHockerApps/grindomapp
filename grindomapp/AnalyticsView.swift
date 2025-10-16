//
//  AnalyticsView.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

struct AnalyticsView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var periodDays: Int = 30

    var body: some View {
        NavigationView {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: theme.metrics.spacingL) {
                        header

                        // Totals
                        let totals = store.totals(periodDays: periodDays)
                        HStack(spacing: theme.metrics.spacing) {
                            MetricCard(title: "Orders",
                                       value: "\(totals.count)",
                                       subtitle: periodSubtitle)
                            MetricCard(title: "Revenue",
                                       value: totals.revenue.formatted(.currency(code: store.currencyCode)),
                                       subtitle: periodSubtitle)
                            MetricCard(title: "Average",
                                       value: totals.avg.formatted(.currency(code: store.currencyCode)),
                                       subtitle: periodSubtitle)
                        }
                        .padding(.horizontal, theme.metrics.spacingL)

                        // Trend
                        VStack(alignment: .leading, spacing: theme.metrics.spacing) {
                            Text("Revenue Trend")
                                .foregroundColor(theme.colors.textPrimary)
                                .font(.headline)
                                .padding(.horizontal, theme.metrics.spacingL)

                            RevenueBars(periodDays: periodDays)
                                .frame(height: 140)
                                .padding(.horizontal, theme.metrics.spacingL)
                        }

                        // Breakdown by Service
                        VStack(alignment: .leading, spacing: theme.metrics.spacing) {
                            Text("By Service")
                                .foregroundColor(theme.colors.textPrimary)
                                .font(.headline)
                                .padding(.horizontal, theme.metrics.spacingL)

                            let items = store.serviceBreakdown(periodDays: periodDays)
                            if items.isEmpty {
                                Text("No data for the selected period.")
                                    .foregroundColor(theme.colors.textSecondary)
                                    .font(.subheadline)
                                    .padding(.horizontal, theme.metrics.spacingL)
                                    .padding(.bottom, 8)
                            } else {
                                VStack(spacing: theme.metrics.spacing) {
                                    ForEach(items.indices, id: \.self) { i in
                                        let item = items[i]
                                        ServiceRow(rank: i + 1,
                                                   name: item.name,
                                                   value: item.total,
                                                   maxValue: items.first?.total ?? item.total)
                                    }
                                }
                                .padding(.horizontal, theme.metrics.spacingL)
                            }
                        }

                        Spacer(minLength: 16)
                    }
                    .padding(.top, theme.metrics.spacing)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var periodSubtitle: String {
        switch periodDays {
        case 7: return "last 7d"
        case 90: return "last 90d"
        default: return "last 30d"
        }
    }

    private var header: some View {
        HStack(spacing: theme.metrics.spacing) {
            Text("Analytics")
                .font(.title2).bold()
                .foregroundColor(theme.colors.textPrimary)
            Spacer()
            Picker("", selection: $periodDays) {
                Text("7d").tag(7)
                Text("30d").tag(30)
                Text("90d").tag(90)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: periodDays) { _ in
                haptics.selectionChanged()
            }
        }
        .padding(.horizontal, theme.metrics.spacingL)
        .padding(.vertical, theme.metrics.spacing)
        .background(theme.colors.surface)
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(theme.colors.textSecondary)
                .font(.footnote)
            Text(value)
                .foregroundColor(theme.colors.textPrimary)
                .font(.title3).bold()
            Text(subtitle)
                .foregroundColor(theme.colors.textSecondary)
                .font(.caption)
        }
        .padding(theme.metrics.spacingL)
        .frame(maxWidth: .infinity)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Revenue Bars (simple per-day bar chart, offline)

private struct RevenueBars: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    let periodDays: Int

    private var days: [Date] {
        var result: [Date] = []
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(periodDays - 1), to: Date()) ?? Date())
        for i in 0..<periodDays {
            if let d = cal.date(byAdding: .day, value: i, to: start) {
                result.append(d)
            }
        }
        return result
    }

    private var series: [Double] {
        let cal = Calendar.current
        let done = store.orders.filter { $0.status == .done }
        return days.map { day in
            let sum = done
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.price }
            return sum
        }
    }

    var body: some View {
        GeometryReader { geo in
            let maxV = max(series.max() ?? 1, 1)
            let barW = max(2, geo.size.width / CGFloat(series.count) * 0.6)
            let spacing = max(1, (geo.size.width / CGFloat(series.count)) - barW)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(series.indices, id: \.self) { i in
                    let h = CGFloat(series[i] / maxV) * max(geo.size.height - 20, 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.colors.accent)
                        .frame(width: barW, height: max(1, h))
                        .accessibilityLabel(Text("Day \(i+1), \(series[i], format: .currency(code: store.currencyCode))"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.vertical, 8)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cornerRadius))
            .overlay(alignment: .topLeading) {
                if let maxVal = series.max(), maxVal > 0 {
                    Text("Max \(maxVal.formatted(.currency(code: store.currencyCode)))")
                        .font(.caption2)
                        .foregroundColor(theme.colors.textSecondary)
                        .padding(6)
                }
            }
        }
    }
}

// MARK: - Service Row

private struct ServiceRow: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager

    let rank: Int
    let name: String
    let value: Double
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(rank). \(name)")
                    .foregroundColor(theme.colors.textPrimary)
                Spacer()
                Text(value.formatted(.currency(code: store.currencyCode)))
                    .foregroundColor(theme.colors.textSecondary)
            }
            ProgressView(value: maxValue > 0 ? value / maxValue : 0)
                .tint(theme.colors.accent)
        }
        .padding(.vertical, 4)
    }
}
