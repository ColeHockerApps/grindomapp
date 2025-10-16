//
//  SettingsView.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager

    @State private var currencyDraft: String = ""

    var body: some View {
        NavigationView {
            Form {
                appearanceSection
                hapticsSection
                businessSection
                statusesSection
                aboutSection
            }
            .onAppear {
                currencyDraft = store.currencyCode
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle(isOn: Binding(
                get: { theme.theme == .dark },
                set: { isDark in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isDark, theme.theme != .dark { theme.toggleTheme() }
                        if !isDark, theme.theme != .light { theme.toggleTheme() }
                        haptics.selectionChanged()
                    }
                }
            )) {
                Label("Dark Mode", systemImage: theme.theme == .dark ? "moon.fill" : "sun.max.fill")
            }
        }
    }

    private var hapticsSection: some View {
        Section("Haptics") {
            Toggle(isOn: $haptics.isEnabled) {
                Label("Enable Haptics", systemImage: "waveform.path")
            }
            .onChange(of: haptics.isEnabled) { enabled in
                if enabled { haptics.success() }
            }
        }
    }

    private var businessSection: some View {
        Section("Business") {
            HStack {
                Label("Currency Code", systemImage: "dollarsign.circle")
                Spacer()
                TextField("USD", text: $currencyDraft)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: currencyDraft) { new in
                        // keep it short and uppercase
                        let upper = new.uppercased()
                        currencyDraft = String(upper.prefix(6))
                        store.currencyCode = currencyDraft.isEmpty ? "USD" : currencyDraft
                    }
                    .frame(maxWidth: 140)
            }
            .foregroundColor(theme.colors.textPrimary)
        }
    }

    private var statusesSection: some View {
        Section {
            ForEach(store.statusOrder, id: \.self) { st in
                HStack(spacing: theme.metrics.spacing) {
                    Image(systemName: ThemeIcons.forStatus(st))
                        .foregroundColor(theme.colors.forStatus(st))
                        .frame(width: 22)
                    Text(st.rawValue)
                        .foregroundColor(theme.colors.textPrimary)
                    Spacer()
                }
            }
            .onMove { from, to in
                store.statusOrder.move(fromOffsets: from, toOffset: to)
                haptics.selectionChanged()
            }
        } header: {
            Text("Statuses Order")
        } footer: {
            Text("Drag to rearrange. Used on the Board.")
                .foregroundColor(theme.colors.textSecondary)
        }
        .environment(\.editMode, .constant(.active)) // always show reorder handles
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(theme.colors.accent)
                Text("Grindom Control")
                Spacer()
                Text(appVersionString)
                    .foregroundColor(.secondary)
            }
            Link(destination: URL(string: "https://www.termsfeed.com/live/ada136ce-66a4-4c3f-bbad-942f54220e94")!) {
                Label("Website", systemImage: "link")
            }
            .foregroundColor(.accentColor)
        }
    }

    // MARK: - Helpers

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
