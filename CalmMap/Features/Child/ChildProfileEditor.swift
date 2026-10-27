import SwiftData
import SwiftUI

struct ChildProfileEditor: View {
    let child: ChildProfile?
    var onSaved: (ChildProfile) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @AppStorage(ChildProfile.activeKey) private var activeChildID = ""

    @State private var name = ""
    @State private var crowd: Sensitivity = .usual
    @State private var loudness: Sensitivity = .usual
    @State private var triggers: [SoundCategory: TriggerLevel] = [:]
    @State private var brightLight = false
    @State private var flicker = false
    @State private var note = ""
    @State private var confirmingDelete = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름 또는 별명", text: $name)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("아이")
                } footer: {
                    Text("아이 정보는 이 기기에만 저장되고 어디에도 전송하지 않아요.")
                }

                Section {
                    sensitivityPicker("사람 붐빔", systemImage: "person.3", selection: $crowd)
                    sensitivityPicker("큰 소리", systemImage: "speaker.wave.3", selection: $loudness)
                } header: {
                    Text("얼마나 예민한가요")
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
                    Text("소리 크기보다 종류가 더 중요할 때가 많아요. 측정한 곳은 실제로 들린 소리로, 측정 전인 곳은 장소 유형으로 계산해요.")
                }

                Section("빛") {
                    Toggle(isOn: $brightLight) {
                        Label("밝은 조명이 힘들어요", systemImage: "sun.max")
                    }
                    Toggle(isOn: $flicker) {
                        Label("깜빡이는 조명이 힘들어요", systemImage: "lightbulb.max")
                    }
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
                            confirmingDelete = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalmBackdrop())
            .navigationTitle(child == nil ? "아이 프로필 만들기" : "프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("\(child?.name ?? "") 프로필을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { delete() }
            } message: {
                Text("지도는 일반 기준으로 돌아가요.")
            }
            .onAppear(perform: load)
        }
    }

    private func sensitivityPicker(_ title: String, systemImage: String, selection: Binding<Sensitivity>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
            Picker(title, selection: selection) {
                ForEach(Sensitivity.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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

    private func load() {
        guard let child else { return }
        name = child.name
        crowd = child.crowd
        loudness = child.loudness
        triggers = child.triggers
        brightLight = child.brightLightSensitive
        flicker = child.flickerSensitive
        note = child.note
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
            activeChildID = target.id.uuidString
        }
        try? modelContext.save()
        toasts.show(child == nil ? "\(trimmedName) 맞춤 지도를 켰어요." : "\(trimmedName) 프로필을 저장했어요.", style: .success)
        onSaved(target)
        dismiss()
    }

    private func delete() {
        guard let child else { return }
        if activeChildID == child.id.uuidString {
            activeChildID = ""
        }
        let name = child.name
        modelContext.delete(child)
        try? modelContext.save()
        toasts.show("\(name) 프로필을 삭제했어요.")
        dismiss()
    }
}

extension ChildProfile {
    static let activeKey = "activeChildID"
}
