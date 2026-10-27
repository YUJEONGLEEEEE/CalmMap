import SwiftData
import SwiftUI

struct MeasureView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var meter = SoundMeter()
    @State private var location = LocationProvider()
    @State private var place: Place?
    @State private var showingPlacePicker = false
    @State private var brightLight = false
    @State private var flicker = false

    private let places = Place.loadBundled()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacyNote
                    placeSelector
                    switch meter.state {
                    case .idle, .failed:
                        startSection
                    case .denied:
                        deniedSection
                    case .measuring:
                        measuringSection
                    case .finished:
                        if let summary = meter.summary {
                            summarySection(summary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("소리 측정")
            .sheet(isPresented: $showingPlacePicker) {
                PlacePickerView(places: places.sorted(near: location.location)) { picked in
                    place = picked
                    showingPlacePicker = false
                }
            }
            .onAppear {
                location.requestOnce()
                adoptRouterPlace()
            }
            .onChange(of: router.measurePlace) {
                adoptRouterPlace()
            }
            .onChange(of: meter.interruptionCount) {
                toasts.show("다른 소리가 끼어들어 측정이 중단됐어요. 다시 시작해 주세요.", style: .warning, duration: .seconds(4))
            }
            .onChange(of: location.location) {
                if place == nil {
                    place = places.sorted(near: location.location).first
                }
            }
        }
    }

    private var privacyNote: some View {
        Label("소리는 기기 안에서만 분석해요. 녹음 파일은 저장하거나 전송하지 않아요.", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.calmInk.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var placeSelector: some View {
        Button {
            showingPlacePicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("측정 장소").font(.caption).foregroundStyle(.secondary)
                    Text(place?.name ?? "장소를 골라 주세요").font(.headline)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(meter.state == .measuring)
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .failed(let message) = meter.state {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Text("\(Int(SoundMeter.duration))초 동안 주변 소리의 종류와 크기를 살펴요. 폰을 손에 들고 평소처럼 서 있으면 돼요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await meter.start() }
            } label: {
                Label("측정 시작", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmInk)
            .disabled(place == nil)
        }
    }

    private var deniedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("마이크 권한이 필요해요")
                .font(.headline)
            Text("설정에서 마이크 접근을 허용하면 측정할 수 있어요. 소리는 기기 안에서만 분석해요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var measuringSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(meter.remaining)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                Text("초 남았어요").font(.headline)
            }
            ProgressView(value: meter.progress)
                .tint(Color.calmInk)
            VStack(alignment: .leading, spacing: 6) {
                Text("지금 소리 크기 (상대값)").font(.caption).foregroundStyle(.secondary)
                ProgressView(value: SoundScore.loudness(averageDecibels: meter.currentDecibels))
                    .tint(Color.calmInk.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("들리는 소리").font(.caption).foregroundStyle(.secondary)
                if meter.recentCategories.isEmpty {
                    Text("소리를 듣고 있어요…").font(.subheadline)
                } else {
                    FlowTags(categories: meter.recentCategories)
                }
            }
            Button {
                meter.cancel()
                toasts.show("측정을 그만뒀어요.")
            } label: {
                Label("그만하기", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmInk)
            .padding(.top, 8)
        }
    }

    private func summarySection(_ summary: SoundMeter.Summary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("측정 결과").font(.title3.bold())
            Text("소리 부담 \(Int((summary.soundScore * 100).rounded())) / 100")
                .font(.headline)
            ForEach(summary.ratios.sorted { $0.value > $1.value }, id: \.key) { category, ratio in
                HStack {
                    Label(category.title, systemImage: category.symbolName)
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%").monospacedDigit()
                }
                .font(.subheadline)
            }
            if summary.ratios.isEmpty {
                Text("뚜렷하게 구분된 소리가 없었어요.").font(.subheadline).foregroundStyle(.secondary)
            }
            Divider()
            Text("빛은 어땠나요?").font(.headline)
            Toggle("조명이 많이 밝았어요", isOn: $brightLight)
            Toggle("깜빡이는 조명이 있었어요", isOn: $flicker)
            HStack {
                Button("다시 측정") {
                    meter.reset()
                }
                .buttonStyle(.bordered)
                Button {
                    save(summary)
                } label: {
                    Text("저장하기").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmInk)
            }
        }
    }

    private func save(_ summary: SoundMeter.Summary) {
        guard let place else { return }
        let measurement = SoundMeasurement(
            placeCode: place.code,
            measuredAt: Date(),
            durationSeconds: summary.durationSeconds,
            ratios: summary.ratios,
            averageDecibels: summary.averageDecibels,
            peakDecibels: summary.peakDecibels,
            soundScore: summary.soundScore,
            brightLight: brightLight,
            flicker: flicker
        )
        modelContext.insert(measurement)
        try? modelContext.save()
        toasts.show("\(place.name)에 저장했어요. 지도에 반영됐어요.", style: .success)
        brightLight = false
        flicker = false
        meter.reset()
    }

    private func adoptRouterPlace() {
        if let pending = router.measurePlace {
            place = pending
            router.measurePlace = nil
        }
    }
}

struct FlowTags: View {
    let categories: [SoundCategory]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(categories) { category in
                Label(category.title, systemImage: category.symbolName)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.calmInk.opacity(0.1), in: Capsule())
            }
        }
    }
}

struct PlacePickerView: View {
    let places: [Place]
    let onPick: (Place) -> Void
    @State private var query = ""

    private var filtered: [Place] {
        query.isEmpty ? places : places.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { place in
                Button {
                    onPick(place)
                } label: {
                    VStack(alignment: .leading) {
                        Text(place.name)
                        Text(place.category).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $query, prompt: "장소 이름")
            .navigationTitle("측정 장소")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
