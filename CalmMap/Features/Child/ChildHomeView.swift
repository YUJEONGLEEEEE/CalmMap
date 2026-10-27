import SwiftData
import SwiftUI

struct ChildHomeView: View {
    @Environment(SensoryMapModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Query(sort: \ChildProfile.createdAt) private var children: [ChildProfile]
    @AppStorage(ChildProfile.activeKey) private var activeChildID = ""
    @State private var editing: EditorTarget?
    @State private var selectedPlace: SensoryMapModel.Entry?

    private enum EditorTarget: Identifiable {
        case new
        case edit(ChildProfile)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let child): child.id.uuidString
            }
        }
    }

    private var activeChild: ChildProfile? {
        children.first { $0.id.uuidString == activeChildID }
    }

    private var rated: [SensoryMapModel.Entry] {
        model.entries.filter { $0.reading != nil }
    }

    private var calmPicks: [SensoryMapModel.Entry] {
        Array(rated.filter { $0.reading?.tier == .calm }.sorted { score($0) < score($1) }.prefix(5))
    }

    private var avoidPicks: [SensoryMapModel.Entry] {
        Array(rated.filter { $0.reading?.tier == .intense }.sorted { score($0) > score($1) }.prefix(3))
    }

    private var shifted: [SensoryMapModel.Entry] {
        rated.filter { entry in
            guard let reading = entry.reading else { return false }
            return reading.tier > reading.baseTier
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if children.isEmpty {
                        intro
                    } else {
                        childPicker
                        if let activeChild {
                            profileCard(activeChild)
                            recommendations(for: activeChild)
                        } else {
                            generalNotice
                        }
                    }
                }
                .padding()
            }
            .background(CalmBackdrop())
            .navigationTitle("우리 아이")
            .toolbar {
                if !children.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editing = .new
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("아이 추가")
                    }
                }
            }
            .sheet(item: $editing) { target in
                switch target {
                case .new: ChildProfileEditor(child: nil)
                case .edit(let child): ChildProfileEditor(child: child)
                }
            }
            .sheet(item: $selectedPlace) { entry in
                PlaceDetailView(placeCode: entry.place.code)
                    .presentationDetents([.medium, .large])
                    .presentationBackground { CalmBackdrop() }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "figure.and.child.holdinghands")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.calmInk)
            Text("아이에게 맞춘 지도")
                .font(.title2.bold())
            Text("아이마다 힘들어하는 것이 달라요.\n사람 붐빔, 큰 소리, 안내음이나 사이렌 같은 사운드 종류, 조명까지 알려 주면 지도와 시간 추천을 우리 아이 기준으로 다시 계산해요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("같은 장소도 아이에 따라 무던함 · 보통 · 붐빔이 달라져요", systemImage: "map")
                Label("측정한 곳은 실제로 들린 소리 종류로 계산해요", systemImage: "waveform")
                Label("아이 정보는 이 기기에만 저장돼요", systemImage: "lock.shield")
            }
            .font(.footnote)
            Button {
                editing = .new
            } label: {
                Label("아이 프로필 만들기", systemImage: "plus")
            }
            .buttonStyle(.calmPrimary)
            .padding(.top, 4)
        }
        .calmCard(padding: 20)
    }

    private var childPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "일반 기준", systemImage: "map", isOn: activeChild == nil) {
                    activeChildID = ""
                }
                ForEach(children) { child in
                    chip(title: child.name, systemImage: "figure.child", isOn: child.id == activeChild?.id) {
                        activeChildID = child.id.uuidString
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.calmOnInk : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isOn ? Color.calmInk.opacity(0.85) : Color.clear, in: Capsule())
                .calmGlass(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var generalNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지금은 일반 기준 지도예요")
                .font(.headline)
            Text("위에서 아이를 고르면 지도와 장소 정보가 그 아이 기준으로 바뀌어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .calmCard()
    }

    private func profileCard(_ child: ChildProfile) -> some View {
        let profile = child.sensoryProfile
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.title2.bold())
                    Text("지도와 시간 추천이 \(child.name) 기준이에요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("수정") {
                    editing = .edit(child)
                }
                .buttonStyle(.bordered)
                .tint(Color.calmInk)
            }
            if profile.highlights.isEmpty {
                Text("아직 예민한 항목을 고르지 않았어요. 수정에서 힘들어하는 것을 알려 주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                FlexibleChips(items: profile.highlights)
            }
            if !child.note.isEmpty {
                Label(child.note, systemImage: "note.text")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .calmCard()
    }

    @ViewBuilder
    private func recommendations(for child: ChildProfile) -> some View {
        if rated.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("장소 정보를 불러오는 중이에요")
                    .font(.headline)
                Text("지도 탭에서 새로고침하면 추천이 나타나요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .calmCard()
        } else {
            placeSection(
                title: "지금 \(child.name)에게 무던한 곳",
                empty: "지금은 무던한 곳이 없어요. 장소를 눌러 덜 붐비는 시간을 확인해 보세요.",
                entries: calmPicks
            )
            if !avoidPicks.isEmpty {
                placeSection(title: "지금은 피하면 좋은 곳", empty: "", entries: avoidPicks)
            }
            if !shifted.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(child.name) 기준으로 더 버거워진 곳 \(shifted.count)곳", systemImage: "arrow.up.right")
                        .font(.headline)
                    Text("일반 지도에서는 한 단계 낮게 보이지만, \(child.name.particle("이", "가")) 힘들어하는 요소 때문에 점수가 올라간 곳이에요. 지도에서 바로 확인할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("지도에서 보기") {
                        router.selectedTab = .map
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.calmInk)
                }
                .calmCard()
            }
        }
    }

    private func placeSection(title: String, empty: String, entries: [SensoryMapModel.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 6)
            if entries.isEmpty {
                Text(empty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                Button {
                    selectedPlace = entry
                } label: {
                    placeRow(entry)
                }
                .buttonStyle(.plain)
                if entry.id != entries.last?.id {
                    Divider()
                }
            }
        }
        .calmCard()
    }

    private func placeRow(_ entry: SensoryMapModel.Entry) -> some View {
        HStack(spacing: 12) {
            if let reading = entry.reading {
                TierBadge(tier: reading.tier, size: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.place.name)
                    .font(.subheadline.weight(.medium))
                Text(entry.place.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(score(entry).rounded()))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func score(_ entry: SensoryMapModel.Entry) -> Double {
        entry.reading?.score ?? 0
    }
}

struct FlexibleChips: View {
    let items: [String]

    var body: some View {
        ChipLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.calmTint, in: Capsule())
            }
        }
    }
}

struct ChipLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], needed, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
