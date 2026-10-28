import MapKit
import SwiftData
import SwiftUI

struct SensoryMapView: View {
    @Environment(SensoryMapModel.self) private var model
    @Environment(ToastCenter.self) private var toasts
    @Environment(AlertCenter.self) private var alerts
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \SoundMeasurement.measuredAt, order: .reverse) private var measurements: [SoundMeasurement]
    @AppStorage("hasSeenMapIntro") private var hasSeenIntro = false
    @State private var selected: SensoryMapModel.Entry?
    @State private var selectedSpot: MeasuredSpot?
    @State private var veilOpacity = 0.0
    @State private var locator = LocationProvider()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5560, longitude: 126.9900),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
                if hasSeenIntro {
                    ForEach(model.entries) { entry in
                        Annotation(entry.place.name, coordinate: entry.place.coordinate, anchor: .center) {
                            Button {
                                selected = entry
                            } label: {
                                marker(for: entry)
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                    ForEach(model.spots) { spot in
                        Annotation("내가 측정한 곳", coordinate: spot.coordinate, anchor: .center) {
                            Button {
                                selectedSpot = spot
                            } label: {
                                MeasuredSpotPin(tier: spot.tier)
                                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapControls {
                MapCompass()
            }
            .overlay(alignment: .top) {
                if !hasSeenIntro {
                    introFade
                }
            }
            .safeAreaInset(edge: .top) {
                if hasSeenIntro {
                    VStack(alignment: .trailing, spacing: 6) {
                        header
                        locateButton
                            .padding(.trailing, 10)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !hasSeenIntro {
                    introCard
                }
            }
            .navigationTitle("무던한 지도")
            .navigationBarTitleDisplayMode(hasSeenIntro ? .inline : .large)
            .toolbar {
                if hasSeenIntro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await refresh(announce: true) }
                        } label: {
                            if model.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(model.isLoading)
                        .accessibilityLabel("새로고침")
                    }
                }
            }
            .sheet(item: $selected) { entry in
                PlaceDetailView(placeCode: entry.place.code)
                    .calmDetailSheet()
            }
            .sheet(item: $selectedSpot) { spot in
                MeasuredSpotView(spotID: spot.id)
                    .calmDetailSheet()
            }
            .task {
                model.apply(measurements: measurements)
                await refresh(announce: false)
            }
            .onChange(of: measurements.count) {
                model.apply(measurements: measurements)
            }
            .onChange(of: router.mapFocus) {
                focusFromRouter()
            }
        }
        .overlay {
            Color(light: 0xD7DFEA, dark: 0x1A2940)
                .opacity(veilOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(veilOpacity > 0)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func marker(for entry: SensoryMapModel.Entry) -> some View {
        if let tier = entry.reading?.tier {
            TierBadge(tier: tier)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .accessibilityLabel("\(entry.place.name), \(tier.title)")
        } else {
            Circle()
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 22, height: 22)
                .phaseAnimator([1.0, 0.35]) { content, phase in
                    content.opacity(model.isLoading && !reduceMotion ? phase : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.55)
                }
                .accessibilityLabel("\(entry.place.name), \(model.isLoading ? "불러오는 중" : "데이터 없음")")
        }
    }

    private var introFade: some View {
        let base = Color(light: 0xD7DFEA, dark: 0x1A2940)
        return LinearGradient(
            stops: [
                .init(color: base, location: 0),
                .init(color: base.opacity(0.85), location: 0.6),
                .init(color: base.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 200)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("지금 덜 붐비는 곳을 찾아볼까요?")
                .font(.headline)
            Text("서울시 실시간 도시데이터로 사람 붐빔과 소리를 계산해서 무던함 · 보통 · 붐빔으로 보여 드려요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !model.profile.isGeneral {
                Label("\(model.profile.displayName) 기준으로 계산해요", systemImage: "figure.and.child.holdinghands")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.calmInk)
            }
            Button {
                Task { await revealMap() }
            } label: {
                Label("무던한 곳 보기", systemImage: "map")
            }
            .buttonStyle(.calmPrimary)
        }
        .calmCard()
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    private var locateButton: some View {
        Button {
            locateMe()
        } label: {
            Image("LocateMe")
                .renderingMode(.template)
                .foregroundStyle(Color.primary)
                .frame(width: 32, height: 32)
                .background(Color(.systemBackground), in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("내 위치로 이동")
    }

    private func locateMe() {
        if locator.isDenied {
            alerts.present(
                systemImage: "location.slash",
                title: "위치 권한이 꺼져 있어요",
                message: "설정에서 위치 접근을 허용하면 지도에서 내 위치를 볼 수 있어요.",
                cancelTitle: "취소",
                actionTitle: "설정 열기"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            return
        }
        locator.requestOnce()
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .userLocation(fallback: position)
        }
    }

    private func focusFromRouter() {
        guard let focus = router.mapFocus else { return }
        router.mapFocus = nil
        hasSeenIntro = true
        model.apply(measurements: measurements)
        let coordinate: CLLocationCoordinate2D?
        switch focus {
        case .place(let code):
            let entry = model.entry(for: code)
            coordinate = entry?.place.coordinate
            selected = entry
        case .spot(let id):
            let spot = model.spot(id: id)
            coordinate = spot?.coordinate
            selectedSpot = spot
        }
        if let coordinate {
            withAnimation(.easeInOut(duration: 0.4)) {
                position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
            }
        }
    }

    private func revealMap() async {
        withAnimation(.easeIn(duration: 0.25)) {
            veilOpacity = 1
        }
        try? await Task.sleep(for: .milliseconds(250))
        hasSeenIntro = true
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.easeOut(duration: 0.5)) {
            veilOpacity = 0
        }
        if model.updatedAt == nil, !model.isLoading, model.errorMessage != nil {
            presentLoadError()
        }
    }

    private func refresh(announce: Bool) async {
        switch await model.refresh() {
        case .loaded:
            if announce, let updatedAt = model.updatedAt {
                toasts.show("업데이트했어요 · \(updatedAt.formatted(date: .omitted, time: .shortened)) 기준", style: .success)
            }
        case .failed:
            if hasSeenIntro {
                presentLoadError()
            }
        case .skipped:
            break
        }
    }

    private func presentLoadError() {
        alerts.present(
            systemImage: "wifi.exclamationmark",
            title: "데이터를 불러오지 못했어요",
            message: "인터넷 연결을 확인하고 다시 시도해 주세요.",
            cancelTitle: "닫기",
            actionTitle: "다시 시도"
        ) {
            Task { await refresh(announce: true) }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            if let updatedAt = model.updatedAt {
                HStack(spacing: model.spots.isEmpty ? 14 : 10) {
                    ForEach(SensoryTier.allCases, id: \.self) { tier in
                        HStack(spacing: 6) {
                            TierBadge(tier: tier, size: 20)
                            Text("\(tier.title) \(model.count(of: tier))")
                                .font(.footnote.weight(.medium))
                        }
                    }
                    if !model.spots.isEmpty {
                        HStack(spacing: 6) {
                            MeasuredSpotPin(tier: .calm, size: 20)
                            Text("내 측정 \(model.spots.count)")
                                .font(.footnote.weight(.medium))
                        }
                    }
                }
                Text("\(updatedAt.formatted(date: .omitted, time: .shortened)) 기준 · 서울시 실시간 도시데이터")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if model.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("서울시 실시간 도시데이터 불러오는 중…")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("데이터를 불러오지 못했어요. 새로고침해 주세요.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if !model.profile.isGeneral {
                Label("\(model.profile.displayName) 맞춤 지도", systemImage: "figure.and.child.holdinghands")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.calmInk)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .calmGlass(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    SensoryMapView()
        .environment(ToastCenter())
        .environment(AlertCenter())
        .environment(AppRouter())
        .environment(SensoryMapModel())
}
