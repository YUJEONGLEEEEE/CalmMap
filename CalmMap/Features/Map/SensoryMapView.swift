import MapKit
import SwiftData
import SwiftUI

struct SensoryMapView: View {
    @State private var model = SensoryMapModel()
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \SoundMeasurement.measuredAt, order: .reverse) private var measurements: [SoundMeasurement]
    @State private var selected: SensoryMapModel.Entry?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5560, longitude: 126.9900),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position) {
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
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .safeAreaInset(edge: .top) {
                header
            }
            .navigationTitle("무던한 지도")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    .accessibilityLabel("새로고침")
                }
            }
            .sheet(item: $selected) { entry in
                PlaceDetailView(entry: entry) { date in
                    model.soundInput(for: entry.place.code, at: date)
                }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.calmBackground)
            }
            .task {
                model.apply(measurements: measurements)
                await refresh(announce: false)
            }
            .onChange(of: measurements.count) {
                model.apply(measurements: measurements)
            }
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
                .accessibilityLabel("\(entry.place.name), 데이터 없음")
        }
    }

    private func refresh(announce: Bool) async {
        let succeeded = await model.refresh()
        if succeeded {
            if announce, let updatedAt = model.updatedAt {
                toasts.show("업데이트했어요 · \(updatedAt.formatted(date: .omitted, time: .shortened)) 기준", style: .success)
            }
        } else if let message = model.errorMessage {
            toasts.show("\(message) 인터넷 연결을 확인하고 새로고침해 주세요.", style: .warning, duration: .seconds(4))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                ForEach(SensoryTier.allCases, id: \.self) { tier in
                    HStack(spacing: 6) {
                        TierBadge(tier: tier, size: 20)
                        Text("\(tier.title) \(model.count(of: tier))")
                            .font(.footnote.weight(.medium))
                    }
                }
            }
            if let updatedAt = model.updatedAt {
                Text("\(updatedAt.formatted(date: .omitted, time: .shortened)) 기준 · 서울시 실시간 도시데이터")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    SensoryMapView()
        .environment(ToastCenter())
}
