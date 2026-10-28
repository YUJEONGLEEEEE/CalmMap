import SwiftData
import SwiftUI

struct ChildProfileEditor: View {
    let child: ChildProfile?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @AppStorage(ChildProfile.activeKey) private var activeChildID = ""
    @Query private var profiles: [ChildProfile]

    @State private var name: String
    @State private var crowd: Sensitivity
    @State private var loudness: Sensitivity
    @State private var triggers: [SoundCategory: TriggerLevel]
    @State private var brightLight: Bool
    @State private var flicker: Bool
    @State private var note: String
    @State private var sheetAlerts = AlertCenter()
    @State private var nameEdited = false
    private let initialDraft: Draft
    private let originalName: String
    private let childID: UUID?

    init(child: ChildProfile?) {
        self.child = child
        let draft = Draft(child)
        initialDraft = draft
        originalName = draft.name
        childID = child?.id
        _name = State(initialValue: draft.name)
        _crowd = State(initialValue: draft.crowd)
        _loudness = State(initialValue: draft.loudness)
        _triggers = State(initialValue: draft.triggers)
        _brightLight = State(initialValue: draft.brightLight)
        _flicker = State(initialValue: draft.flicker)
        _note = State(initialValue: draft.note)
    }

    private struct Draft: Equatable {
        var name = ""
        var crowd: Sensitivity = .usual
        var loudness: Sensitivity = .usual
        var triggers: [SoundCategory: TriggerLevel] = [:]
        var brightLight = false
        var flicker = false
        var note = ""

        init(name: String, crowd: Sensitivity, loudness: Sensitivity, triggers: [SoundCategory: TriggerLevel], brightLight: Bool, flicker: Bool, note: String) {
            self.name = name
            self.crowd = crowd
            self.loudness = loudness
            self.triggers = triggers
            self.brightLight = brightLight
            self.flicker = flicker
            self.note = note
        }

        init(_ child: ChildProfile?) {
            guard let child else { return }
            name = child.name
            crowd = child.crowd
            loudness = child.loudness
            triggers = child.triggers
            brightLight = child.brightLightSensitive
            flicker = child.flickerSensitive
            note = child.note
        }

        var normalized: Draft {
            var copy = self
            copy.name = NicknameValidator.trimmed(name)
            copy.note = NicknameValidator.trimmed(note)
            return copy
        }
    }

    private var draft: Draft {
        Draft(name: name, crowd: crowd, loudness: loudness, triggers: triggers, brightLight: brightLight, flicker: flicker, note: note)
    }

    private var hasChanges: Bool {
        draft.normalized != initialDraft.normalized
    }

    private var otherNames: [String] {
        let keepsOwnName = childID != nil && NicknameValidator.visible(name) == NicknameValidator.visible(originalName)
        guard !keepsOwnName else { return [] }
        return profiles.filter { $0.id != childID }.map(\.name)
    }

    private var nameError: String? {
        NicknameValidator.message(for: name, existing: otherNames, edited: nameEdited)
    }

