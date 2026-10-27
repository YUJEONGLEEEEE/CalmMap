import Charts
import SwiftUI

struct PlaceDetailView: View {
    let placeCode: String
    @Environment(SensoryMapModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

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
            .background(CalmBackdrop())
            .navigationTitle(entry?.place.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
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
                Label("\(model.profile.displayName)에게 맞춘 점수", systemImage: "figure.and.child.holdinghands")
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.calmTint, in: RoundedRectangle(cornerRadius: 20))
        .calmGlass(RoundedRectangle(cornerRadius: 20))
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
