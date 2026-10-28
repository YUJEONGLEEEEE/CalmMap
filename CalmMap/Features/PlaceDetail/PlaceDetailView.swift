import Charts
import SwiftData
import SwiftUI

struct PlaceDetailView: View {
    let placeCode: String
    @Environment(SensoryMapModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \SoundMeasurement.measuredAt, order: .reverse) private var measurements: [SoundMeasurement]
    @State private var sheetAlerts = AlertCenter()

    private var placeMeasurements: [SoundMeasurement] {
        measurements.filter { $0.placeCode == placeCode }
    }

    private var entry: SensoryMapModel.Entry? {
        model.entry(for: placeCode)
    }

    private var hourly: [HourlyReading] {
        entry.map { model.hourly(for: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let reading = entry?.reading, let live = entry?.live {
                        summary(reading: reading, live: live)
                        adviceCard(reading: reading)
                        if !model.profile.isGeneral {
                            personalCard(reading: reading)
                                .calmCard()
                        }
                        forecastChart
                            .calmCard()
                        breakdown(reading: reading, live: live)
                            .calmCard()
                        myMeasurements
                        measureButton
                    } else if model.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("장소 정보를 불러오는 중이에요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if entry != nil, model.updatedAt != nil {
                        ContentUnavailableView(
                            "지금은 실시간 정보가 없어요",
                            systemImage: "clock.badge.questionmark",
                            description: Text("이 장소는 서울시 실시간 데이터가 잠시 들어오지 않고 있어요. 직접 측정한 소리는 기록할 수 있어요.")
                        )
                        myMeasurements
                        measureButton
                    } else {
                        ContentUnavailableView(
                            "데이터를 불러오지 못했어요",
                            systemImage: "wifi.exclamationmark",
                            description: Text((model.loadFailure ?? .network).message)
                        )
                        if entry != nil {
                            myMeasurements
                            measureButton
                        }
                    }
                    Text("출처: 서울특별시 실시간 도시데이터, 스마트서울 도시데이터 센서(S-DoT) 환경정보 (공공누리 제1유형). 지수는 확률적 예측이며 판정이 아닙니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(CalmBackdrop())
            .navigationTitle(entry?.place.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
        }
        .calmAlertOverlay()
        .environment(sheetAlerts)
    }

    @ViewBuilder
    private var myMeasurements: some View {
        let records = placeMeasurements
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("내 측정 기록 \(records.count)개")
                    .font(.headline)
                Text("측정한 시간대 앞뒤 2시간의 소리 계산에 반영돼요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                ForEach(records) { measurement in
                    let score = measurement.soundScore * 100
                    HStack(spacing: 12) {
                        Text(measurement.measuredAt.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute()))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("소리 부담 \(Int(score.rounded()))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            confirmDelete(measurement)
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("이 측정 기록 삭제")
                    }
                    if measurement.id != records.last?.id {
                        Divider()
                    }
                }
            }
            .calmCard()
        }
    }

    private func confirmDelete(_ measurement: SoundMeasurement) {
        let when = measurement.measuredAt.formatted(.dateTime.month().day().hour().minute())
        sheetAlerts.present(
            systemImage: "trash",
            title: "이 측정 기록을 삭제할까요?",
            message: "\(when)에 측정한 기록이 사라지고 점수를 다시 계산해요.",
            cancelTitle: "취소",
            actionTitle: "삭제",
            isDestructive: true
        ) {
            delete(measurement)
        }
    }

    private func delete(_ measurement: SoundMeasurement) {
        model.forget(measurementIDs: [measurement.id])
        modelContext.delete(measurement)
        do {
            try modelContext.save()
            toasts.show("측정 기록을 삭제했어요.")
        } catch {
            modelContext.rollback()
            model.apply(measurements: measurements)
            toasts.show("삭제하지 못했어요. 다시 시도해 주세요.", style: .warning)
        }
    }

    private var measureButton: some View {
        Button {
            guard let place = entry?.place else { return }
            dismiss()
            router.measure(at: place)
        } label: {
            Label("여기서 소리 측정하기", systemImage: "waveform")
        }
        .buttonStyle(.calmPrimary)
    }

    private func summary(reading: SensoryReading, live: LivePlace) -> some View {
        HStack(spacing: 14) {
            TierBadge(tier: reading.tier, size: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("지금 \(reading.tier.title)")
                    .font(.title2.bold())
                Text(scoreLine(reading))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func scoreLine(_ reading: SensoryReading) -> String {
        let score = "감각부하 \(Int(reading.score.rounded())) / 100"
        guard !model.profile.isGeneral else { return score }
        return "\(model.profile.displayName) 기준 \(score)"
    }

    private func personalCard(reading: SensoryReading) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("\(model.profile.displayName)에게 맞춘 점수")
                } icon: {
                    Image("ChildChip")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.calmInk)
                }
                .font(.headline)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("일반 \(Int(reading.baseScore.rounded()))")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(model.profile.displayName) \(Int(reading.score.rounded()))")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.calmInk)
                if reading.tier != reading.baseTier {
                    Text("\(reading.baseTier.title) → \(reading.tier.title)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .calmGlass(Capsule())
                }
            }
            .font(.subheadline.monospacedDigit())
            if reading.factors.isEmpty {
                Text("\(model.profile.displayName.particle("이", "가")) 힘들어하는 요소가 크게 보이지 않는 곳이에요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reading.factors) { factor in
                    Label(factor.text, systemImage: factor.symbolName)
                        .font(.footnote)
                }
            }
        }
    }