    private var trimmedName: String {
        NicknameValidator.trimmed(name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("이름 또는 별명", text: $name)
                                .textInputAutocapitalization(.never)
                            Text("\(NicknameValidator.count(name))/\(NicknameValidator.limit)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(nameError == nil ? Color.secondary : Color.red)
                                .accessibilityLabel("\(NicknameValidator.limit)자 중 \(NicknameValidator.count(name))자")
                        }
                        if let nameError {
                            Text(nameError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: nameError)
                    .onChange(of: name) {
                        nameEdited = true
                    }
                    .onChange(of: nameError) {
                        if let nameError {
                            AccessibilityNotification.Announcement(nameError).post()
                        }
                    }
                } header: {
                    Text("아이")
                } footer: {
                    Text("아이 정보는 이 기기에만 저장되고 어디에도 전송하지 않아요.")
                }

                Section {
                    sensitivityPicker("사람 붐빔", systemImage: "person.3", selection: $crowd)
                    sensitivityPicker("큰 소리", systemImage: "speaker.wave.3", selection: $loudness)
                } header: {
                    Text("얼마나 예민한가요?")
                } footer: {
                    Text("예민할수록 같은 장소도 점수가 높게 나와요.")
                }

                Section {
                    ForEach(SoundCategory.triggerCandidates) { category in
                        Picker(selection: triggerBinding(category)) {
                            ForEach(TriggerLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        } label: {
                            Label(category.title, systemImage: category.symbolName)
                        }
                    }
                } header: {
                    Text("힘들어하는 소리")
                } footer: {
                    Text("소리 크기보다 종류가 더 중요할 때가 많아요.\n측정한 곳은 측정한 시간대 앞뒤로 실제로 들린 소리로, 그 밖에는 장소 유형으로 계산해요.")
                }

                Section {
                    Toggle(isOn: $brightLight) {
                        Label("밝은 조명이 힘들어요", systemImage: "sun.max")
                    }
                    Toggle(isOn: $flicker) {
                        Label("깜빡이는 조명이 힘들어요", systemImage: "lightbulb.max")
                    }
                } header: {
                    Text("빛")
                } footer: {
                    Text("측정할 때 조명을 체크한 곳에만 반영돼요.")
                }

                Section {
                    TextField("예: 이어머프를 쓰면 괜찮아져요", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("메모")
                } footer: {
                    Text("진정에 도움이 되는 것이나 미리 알아 두면 좋은 점을 적어 두세요.")
                }

                if child != nil {
                    Section {
                        Button("프로필 삭제", role: .destructive) {
                            confirmDelete()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalmBackdrop())
            .navigationTitle(child == nil ? "프로필 만들기" : "프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(NicknameValidator.visible(name).isEmpty || nameError != nil)
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .toastOverlay()
        .calmAlertOverlay()
        .environment(sheetAlerts)
    }

    private func confirmDelete() {
        sheetAlerts.present(
            systemImage: "trash",
            title: "\(originalName) 프로필을 삭제할까요?",
            message: "지도는 일반 기준으로 돌아가요.",
            cancelTitle: "취소",
            actionTitle: "삭제",
            isDestructive: true
        ) {
            delete()
        }
    }

    private func sensitivityPicker(_ title: String, systemImage: String, selection: Binding<Sensitivity>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
            StepSlider(title: title, options: Sensitivity.allCases, selection: selection) { $0.title }
        }
        .padding(.vertical, 4)
    }

    private func triggerBinding(_ category: SoundCategory) -> Binding<TriggerLevel> {
        Binding {
            triggers[category] ?? .fine
        } set: { level in
            triggers[category] = level == .fine ? nil : level
        }
    }

    private func cancel() {
        guard hasChanges else {
            dismiss()
            return
        }
        sheetAlerts.present(
            systemImage: "exclamationmark.circle",
            title: "저장하지 않고 나갈까요?",
            message: "지금 나가면 바꾼 내용이 저장되지 않아요.",
            cancelTitle: "계속 수정",
            actionTitle: "나가기",
            isDestructive: true
        ) {
            dismiss()
        }
    }

    private func save() {
        let target = child ?? ChildProfile(name: trimmedName)
        target.name = trimmedName
        target.crowd = crowd
        target.loudness = loudness
        target.triggers = triggers
        target.brightLightSensitive = brightLight
        target.flickerSensitive = flicker
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if child == nil {
            modelContext.insert(target)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toasts.show("저장하지 못했어요. 다시 시도해 주세요.", style: .warning)
            return
        }
        if child == nil {
            activeChildID = target.id.uuidString
        }
        toasts.show(child == nil ? "\(trimmedName) 맞춤 지도를 켰어요." : "\(trimmedName) 프로필을 저장했어요.", style: .success)
        dismiss()
    }

    private func delete() {
        guard let child, let childID else { return }
        let id = childID.uuidString
        let name = originalName
        let context = modelContext
        let toasts = toasts
        if activeChildID == id {
            activeChildID = ""
        }
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(child)
            do {
                try context.save()
                toasts.show("\(name) 프로필을 삭제했어요.")
            } catch {
                context.rollback()
                toasts.show("삭제하지 못했어요. 다시 시도해 주세요.", style: .warning)
            }
        }
    }
}

extension ChildProfile {
    static let activeKey = "activeChildID"
}
