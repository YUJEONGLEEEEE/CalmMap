import SwiftUI

struct StepSlider<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    private let thumbWidth: CGFloat = 40
    private let thumbHeight: CGFloat = 26

    private var index: Int {
        options.firstIndex(of: selection) ?? 0
    }

    private func fraction(_ position: Int) -> CGFloat {
        options.count > 1 ? CGFloat(position) / CGFloat(options.count - 1) : 0
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let travel = max(proxy.size.width - thumbWidth, 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(.white)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .shadow(color: .black.opacity(0.12), radius: 6.5, y: 6)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 0.5)
                        .offset(x: travel * fraction(index))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let raw = (value.location.x - thumbWidth / 2) / travel
                            let step = Int((min(max(raw, 0), 1) * CGFloat(options.count - 1)).rounded())
                            if options[step] != selection {
                                selection = options[step]
                            }
                        }
                )
            }
            .frame(height: thumbHeight)

            GeometryReader { proxy in
                let travel = proxy.size.width - thumbWidth
                ForEach(options.indices, id: \.self) { position in
                    if position != index {
                        Circle()
                            .fill(Color(.tertiaryLabel))
                            .frame(width: 4, height: 4)
                            .position(x: thumbWidth / 2 + travel * fraction(position), y: 2)
                    }
                }
            }
            .frame(height: 4)

            ZStack {
                ForEach(options.indices, id: \.self) { position in
                    Button {
                        selection = options[position]
                    } label: {
                        Text(label(options[position]))
                            .font(.footnote.weight(position == index ? .semibold : .medium))
                            .foregroundStyle(position == index ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: alignment(for: position))
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if index < options.count - 1 { selection = options[index + 1] }
            case .decrement:
                if index > 0 { selection = options[index - 1] }
            @unknown default:
                break
            }
        }
    }

    private func alignment(for position: Int) -> Alignment {
        if position == 0 { return .leading }
        if position == options.count - 1 { return .trailing }
        return .center
    }
}

#Preview {
    @Previewable @State var level = Sensitivity.high
    StepSlider(title: "사람 붐빔", options: Sensitivity.allCases, selection: $level) { $0.title }
        .padding()
}
