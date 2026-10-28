import AVFAudio
import CoreLocation
import SwiftData
import SwiftUI

struct MeasureView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(AlertCenter.self) private var alerts
    @Environment(SensoryMapModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var meter = SoundMeter()
    @State private var location = LocationProvider()
    @State private var place: Place?
    @State private var useCurrentLocation = false
    @State private var showingPlacePicker = false
    @State private var brightLight = false
    @State private var flicker = false

    private var places: [Place] { model.places }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    privacyNote
                    placeSelector
                    if useCurrentLocation {
                        soundOnlyNote
                    }
                    switch meter.state {
                    case .idle, .failed, .denied:
                        startSection
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
            .background(CalmBackdrop())
            .navigationTitle("소리 측정")
            .sheet(isPresented: $showingPlacePicker) {
                PlacePickerView(
                    places: places.sorted(near: location.location),
                    location: location.location,
                    areaName: location.areaName,
                    onPickCurrentLocation: {
                        place = nil
                        useCurrentLocation = true
                        showingPlacePicker = false
                    },
                    onPick: { picked in
                        place = picked
                        useCurrentLocation = false
                        showingPlacePicker = false
                    }
                )
            }
            .onAppear {
                location.requestOnce()
                adoptRouterPlace()
            }
            .onChange(of: router.measurePlace) {
                adoptRouterPlace()
            }
            .onChange(of: router.measureAtCurrentLocation) {
                adoptRouterPlace()
            }
            .onChange(of: meter.interruptionCount) {
                toasts.show("다른 소리가 끼어들어 측정이 중단됐어요. 다시 시작해 주세요.", style: .warning, duration: .seconds(4))
            }
            .onChange(of: location.location) {
                guard place == nil, !useCurrentLocation, let current = location.location else { return }
                if let nearest = places.sorted(near: current).first, nearest.isNearby(current) {
                    place = nearest
                } else {
                    useCurrentLocation = true
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
            .calmGlass(RoundedRectangle(cornerRadius: 16))
    }

    private var placeSelector: some View {
        Button {
            showingPlacePicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("측정 장소").font(.caption).foregroundStyle(.secondary)
                    if useCurrentLocation {
                        Text("현재 위치").font(.headline)
                        Label(location.areaName ?? (location.location == nil ? "위치를 확인하고 있어요" : "현재 위치"), systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(place?.name ?? "장소를 골라 주세요").font(.headline)
                        if let place, let current = location.location {
                            Label("현재 위치에서 \(place.distance(from: current).shortText)", systemImage: "location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .calmCard()
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
                Task { await startMeasuring() }
            } label: {
                Label("측정 시작", systemImage: "waveform")
            }
            .buttonStyle(.calmPrimary)
            .disabled(!canMeasure)
        }
    }

    private var canMeasure: Bool {
        place != nil || (useCurrentLocation && location.location != nil)
    }

    private var soundOnlyNote: some View {
        Label {
            Text("근처에 실시간 데이터 장소가 없어서 소리만 기록해요. 서울 121곳 근처에서는 사람 붐빔까지 함께 계산해요.")
                .font(.footnote)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.calmInk)
        }
        .calmTintCard(padding: 12, cornerRadius: 16)
    }

    private func startMeasuring() async {
        let wasAsked = AVAudioApplication.shared.recordPermission != .undetermined
        await meter.start()
        guard meter.state == .denied else { return }
        if wasAsked {
            alerts.present(
                systemImage: "mic.slash",
                title: "마이크 권한이 필요해요",
                message: "설정에서 마이크 접근을 허용하면 측정할 수 있어요. 소리는 기기 안에서만 분석해요.",
                cancelTitle: "취소",
                actionTitle: "설정 열기"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        } else {
            toasts.show("마이크 권한이 없어서 측정을 시작하지 않았어요.")
        }
    }

    private var measuringSection: some View {
        VStack(spacing: 16) {
            ZStack {
                SoundBlob(level: SoundScore.loudness(averageDecibels: meter.currentDecibels))
                VStack(spacing: 2) {
                    Text("\(meter.remaining)")
                        .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("초 남았어요").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(height: 260)
            .accessibilityElement(children: .combine)
            ProgressView(value: meter.progress)
                .tint(Color.calmInk)
            VStack(spacing: 8) {
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
            }
            .buttonStyle(.calmPrimary)
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
                    if model.profile.trigger(category) != .fine {
                        Text("\(model.profile.displayName) \(model.profile.trigger(category).shortTitle) 힘들어함")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.calmOnInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.calmInk.opacity(0.85), in: Capsule())
                    }
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
                .buttonStyle(.calmSecondary)
                Button("저장하기") {
                    save(summary)
                }
                .buttonStyle(.calmPrimary)
            }
        }
        .calmCard()
    }

    private func save(_ summary: SoundMeter.Summary) {
        let current = location.location
        guard place != nil || (useCurrentLocation && current != nil) else { return }
        let measurement = SoundMeasurement(
            placeCode: useCurrentLocation ? SoundMeasurement.currentLocationCode : place?.code ?? "",
            measuredAt: Date(),
            durationSeconds: summary.durationSeconds,
            ratios: summary.ratios,
            averageDecibels: summary.averageDecibels,
            peakDecibels: summary.peakDecibels,
            soundScore: summary.soundScore,
            brightLight: brightLight,
            flicker: flicker,
            latitude: useCurrentLocation ? current?.coordinate.latitude : nil,
            longitude: useCurrentLocation ? current?.coordinate.longitude : nil,
            areaName: useCurrentLocation ? location.areaName : nil
        )
        modelContext.insert(measurement)
        try? modelContext.save()
        if useCurrentLocation {
            toasts.show("현재 위치에 저장했어요. 지도에 표시됐어요.", style: .success)
        } else if let place {
            toasts.show("\(place.name)에 저장했어요. 지도에 반영됐어요.", style: .success)
        }
        brightLight = false
        flicker = false
        meter.reset()
    }

    private func adoptRouterPlace() {
        if let pending = router.measurePlace {
            place = pending
            useCurrentLocation = false
            router.measurePlace = nil
        }
        if router.measureAtCurrentLocation {
            place = nil
            useCurrentLocation = true
            router.measureAtCurrentLocation = false
            location.requestOnce()
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
                    .calmGlass(Capsule())
            }
        }
    }
}

struct PlacePickerView: View {
    let places: [Place]
    let location: CLLocation?
    let areaName: String?
    let onPickCurrentLocation: () -> Void
    let onPick: (Place) -> Void
    @State private var query = ""

    private var filtered: [Place] {
        query.isEmpty ? places : places.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if location != nil, query.isEmpty {
                    Section {
                        Button(action: onPickCurrentLocation) {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.calmInk)
                                    .frame(width: 30, height: 30)
                                    .background(Color.calmTint, in: Circle())
                                VStack(alignment: .leading) {
                                    Text("현재 위치에서 측정")
                                        .foregroundStyle(Color.calmInk)
                                    Text("\(areaName ?? "현재 위치") · 소리만 기록돼요")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section(location == nil ? "실시간 데이터 장소" : "실시간 데이터 장소 · 가까운 순") {
                    ForEach(filtered) { place in
                        placeRow(place)
                    }
                }
            }
            .searchable(text: $query, prompt: "장소 이름")
            .navigationTitle("측정 장소")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func placeRow(_ place: Place) -> some View {
        Button {
            onPick(place)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(place.name)
                    Text(place.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let location {
                    Text(place.distance(from: location).shortText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
