import SwiftUI
import AlarmAppCore

struct SoundPickerView: View {
    @Binding var soundId: String
    @Binding var soundVolumePercent: Double
    let soundPreview: AlarmSoundPreview

    var body: some View {
        Form {
            Section {
                Picker("create.sound_section", selection: $soundId) {
                    ForEach(AlarmSoundCatalog.all) { sound in
                        Text(LocalizedStringKey(sound.displayNameKey)).tag(sound.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: soundId) { _, newId in
                    soundPreview.play(
                        soundId: newId,
                        volume: soundVolumePercent / 100
                    )
                }
                .sensoryFeedback(.selection, trigger: soundId)

                VStack(alignment: .leading) {
                    Text("create.sound_volume")
                    Slider(
                        value: $soundVolumePercent,
                        in: 0...100,
                        step: 1,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                soundPreview.play(soundId: soundId, volume: soundVolumePercent / 100)
                            }
                        }
                    )
                    .onChange(of: soundVolumePercent) { _, newValue in
                        soundPreview.setVolume(newValue / 100)
                    }
                }
                Text("create.sound_volume_footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("create.sound_section"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            soundPreview.stop()
        }
    }
}
