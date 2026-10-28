import SwiftUI

// Rows and small controls shared by the panel and the Settings window.

/// An inset, frosted group of rows, like the grouped lists in System Settings.
struct GlassGroup<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(colorScheme == .dark ? 0.06 : 0.5), lineWidth: 0.5))
    }

    private var fill: Color {
        if let tint { return tint.opacity(0.14) }
        return colorScheme == .dark ? .white.opacity(0.06) : .white.opacity(0.45)
    }
}

struct Row<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 38)
    }
}

struct DisclosureRow<Trailing: View>: View {
    let icon: String
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            Row(icon: icon, title: title) {
                trailing()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SmallSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
    }
}

struct KeyCap: View {
    let keys: String
    var onAccent = false

    init(_ keys: String, onAccent: Bool = false) {
        self.keys = keys
        self.onAccent = onAccent
    }

    var body: some View {
        Text(keys)
            .font(.caption.weight(.medium))
            .foregroundStyle(onAccent ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(onAccent ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct MarginSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// Snaps to 10 pt without `Slider(step:)`, which draws a tick mark for every step.
    private var snapped: Binding<Double> {
        Binding(get: { value }, set: { value = ($0 / 10).rounded() * 10 })
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Slider(value: snapped, in: range)
                .controlSize(.small)
            Text("\(Int(value))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .font(.callout)
    }
}
