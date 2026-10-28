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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var stoppedInBackground = false
    @State private var autoSelected = false
    @State private var spotAnchor: CLLocationCoordinate2D?
    @State private var measuredLocation: CLLocation?
    @State private var measuredAreaName: String?
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
                    if meter.state != .measuring {
                        privacyNote
                    }
                    placeSelector
                    if useCurrentLocation {
                        if location.isDenied {
                            locationDeniedNote
                        } else {
                            soundOnlyNote
                        }
                    }
                    if meter.state == .denied {
                        micDeniedNote
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
                    isLocationDenied: location.isDenied,
                    onPickCurrentLocation: {
                        place = nil
                        useCurrentLocation = true
                        autoSelected = false
                        spotAnchor = nil
                        showingPlacePicker = false
                    },
                    onPick: { picked in
                        place = picked
                        useCurrentLocation = false
                        autoSelected = false
                        spotAnchor = nil
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
                toasts.show(meter.interruptionMessage, style: .warning, duration: .seconds(4))
            }
            .onChange(of: meter.state) {
                guard meter.state == .finished else { return }
                if router.selectedTab != .measure {
                    toasts.show("측정이 끝났어요. 결과를 저장해 주세요.", style: .success, duration: .seconds(4.5), actionTitle: "결과 보기") { [router] in
                        router.showMeasureResult()
                    }
                } else {
                    AccessibilityNotification.Announcement("측정이 끝났어요. 결과를 확인하고 저장해 주세요.").post()
                }
            }
            .sensoryFeedback(.success, trigger: meter.state) { _, new in new == .finished }
            .onChange(of: scenePhase) {
                if scenePhase == .background, meter.state == .measuring {
                    meter.cancel()
                    stoppedInBackground = true
                } else if scenePhase == .active, router.selectedTab == .measure {
                    location.requestOnce()
                }
                if scenePhase == .active, stoppedInBackground {
                    stoppedInBackground = false
                    toasts.show("앱을 나가서 측정을 멈췄어요.\n다시 시작해 주세요.", style: .warning, duration: .seconds(4))
                }
            }
            .onChange(of: location.location) {
                if meter.state == .measuring {
                    measuredLocation = location.location
                }
                autoSelectPlace()
            }
            .onChange(of: location.areaName) {
                if meter.state == .measuring {
                    measuredAreaName = location.areaName
                }
            }
        }
    }

    private var privacyNote: some View {
        Label("소리는 기기 안에서만 분석해요.\n녹음 파일은 저장하거나 전송하지 않아요.", systemImage: "lock.shield")
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
                        if !location.isDenied {
                            Label(currentLocationText, systemImage: "location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if location.isApproximate, location.location != nil {
                            Label("대략적인 위치라 핀이 실제 위치와 다를 수 있어요", systemImage: "location.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let distance = distanceFromSpotAnchor, distance > MeasuredSpot.mergeRadius {
                            Label("이 핀에서 \(distance.shortText) 떨어져 있어요 · 측정하면 새 핀이 생겨요", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(place?.name ?? "장소를 골라 주세요").font(.headline)
                        if place == nil, location.isApproximate {
                            Label("대략적인 위치라 장소를 자동으로 고르지 않았어요", systemImage: "location.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let place, let current = location.location {
                            if place.isNearby(current) {
                                Label("현재 위치에서 \(place.distance(from: current).shortText)", systemImage: "location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("이 장소에서 \(place.distance(from: current).shortText) 떨어져 있어요 · 가까이 가서 측정하면 더 정확해요", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
                if meter.state == .measuring {
                    measuringBadge
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
            .calmCard()
        }
        .buttonStyle(.plain)
        .disabled(meter.state == .measuring)
    }

    private var measuringBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.calmInk)
                .frame(width: 6, height: 6)
                .phaseAnimator([1.0, 0.25]) { content, phase in
                    content.opacity(reduceMotion ? 1 : phase)
                } animation: { _ in
                    .easeInOut(duration: 0.6)
                }
            Text("측정 중")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(Color.calmInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.calmTint, in: Capsule())
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .failed(let message) = meter.state {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Text("\(Int(SoundMeter.duration))초 동안 주변 소리의 종류와 크기를 살펴요.\n폰을 손에 들고 평소처럼 서 있으면 돼요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if useCurrentLocation, location.didFail, location.location == nil {
                Button {
                    location.requestOnce()
                } label: {
                    Label("위치 다시 찾기", systemImage: "location")
                }
                .font(.subheadline.weight(.semibold))
                .tint(Color.calmInk)
            }
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

    private var distanceFromSpotAnchor: CLLocationDistance? {
        guard let anchor = spotAnchor, let current = location.location else { return nil }
        return current.distance(from: CLLocation(latitude: anchor.latitude, longitude: anchor.longitude))
    }

    private func autoSelectPlace() {
        guard meter.state != .measuring, meter.state != .finished, let current = location.location else { return }
        guard (place == nil && !useCurrentLocation) || autoSelected else { return }
        if location.isApproximate {
            if autoSelected {
                place = nil
                useCurrentLocation = false
                autoSelected = false
            }
            return
        }
        if let nearest = places.sorted(near: current).first, nearest.isNearby(current) {
            place = nearest
            useCurrentLocation = false
        } else {
            place = nil
            useCurrentLocation = true
        }
        autoSelected = true
    }

    private var currentLocationText: String {
        if location.isDenied { return "위치 권한이 꺼져 있어요" }
        if let areaName = location.areaName { return areaName }
        if location.location == nil {
            return location.didFail ? "위치를 찾지 못했어요" : "위치를 확인하고 있어요"
        }
        return "현재 위치"
    }

    private var locationDeniedNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("위치 권한이 꺼져 있어요")
                        .font(.subheadline.weight(.semibold))
                    Text("설정에서 켜면 현재 위치에서 측정할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "location.slash")
                    .foregroundStyle(Color.calmInk)
            }
            Button("설정 열기", action: openSettings)
            .font(.subheadline.weight(.semibold))
            .tint(Color.calmInk)
        }
        .calmTintCard(padding: 12, cornerRadius: 16)
    }

    private var micDeniedNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("마이크 권한이 꺼져 있어 측정할 수 없어요. 설정에서 마이크를 허용해 주세요.")
                    .font(.footnote)
            } icon: {
                Image(systemName: "mic.slash")
                    .foregroundStyle(Color.calmInk)
            }
            Button("설정 열기", action: openSettings)
                .font(.subheadline.weight(.semibold))
                .tint(Color.calmInk)
        }
        .calmTintCard(padding: 12, cornerRadius: 16)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private var soundOnlyText: String {
        guard let current = location.location else {
            return "현재 위치에서는 소리만 기록해요.\n서울 121곳 근처에서는 사람 붐빔까지 함께 계산해요."
        }
        if places.contains(where: { $0.isNearby(current) }) {
            return "현재 위치에서는 소리만 기록해요.\n근처 장소를 고르면 사람 붐빔까지 함께 계산해요."
        }
        return "근처에 실시간 데이터 장소가 없어서 소리만 기록해요.\n서울 121곳 근처에서는 사람 붐빔까지 함께 계산해요."
    }

    private var soundOnlyNote: some View {
        Label {
            Text(soundOnlyText)
                .font(.footnote)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.calmInk)
        }
        .calmTintCard(padding: 12, cornerRadius: 16)
    }

    private func startMeasuring() async {
        let wasAsked = AVAudioApplication.shared.recordPermission != .undetermined
        location.requestOnce()
        await meter.start()
        if meter.state == .measuring {
            measuredLocation = location.location
            measuredAreaName = location.areaName
        }
        guard meter.state == .denied else { return }
        if wasAsked {
            alerts.present(
                systemImage: "mic.slash",
                title: "마이크 권한이 필요해요",
                message: "설정에서 마이크 접근을 허용하면 측정할 수 있어요. 소리는 기기 안에서만 분석해요.",
                cancelTitle: "취소",
                actionTitle: "설정 열기",
                action: openSettings
            )
        } else {
            toasts.show("마이크 권한이 없어 측정할 수 없어요.")
        }
    }

    private var loudnessIndicator: some View {
        let level = LoudnessLevel(loudness: SoundScore.loudness(averageDecibels: meter.currentDecibels))
        return HStack(spacing: 6) {
            Text(level.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.calmInk)
            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { step in
                    Capsule()
                        .fill(Color.calmInk.opacity(step <= level.rawValue ? 1 : 0.18))
                        .frame(width: 14, height: 5)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("지금 소리 크기, \(level.title)")
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
                    loudnessIndicator
                        .padding(.top, 6)
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
                    brightLight = false
                    flicker = false
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
        let current = measuredLocation ?? location.location
        if useCurrentLocation, current == nil {
            location.requestOnce()
            toasts.show("위치를 아직 찾지 못했어요. 잠시 후 다시 저장해 주세요.", style: .warning)
            return
        }
        guard place != nil || useCurrentLocation else {
            toasts.show("측정 장소를 골라 주세요.", style: .warning)
            return
        }
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
            areaName: useCurrentLocation ? measuredAreaName ?? location.areaName : nil
        )
        modelContext.insert(measurement)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(measurement)
            toasts.show("저장하지 못했어요. 다시 시도해 주세요.", style: .warning)
            return
        }
        if useCurrentLocation {
            let spotID = measurement.id
            toasts.show("현재 위치에 저장했어요", style: .success, duration: .seconds(4.5), actionTitle: "지도에서 보기") { [router] in
                router.showOnMap(.spot(spotID))
            }
        } else if let place {
            toasts.show("\(place.name)에 저장했어요", style: .success, duration: .seconds(4.5), actionTitle: "지도에서 보기") { [router] in
                router.showOnMap(.place(place.code))
            }
        }
        brightLight = false
        flicker = false
        spotAnchor = nil
        measuredLocation = nil
        measuredAreaName = nil
        meter.reset()
    }

    private func adoptRouterPlace() {
        let pendingPlace = router.measurePlace
        let pendingCurrent = router.measureAtCurrentLocation
        let anchor = router.measureAnchor
        guard pendingPlace != nil || pendingCurrent else { return }
        router.measurePlace = nil
        router.measureAtCurrentLocation = false
        router.measureAnchor = nil
        switch meter.state {
        case .measuring:
            toasts.show("측정 중에는 장소를 바꿀 수 없어요.")
        case .finished:
            alerts.present(
                systemImage: "exclamationmark.circle",
                title: "저장하지 않은 결과가 있어요",
                message: "지금 결과를 저장하지 않고 새로 측정할까요?",
                cancelTitle: "결과 보기",
                actionTitle: "새로 측정",
                isDestructive: true
            ) {
                brightLight = false
                flicker = false
                meter.reset()
                select(place: pendingPlace, currentLocation: pendingCurrent, anchor: anchor)
            }
        default:
            select(place: pendingPlace, currentLocation: pendingCurrent, anchor: anchor)
        }
    }

    private func select(place pending: Place?, currentLocation: Bool, anchor: CLLocationCoordinate2D?) {
        autoSelected = false
        if currentLocation {
            place = nil
            useCurrentLocation = true
            spotAnchor = anchor
            location.requestOnce()
        } else if let pending {
            place = pending
            useCurrentLocation = false
            spotAnchor = nil
        }
    }
}

struct FlowTags: View {
    let categories: [SoundCategory]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(categories) { category in
                Label(category.title, systemImage: category.symbolName)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .calmGlass(Capsule())
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
            }
        }
        .animation(.easeOut(duration: 0.45), value: categories)
    }
}

struct PlacePickerView: View {
    let places: [Place]
    let location: CLLocation?
    let areaName: String?
    let isLocationDenied: Bool
    let onPickCurrentLocation: () -> Void
    let onPick: (Place) -> Void
    @State private var query = ""

    private var filtered: [Place] {
        query.isEmpty ? places : places.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if isLocationDenied, query.isEmpty {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color(.tertiarySystemFill), in: Circle())
                            VStack(alignment: .leading) {
                                Text("현재 위치에서 측정")
                                    .foregroundStyle(.secondary)
                                Text("위치 권한을 켜면 쓸 수 있어요")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else if location != nil, query.isEmpty {
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
            .overlay {
                if filtered.isEmpty, !query.isEmpty {
                    ContentUnavailableView.search(text: query)
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
