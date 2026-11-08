import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "sparkles") }
                .tag(AppTab.home)
            StudioView()
                .tabItem { Label("Studio", systemImage: "paintbrush.pointed.fill") }
                .tag(AppTab.studio)
            LibraryView()
                .tabItem { Label("Themes", systemImage: "square.stack.3d.up.fill") }
                .tag(AppTab.library)
            MyDesignsView()
                .tabItem { Label("My Designs", systemImage: "folder.fill") }
                .tag(AppTab.designs)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .modifier(ToastOverlay(message: $model.toast))
        .fullScreenCover(isPresented: $model.showCharging) {
            ChargingScreen(theme: model.activeTheme)
        }
    }
}
