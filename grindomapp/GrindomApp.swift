//
//  GrindomApp.swift
//  GrindomApp
//
//  Created on 2025-10-16
//

import SwiftUI
import Combine

@main
struct GrindomApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var theme = ThemeManager()
    @StateObject private var haptics = HapticsManager()

    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if OrientationGate.allowAll {
                return [.portrait, .landscapeLeft, .landscapeRight]
            } else {
                return [.portrait]
            }
        }
    }
    
    
    init()
    {

        NotificationCenter.default.post(name: Notification.Name("art.icon.loading.start"), object: nil)
        IconSettings.shared.attach()

    }
    
    
    var body: some Scene {
        
        WindowGroup {
            TabSettingsView{
                RootTabView()
                    .environmentObject(store)
                    .environmentObject(theme)
                    .environmentObject(haptics)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        store.load()
                        haptics.prepare()
                    }
                    .onAppear {
                                        
                        ReviewNudge.shared.schedule(after: 60)
                                 
                    }
                
            }
            
            .onAppear {
                OrientationGate.allowAll = false
            }
            
        }
        
        
        
        
        
    }
}

private struct RootTabView: View {
    @EnvironmentObject private var haptics: HapticsManager
    @State private var selectedTab: Tab = .board

    enum Tab: Hashable {
        case board
        case clients
        case calendar
        case analytics
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            BoardView()
                .tag(Tab.board)
                .tabItem {
                    Label("Board", systemImage: "square.grid.3x3.fill")
                }

            ClientsView()
                .tag(Tab.clients)
                .tabItem {
                    Label("Clients", systemImage: "person.2.fill")
                }

            CalendarView()
                .tag(Tab.calendar)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            
            AnalyticsView()
                .tag(Tab.analytics)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }

            SettingsView()
                .tag(Tab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .onChange(of: selectedTab) { _ in
            haptics.light()
        }
    }
}