    private func adviceCard(reading: SensoryReading) -> some View {
        Label {
            Text(CalmWindowAdvisor.advice(current: reading, hourly: hourly))
                .font(.headline)
        } icon: {
            Image(systemName: "clock")
                .foregroundStyle(Color.calmInk)
        }
        .calmTintCard()
    }

    private var forecastChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("앞으로 12시간")
                .font(.headline)
            if hourly.isEmpty {
                Text("지금은 시간대별 예측을 볼 수 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
            Chart(hourly) { item in
                BarMark(
                    x: .value("시각", item.date, unit: .hour),
                    y: .value("감각부하", item.reading.score)
                )
                .foregroundStyle(item.reading.tier.fill)
                .accessibilityLabel(item.date.hourText())
                .accessibilityValue("\(item.reading.tier.title), 감각부하 \(Int(item.reading.score.rounded()))")
                .annotation(position: .top, spacing: 2) {
                    Image(systemName: item.reading.tier.symbolName)
                        .font(.system(size: 8))
                        .foregroundStyle(Color.calmInk)
                }
                RuleMark(y: .value("무던함 기준", 40))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: Date.FormatStyle(timeZone: .seoul).hour())
                }
            }
            .environment(\.timeZone, .seoul)
            .environment(\.calendar, .seoul)
            .frame(height: 180)
            .accessibilityLabel("시간대별 감각부하 예측")
            }
        }
    }

    private func breakdown(reading: SensoryReading, live: LivePlace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이렇게 계산했어요")
                .font(.headline)
            row(title: "사람 붐빔", value: reading.crowd, detail: "약 \(Int(live.populationMin).formatted())~\(Int(live.populationMax).formatted())명 · 서울시 혼잡도 \(live.level.rawValue)")
            row(title: "소리", value: reading.sound, detail: soundDetail(reading.soundSource))
            Text(live.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func soundDetail(_ source: SoundSource) -> String {
        switch source {
        case .measured:
            "현장 실측 반영"
        case .sensor(let decibels, let sensors):
            "서울시 소음 센서 \(sensors)대 · 평소 이 시간 약 \(Int(decibels.rounded()))dB"
        case .estimate:
            "장소 유형 기반 추정 (주변 센서·측정 없음)"
        }
    }

    private func row(title: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int((value * 100).rounded()))")
                    .font(.subheadline.monospacedDigit())
            }
            ProgressView(value: value)
                .tint(Color.calmInk)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int((value * 100).rounded())), \(detail)")
    }
}
