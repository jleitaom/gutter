import SwiftUI

/// Capsule segmented control with a sliding selection. Used for displays and gap presets;
/// nothing is highlighted when the selection matches no option.
struct CapsulePicker<Value: Hashable>: View {
    /// What VoiceOver calls the group, e.g. "Display".
    let title: String
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    @Namespace private var highlight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = selection == option.value
                Button {
                    withAnimation(.snappy) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(selected ? .primary : .secondary)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(.white.opacity(colorScheme == .dark ? 0.18 : 0.9))
                                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.primary.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// A full-width accent capsule with a soft top highlight, like the glass buttons in macOS 26.
struct CapsuleProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                Capsule()
                    .fill(Color.accentColor)
                    .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)))
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .accentColor.opacity(isEnabled ? 0.35 : 0), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// A quieter capsule for secondary actions next to the prominent one.
struct CapsuleSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
