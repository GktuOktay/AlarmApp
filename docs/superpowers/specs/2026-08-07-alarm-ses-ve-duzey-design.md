# Alarm Ses ve Ses Düzeyi — Tasarım

**Tarih:** 2026-08-07  
**Durum:** Onaylı (brainstorm)  
**Kapsam:** Alarm başına ses seçimi + göreli ses düzeyi; CC0 paket; iOS bildirim zamanlama; S2 UI önizleme  
**İlişkili:** `docs/03`, `docs/07` S2, K4 Critical Alert, `2026-08-06-alarm-first-model-design.md`

---

## 1. Ürün özeti

Kullanıcı her alarm için bir **uygulama sesi** seçer ve **0–100 kaydırıcı** ile göreli düzey ayarlar. Seçimde kısa önizleme çalar. Apple Clock zil kataloğu kullanılmaz (API/lisans yok); sesler CC0 paket olarak uygulama bundle’ına gömülür.

Konumlama dili: **“Uygulama sesleri”** — “sistem zilleri” vaadi yok.

---

## 2. Kararlar

| Konu | Karar |
|---|---|
| Ses kaynağı | Bundle’da CC0 / public domain paket (~6–8 ton) + `default` = `UNNotificationSound.default` |
| Apple sistem dosyaları | Kopyalanmaz / private path kullanılmaz |
| Ses düzeyi UI | Sürekli Slider 0–100 → model `soundVolume: Double` `0.0…1.0` |
| Critical Alert | K4: garantisiz; entitlement yoksa volume sistem sesine zorlanmaz, değer saklanır |
| Önizleme | Listeden seçilince kısa çalma (`AVAudioPlayer`); kaydırıcı hareketinde otomatik yeniden çalmaz |
| Mimari | Katalog + volume Domain/Core; `.caf` dosyaları yalnızca iOS target |
| Watch | Bu spec dışı (sonraki faz) |
| Kullanıcı dosya import | Yok |

---

## 3. Veri modeli

### 3.1 `Alarm` alanları

| Alan | Tip | Varsayılan | Not |
|---|---|---|---|
| `soundId` | `String` | `"default"` | Katalog id; bilinmeyen → `default` |
| `soundVolume` | `Double` | `1.0` | Clamp `0.0…1.0` |

Mevcut kayıtlar: migration yok (0.0.x şema kırılması kabul); yeni alan varsayılan `1.0`.

### 3.2 Katalog (Core, saf veri)

```swift
public struct AlarmSound: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayNameKey: String  // String Catalog / LocalizedStringKey kaynağı
    public let fileName: String?       // nil → sistem varsayılanı
}

public enum AlarmSoundCatalog {
    public static let all: [AlarmSound]
    public static func resolve(_ id: String) -> AlarmSound  // bilinmeyen → default
    public static func clampVolume(_ value: Double) -> Double  // 0...1
}
```

- `id == "default"` → `fileName == nil` → `UNNotificationSound.default`
- Diğer id’ler → iOS bundle’daki `.caf`; `UNNotificationSound(named:)` için **uzantısız** dosya adı (ör. `classic_bell`)

### 3.3 DTO / use case

`CreateAlarmRequest`, `PreparedAlarm`, `AlarmSummary` → `soundVolume` eklenir.  
`CreateAlarm.prepare` volume’u clamp eder; boş/bilinmeyen `soundId` → `"default"`.

`docs/03-veri-modeli-ve-arayuzler.md` aynı changeset’te güncellenir.

---

## 4. Bildirim zamanlama

`NotificationScheduling.schedule` imzası genişler:

```swift
func schedule(
    instanceId: UUID,
    fireDate: Date,
    title: String,
    body: String,
    soundId: String,
    soundVolume: Double
) async throws
```

### 4.1 Ses çözümleme

1. `AlarmSoundCatalog.resolve(soundId)`
2. `fileName == nil` → `.default`
3. Aksi → `UNNotificationSound(named:)` (bundle’da yoksa → `.default`; **planlama yine yapılır** — fail-safe, sessiz iptal yok)

### 4.2 Düzey

