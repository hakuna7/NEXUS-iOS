import SwiftUI

enum NexusTheme {
    static let background = Color(red: 0.027, green: 0.043, blue: 0.047)
    static let surface = Color(red: 0.067, green: 0.094, blue: 0.098)
    static let surfaceRaised = Color(red: 0.094, green: 0.125, blue: 0.125)
    static let line = Color.white.opacity(0.10)
    static let primary = Color(red: 0.329, green: 0.839, blue: 0.784)
    static let secondary = Color(red: 0.718, green: 0.953, blue: 0.420)
    static let warning = Color(red: 1.0, green: 0.478, blue: 0.420)
    static let muted = Color.white.opacity(0.58)
}

struct NexusPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NexusTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(NexusTheme.line, lineWidth: 1)
            }
    }
}

struct StatusPill: View {
    let title: String
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? NexusTheme.secondary : NexusTheme.warning)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(NexusTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String
    var color = NexusTheme.primary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(NexusTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(NexusTheme.muted)
        }
        .contentShape(Rectangle())
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NexusTheme.primary)
            }
        }
    }
}

private struct NexusBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                    }
                }
            }
    }
}

extension View {
    func nexusScreen() -> some View {
        self
            .foregroundStyle(Color.white)
            .background(NexusTheme.background.ignoresSafeArea())
            .tint(NexusTheme.primary)
    }

    func nexusBackButton() -> some View {
        modifier(NexusBackButtonModifier())
    }
}
