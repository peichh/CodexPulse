import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    var body: some View {
        Form {
            Text("Codex rate limits")
                .font(.headline)
            Text("Reads usage remaining from the latest token_count event in Codex session logs.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .frame(width: 360)
    }
}