| Critical entitlement | Davranış |
|---|---|
| Var | `defaultCriticalSound(withAudioVolume:)` veya `criticalSoundNamed(_:withAudioVolume:)` — volume = clamp |
| Yok | Normal `UNNotificationSound`; `soundVolume` yalnızca saklanır / önizlemede kullanılır |

UI footer (entitlement yokken): düzeyin cihaz sistem sesine bağlı olabileceğini kısaca belirtir.

Repo, instance planlarken alarmın `soundId` / `soundVolume` değerlerini scheduler’a iletir.

---

## 5. iOS UI

### 5.1 S2 — Oluştur / Düzenle

Form’da **Ses** bölümü:

```
Section
├── Katalog listesi (seçili ✓)
│     onSelect → soundId güncelle + önizleme çal (volume = slider)
├── Slider 0…100  (“Ses düzeyi”)
└── Footer: Critical yoksa dürüst not
```

Varsayılan UI state: `soundId = "default"`, slider = 100.

Önizleme: iOS-only helper (`AlarmSoundPreview`); Core’a AVFoundation bağlanmaz. Seçim değişince önceki önizleme durur.

### 5.2 S3 — Detay

Ses görünen adı + düzey yüzdesi özeti. Tam düzenleme ekranı bu fazda yoksa: Ses bölümü önce **S2 Create**’te; mevcut alarmı düzenleme ayrı görev (aynı Ses UI bileşeni paylaşılır).

### 5.3 Dil

TR/EN lokalizasyon anahtarları. Kullanıcıya “Uygulama sesleri”.

---

## 6. Ses paketi (assets)

| Konum | İçerik |
|---|---|
| `AlarmApp-iOS/Sounds/*.caf` | ≤30 sn, tercihen mono, bildirim uyumlu |
| `AlarmApp-iOS/Sounds/SOUNDS.md` | id, dosya adı, kaynak URL, lisans (CC0), süre |

v1 hedef: ~6–8 “standart” alarm tonu (mekanik zil, elektronik buzz, çan, bip, ring, …) — tarama CC0 kaynaklardan (ör. BigSoundBank). Atıf zorunlu değil; kaynak yine `SOUNDS.md`’de tutulur.

Xcode: Sound dosyaları iOS target **Copy Bundle Resources**.

---

## 7. Test

| Katman | Senaryo |
|---|---|
| Core | `resolve` bilinmeyen id → default |
| Core | `clampVolume` sınırları |
| Core | `CreateAlarm` soundId + soundVolume taşır |
| Core | Scheduler mock: named mapping / fallback default (mümkünse) |
| Manuel (insan) | Önizleme; bildirim sesi cihaz/simülatör |

`swift test` AlarmAppCore’da; tam `xcodebuild` ajan varsayılanında yok.

---

## 8. Doküman ve memory

- `docs/03` — `soundVolume`, katalog notu, schedule imzası  
- `docs/07` S2 — Ses + Slider bileşen haritası  
- `docs/01` — “kullanıcı seçimi” → uygulama paketi + düzey  
- `memory.md` — ses/düzey kapısı  
- Kullanıcıya görünen milestone’da `CHANGELOG.md` + gerekirse `VERSION`

---

## 9. Kapsam dışı

- Watch bildirimi / bilekte ses paketi  
- Files / müzik kütüphanesinden özel ses  
- Critical Alert entitlement başvurusu ve App Store review süreci  
- Grup düzeyinde ortak ses (alarm-first: ses alarmda)

---

## 10. Uygulama sırası (yüksek seviye)

1. Core: katalog + `soundVolume` + CreateAlarm/DTO/repo  
2. Scheduler imza + mapping + fail-safe fallback  
3. Unit testler  
4. CC0 tarama → `.caf` + `SOUNDS.md`  
5. S2/S3 UI + önizleme + lokalizasyon  
6. Docs / memory / changelog

Detaylı görev kırılımı → ayrı implementation plan (`writing-plans`).

---

## Onay kaydı

| Rol | Not | Tarih |
|---|---|---|
| Ürün | Brainstorm bölümleri 1–4 onay | 2026-08-07 |
