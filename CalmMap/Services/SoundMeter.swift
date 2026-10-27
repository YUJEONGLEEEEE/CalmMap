import AVFoundation
import Foundation
import Observation
import SoundAnalysis

@Observable
final class SoundMeter {
    enum State: Equatable {
        case idle
        case denied
        case measuring
        case finished
        case failed(String)
    }

    struct Summary {
        let ratios: [SoundCategory: Double]
        let averageDecibels: Double
        let peakDecibels: Double
        let soundScore: Double
        let durationSeconds: Int
    }

    static let duration: TimeInterval = 60

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var currentDecibels: Double = -80
    private(set) var recentCategories: [SoundCategory] = []
    private(set) var summary: Summary?
    private(set) var interruptionCount = 0

    private var engine: AVAudioEngine?
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ClassificationObserver?
    private let analysisQueue = DispatchQueue(label: "calmmap.sound.analysis")
    private var timer: Timer?
    private var startedAt: Date?
    private var categoryCounts: [SoundCategory: Int] = [:]
    private var decibelSamples: [Double] = []
    private var interruptionObserver: NSObjectProtocol?

    var remaining: Int { max(Int((Self.duration - elapsed).rounded(.up)), 0) }
    var progress: Double { min(elapsed / Self.duration, 1) }

    func start() async {
        guard state != .measuring else { return }
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .denied
            return
        }
        do {
            try begin()
        } catch {
            stopEngine()
            state = .failed("측정을 시작하지 못했어요. 다시 시도해 주세요.")
        }
    }

    func cancel() {
        stopEngine()
        state = .idle
        elapsed = 0
    }

    func reset() {
        summary = nil
        state = .idle
        elapsed = 0
        recentCategories = []
    }

    private func begin() throws {
        categoryCounts = [:]
        decibelSamples = []
        recentCategories = []
        summary = nil
        elapsed = 0

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let analyzer = SNAudioStreamAnalyzer(format: format)
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        let observer = ClassificationObserver { [weak self] label in
            Task { @MainActor [weak self] in self?.record(label: label) }
        }
        try analyzer.add(request, withObserver: observer)

        input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self, analysisQueue] buffer, time in
            let decibels = Self.decibels(of: buffer)
            analysisQueue.async {
                analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            Task { @MainActor [weak self] in self?.record(decibels: decibels) }
        }
        try engine.start()

        self.engine = engine
        self.analyzer = analyzer
        self.observer = observer
        startedAt = Date()
        state = .measuring

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began else { return }
            Task { @MainActor [weak self] in self?.interrupt() }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        if elapsed >= Self.duration {
            finish()
        }
    }

    private func record(label: String) {
        guard state == .measuring else { return }
        let category = SoundCategory.category(for: label)
        categoryCounts[category, default: 0] += 1
        recentCategories.removeAll { $0 == category }
        recentCategories.insert(category, at: 0)
        if recentCategories.count > 4 {
            recentCategories.removeLast()
        }
    }

    private func record(decibels: Double) {
        guard state == .measuring else { return }
        currentDecibels = decibels
        decibelSamples.append(decibels)
    }

    private func interrupt() {
        guard state == .measuring else { return }
        stopEngine()
        state = .idle
        elapsed = 0
        recentCategories = []
        interruptionCount += 1
    }

    private func finish() {
        guard state == .measuring else { return }
        stopEngine()
        let total = categoryCounts.values.reduce(0, +)
        var ratios: [SoundCategory: Double] = [:]
        if total > 0 {
            for (category, count) in categoryCounts {
                ratios[category] = Double(count) / Double(total)
            }
        }
        let average = Self.energyAverage(decibelSamples)
        let peak = Self.percentile(decibelSamples, 0.95)
        summary = Summary(
            ratios: ratios,
            averageDecibels: average,
            peakDecibels: peak,
            soundScore: SoundScore.score(ratios: ratios, averageDecibels: average, peakDecibels: peak),
            durationSeconds: Int(elapsed.rounded())
        )
        state = .finished
    }

    private func stopEngine() {
        timer?.invalidate()
        timer = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        analyzer?.completeAnalysis()
        engine = nil
        analyzer = nil
        observer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated private static func decibels(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -80 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            sum += channel[index] * channel[index]
        }
        let rms = sqrt(sum / Float(count))
        return rms > 0 ? max(Double(20 * log10(rms)), -80) : -80
    }

    private static func energyAverage(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return -80 }
        let energy = samples.map { pow(10, $0 / 10) }.reduce(0, +) / Double(samples.count)
        return 10 * log10(energy)
    }

    private static func percentile(_ samples: [Double], _ p: Double) -> Double {
        guard !samples.isEmpty else { return -80 }
        let sorted = samples.sorted()
        let index = min(Int(Double(sorted.count - 1) * p), sorted.count - 1)
        return sorted[index]
    }
}

private final class ClassificationObserver: NSObject, SNResultsObserving {
    private let onLabel: @Sendable (String) -> Void
    private let minimumConfidence = 0.3

    init(onLabel: @escaping @Sendable (String) -> Void) {
        self.onLabel = onLabel
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let top = result.classifications.first,
              top.confidence >= minimumConfidence else { return }
        onLabel(top.identifier)
    }
}
