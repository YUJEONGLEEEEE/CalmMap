import Charts
import SwiftUI

struct PlaceDetailView: View {
    let entry: SensoryMapModel.Entry
    var soundAt: (Date) -> SoundInput? = { _ in nil }
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    private var hourly: [HourlyReading] {
        guard let live = entry.live else { return [] }
        return CalmWindowAdvisor.hourly(place: entry.place, live: live, soundAt: soundAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let reading = entry.reading, let live = entry.live {
                        summary(reading: reading, live: live)
                        adviceCard(reading: reading)
                        forecastChart
                        breakdown(reading: reading, live: live)
                        measureButton
                    } else {
                        ContentUnavailableView(
                            "데이터를 불러오지 못했어요",
                            systemImage: "wifi.exclamationmark",
                            description: Text("잠시 후 다시 시도해 주세요.")
                        )
                    }
                    Text("출처: 서울특별시 실시간 도시데이터, 스마트서울 도시데이터 센서(S-DoT) 환경정보 (공공누리 제1유형). 지수는 확률적 예측이며 판정이 아닙니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(entry.place.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var measureButton: some View {
        Button {
            dismiss()
            router.measure(at: entry.place)
        } label: {
            Label("여기서 소리 측정하기", systemImage: "waveform")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(Color.calmInk)
    }

    private func summary(reading: SensoryReading, live: LivePlace) -> some View {
        HStack(spacing: 14) {
            TierBadge(tier: reading.tier, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("지금 \(reading.tier.title)")
                    .font(.title2.bold())
                Text("감각부하 \(Int(reading.score.rounded())) / 100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func adviceCard(reading: SensoryReading) -> some View {
        Label {
            Text(CalmWindowAdvisor.advice(current: reading, hourly: hourly))
                .font(.headline)
        } icon: {
            Image(systemName: "clock")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.calmInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var forecastChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("앞으로 12시간")
                .font(.headline)
            Chart(hourly) { item in
                BarMark(
                    x: .value("시각", item.date, unit: .hour),
                    y: .value("감각부하", item.reading.score)
                )
                .foregroundStyle(item.reading.tier.fill)
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
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 180)
            .accessibilityLabel("시간대별 감각부하 예측")
        }
    }

    private func breakdown(reading: SensoryReading, live: LivePlace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이렇게 계산했어요")
                .font(.headline)
            row(title: "사람 붐빔", value: reading.crowd, detail: "약 \(Int(live.populationMin).formatted())~\(Int(live.populationMax).formatted())명 · 평소 대비 \(live.level.rawValue)")
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
    }
}
