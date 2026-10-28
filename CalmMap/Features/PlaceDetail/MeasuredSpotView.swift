import SwiftData
import SwiftUI

struct MeasuredSpotView: View {
    let spotID: UUID
    @Environment(SensoryMapModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var sheetAlerts = AlertCenter()

    private var spot: MeasuredSpot? {
        model.spot(id: spotID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let spot, let latest = spot.latest {
                        summary(spot)
                        soundOnlyNote
                        heardSounds(latest, score: spot.score)
                            .calmCard()
                        history(spot)
                            .calmCard()
                        Button {
                            dismiss()
                            router.measureHere(near: spot.coordinate)
                        } label: {
                            Label("여기서 다시 측정하기", systemImage: "waveform")
                        }
                        .buttonStyle(.calmPrimary)
                        Button("이 측정 기록 삭제", role: .destructive) {
                            confirmDelete(count: spot.measurements.count)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView("측정 기록이 없어요", systemImage: "waveform")
                    }
                    Text("측정 기록은 이 기기에만 저장되고, 위치는 지도 표시에만 써요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(CalmBackdrop())
            .navigationTitle("내가 측정한 곳")
            .navigationBarTitleDisplayMode(.inline)
        }
        .calmAlertOverlay()
        .environment(sheetAlerts)
    }

    private func confirmDelete(count: Int) {
        sheetAlerts.present(
            systemImage: "trash",
            title: "이곳의 측정 기록 \(count)개를 삭제할까요?",
            message: "지도에서 이 핀이 사라져요.",
            cancelTitle: "취소",
            actionTitle: "삭제",
            isDestructive: true
        ) {
            delete()
        }
    }

    private func summary(_ spot: MeasuredSpot) -> some View {
        HStack(spacing: 14) {
            MeasuredSpotPin(tier: spot.tier, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("측정 당시 \(spot.tier.title)")
                    .font(.title2.bold())
                Text(spot.areaName ?? "현재 위치")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var soundOnlyNote: some View {
        Label {
            Text("실시간 붐빔 데이터가 없는 곳이라, 직접 측정한 소리로만 보여 드려요. 시간대별 예측은 서울 121곳에서만 볼 수 있어요.")
                .font(.subheadline)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.calmInk)
        }
        .calmTintCard()
    }

    private func heardSounds(_ measurement: SoundMeasurement, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("들린 소리")
                    .font(.headline)
                Spacer()
                Text("소리 부담 \(Int(score.rounded())) / 100")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            let ratios = measurement.ratios.sorted { $0.value > $1.value }
            if ratios.isEmpty {
                Text("뚜렷하게 구분된 소리가 없었어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(ratios, id: \.key) { category, ratio in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(category.title, systemImage: category.symbolName)
                        Spacer()
                        Text("\(Int((ratio * 100).rounded()))%")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    ProgressView(value: ratio)
                        .tint(Color.calmInk)
                }
            }
        }
    }

    private func history(_ spot: MeasuredSpot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("측정 기록 \(spot.measurements.count)회")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(spot.measurements) { measurement in
                let score = measurement.soundScore * 100
                HStack(spacing: 12) {
                    MeasuredSpotPin(tier: SensoryTier(score: score), size: 24)
                    Text(measurement.measuredAt.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute()))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(score.rounded()))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                if measurement.id != spot.measurements.last?.id {
                    Divider()
                }
            }
        }
    }

    private func delete() {
        guard let spot else { return }
        for measurement in spot.measurements {
            modelContext.delete(measurement)
        }
        try? modelContext.save()
        toasts.show("측정 기록을 삭제했어요.")
        dismiss()
    }
}
