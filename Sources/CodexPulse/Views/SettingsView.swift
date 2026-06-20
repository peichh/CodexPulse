import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Codex rate limits")
                .font(.headline)
            Text("Reads usage remaining from the latest token_count event in Codex session logs.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360)
    }
}
