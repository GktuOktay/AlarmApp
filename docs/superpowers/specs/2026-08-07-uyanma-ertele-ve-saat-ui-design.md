# Uyanma Onayı, Erteleme ve Saat-benzeri UI — Tasarım

**Tarih:** 2026-08-07  
**Durum:** Brainstorm onaylı — uygulama planı bekliyor  
**Kapsam:** Alarm çalma / ertele / toplu kapat; Watch erken-uyanma prompt’u (Apple Sleep Focus benzeri); iOS liste + düzenleme UI’si Saat hissiyatı; HealthKit + hareket/nabız motoru (F5 öne çekildi)  
**İlişkili:** PRD F2/F3/F5, `docs/01`, `docs/02` §3, `docs/03`, `docs/07` S1/S2/S6/W1/W2, `2026-08-06-alarm-first-model-design.md`, `apple-feel-swiftui`, `watch-connectivity-safe`

---

## 1. Ürün özeti

Kullanıcı alarm çalınca **Alarmı kapat / Ertele / Daha fazla** görür. Daha fazla seçeneklerde grubun bugünü, önümüzdeki 3 saati veya bugünkü tüm alarmları kapatır. Erteleme süresi **alarm bazlı**dır.

Watch’ta Apple Uyku Odak’ına benzer şekilde, uyanma penceresinde sensörler “uyanmış olabilirsin” derse **sorar**; onay olmadan alarm iptal edilmez (fail-safe).

iOS Alarmlar listesi Saat uygulaması hiyerarşisini izler: üstte **Uyku | Uyanma Zamanı**, altta **Diğer**.

---

## 2. Kararlar

| Konu | Karar |
|---|---|
| Algılama yaklaşımı | **3** — HealthKit Sleep + CoreMotion (+ nabız yedek); F5 bu spece dahil |
| Prompt tetikleme | Alarm penceresinde otomatik + her zaman manuel giriş |
| Çalma UI (telefon + Watch) | 2 katman: (1) Kapat / Ertele / Daha fazla (2) grup bugünü / 3 saat tümü / bugün tümü |
| Vazgeç / cevap yok | Hiçbir şey değişmez |
| Ertele yeri | Çalma ekranı birincil; süre S2’de alarm bazlı |
| Ertele varsayılan | `snoozeEnabled = true`, `snoozeMinutes = 9` (aralık 1…30) |
| Uyku satırı | `isWakeSchedule == true` olan **tek** alarm; yoksa satır “Alarm Yok” + DEĞİŞTİR → oluştur/ata |
| Kapsam (kapat) | Tek alarm · grup bugünü · 3s tüm pending · bugün tüm pending |
| Offline wake | Karar veren cihaz local uygular, sonra WC sync |
| Sessiz iptal | Yasak |
| UI dili | Native Saat hissi (turuncu vurgu, yeşil toggle, büyük saat); pixel-perfect Apple klonu değil |

---

## 3. Ekranlar

### 3.1 S1 — Alarmlar (Saat hiyerarşisi)

```
[Düzenle]     Alarmlar      [+]
┌─────────────────────────────┐
│ 🛏 Uyku | Uyanma Zamanı     │
│    06:30          [DEĞİŞTİR]│
│    Yarın Sabah / gün özeti  │
└─────────────────────────────┘
Diğer
  00:40  etiket…          [toggle]
  06:10  Alarm, Hafta içi [toggle]
```

- `isWakeSchedule` alarm üst kartta; diğerleri `Diğer` listesinde.
- DEĞİŞTİR → uyanma alarmı düzenleme / yoksa oluşturma akışı.
- Toggle `isActive`; swipe “Bugün kapat” mevcut davranış korunur.

### 3.2 S2 — Alarm Ekle / Düzenle

- Tekerlek saat seçici (büyük).
- Satırlar: Yinele · Etiket · Ses · **Ertele** (toggle) · **Erteleme süresi** (Ertele açıkken, turuncu değer, örn. “9 dk.”).
- Grup ataması mevcut alarm-first modelde kalır (formda veya detayda).
- Kaydet / Vazgeç (X + onay).

### 3.3 Çalma ekranı (iOS + Watch)

**Ekran 1**

1. Alarmı kapat → `DismissAlarm` (o instance / o alarmın bugünkü ilgili pending)
2. Ertele → `SnoozeAlarm` (`snoozeMinutes`)
3. Daha fazla seçenek → Ekran 2

**Ekran 2**

1. Bu grubun bugünkü alarmlarını kapat (grupsuzsa gizli veya disabled)
2. 3 saat içerisindeki tüm alarmları kapat
3. Bugünkü tüm alarmları kapat

Geri / Vazgeç → no-op.

### 3.4 Watch erken uyanma prompt (Apple modeli)

- Başlık: “Uyandın mı?”
- Gövde: “Kalan alarmları kapatayım mı?”
- Aksiyonlar: Evet (→ Ekran 2 veya kısa onay + varsayılan “grup bugünü / uyanma alarmı kalanları”) · Hayır
- Timeout / yok say → no-op; alarmlar planlandığı gibi çalar
- Haptic: belirgin ama alarm haptic’inden ayırt edilebilir; kullanıcı şikayetleri (Apple FP) için **varsayılan eşik muhafazakâr**; Ayarlar’da F5 toggle

**Evet sonrası varsayılan hedef:** uyanma schedule alarmının grubu varsa grup bugünü; yoksa yalnızca o alarmın bugünkü kalanları. Kullanıcı Ekran 2 ile genişletebilir.

### 3.5 Görsel dil

- Sistem fontu, `List`/`Form`, koyu semantik arka plan
- Vurgu turuncu; aktif toggle yeşil
- Büyük ince saat tipografisi; gri secondary meta
- Watch birincil buton ≥ 44×44 pt; `sensoryFeedback` / Watch haptic
- `apple-feel-swiftui`: snappy spring, Reduce Motion

---

## 4. Veri modeli

### 4.1 `Alarm` yeni alanlar

| Alan | Tip | Varsayılan | Not |
|---|---|---|---|
| `snoozeEnabled` | `Bool` | `true` | Kapalıysa çalma ekranında Ertele gizli/disabled |
| `snoozeMinutes` | `Int` | `9` | Clamp 1…30 |
| `isWakeSchedule` | `Bool` | `false` | En fazla bir alarm `true`; yeni `true` eskisini `false` yapar |

Migration: 0.0.x şema kırılması kabul (mevcut proje kuralı).

### 4.2 Instance / iptal

- Ertele: eski pending/fired instance iptal veya `snoozed` reason; yeni `AlarmInstance` `now + snoozeMinutes` ile pending + bildirim.
- `CancelReason` gerekirse: `snooze`, `userDismiss`, `wakePrompt`, `nextHoursWindow` (docs/03 ile senkron).

### 4.3 `WatchMessage` (docs/03 aynı değişiklik setinde)

Mevcut:

- `todayContextUpdate(TodayContext)`
- `wakeConfirmed(groupId:timestamp:)`

Ekle (önerilen):

- `snoozeApplied(alarmId:instanceId:fireDate:)`
- `dismissApplied(alarmId:instanceId:)`
- `bulkCancelApplied(scope: BulkCancelScope, timestamp:)`  
  `BulkCancelScope`: `groupToday(groupId)` | `allNextHours(hours:)` | `allToday`
- `wakePromptOffered(timestamp:)` — isteğe bağlı telemetry local-only; ağ yok

Undo mesajı yoksa 10 sn undo yalnızca local UI + reverse use case (mevcut W2 deseni); yeni case eklenmeden önce docs/03 güncellenir.

---

## 5. Domain use case’ler

| Use case | Girdi | Sonuç |
|---|---|---|
| `DismissAlarm` | alarmId / instanceId | İlgili pending iptal + bildirim cancel |
| `SnoozeAlarm` | alarmId, now | snoozeMinutes kadar yeni instance + schedule |
| `CancelGroupToday` | groupId | Bugünkü grup pending iptal (mevcut) |
| `CancelAllInNextHours` | hours (3), now | Tüm alarmların `[now, now+hours)` pending iptal |
| `CancelAllToday` | day | Bugün tüm pending iptal |
| `HandleWakePrompt` | choice + scope | Seçilen bulk/dismiss; Hayır → no-op |
| `SetWakeScheduleAlarm` | alarmId | Tek `isWakeSchedule` invariant |
| `WakeDetectionEngine` | window, samples | Prompt olayları üretir; **asla** doğrudan cancel |

Hepsi `AlarmAppCore` Domain; UI yok. `swift test` ile birim test.

---

## 6. WakeDetectionEngine (Watch)

### 6.1 Pencere

- Başlangıç: günün `isWakeSchedule` alarm saatinden **4 saat önce** (Apple patent diline yakın; ayarlanabilir sabit).
- Bitiş: uyanma alarmı ateşlendikten kısa süre sonra veya kullanıcı karar verince.
- Pencere dışında motor uyur.

### 6.2 Sinyaller (öncelik)

1. **HealthKit `sleepAnalysis`** — uykudan `awake` / in-bed bitişine geçiş (HKObserver / anchored).
2. **CoreMotion** — sürekli hareket eşiği (muhafazakâr).
3. **Nabız** — izin varsa yedek sinyal; sürekli sahte `HKWorkoutSession` **yok** (pil, Activity rings, Review). Anlık örnekleme yalnızca sistemin verdiği HR ile sınırlı; Sleep + hareket birincil.

### 6.3 Politika

- Algılama → yalnızca prompt (bildirim / Watch UI).
- Onay yok → alarmlar devam.
- Cooldown: aynı gece tekrar soru için min. aralık (örn. 20 dk) — FP azaltır.
- HealthKit izni yok / Sleep kapalı → motor disabled; manuel + çalma UI çalışır.
- Ayarlar (S7): “Otomatik uyanma sorusu” toggle; varsayılan **açık** ama eşik muhafazakâr; FP ölçümü sonrası gerekirse varsayılan kapalı (PRD F5).

---

## 7. Senkron ve fail-safe

1. Watch veya iPhone kararı local repository’de uygular.
2. Local bildirimleri iptal/ertele.
3. `WatchMessage` kuyruk (`sendMessage` → fallback `transferUserInfo`).
4. Karşı taraf aynı use case’i idempotent uygular.
5. Belirsizlik → alarmları açık bırak.

---

## 8. Kenar durumlar

| Durum | Davranış |
|---|---|
| `snoozeEnabled == false` | Ertele gizli; sadece kapat / daha fazla |
| Grupsuz alarm | “Bu grubun…” satırı yok |
| Birden fazla `isWakeSchedule` (bug) | Repository invariant: son yazılan kazanır |
| Uyanma alarmı yok | Üst kart “Alarm Yok”; DEĞİŞTİR oluşturur |
| 3 saat içinde alarm yok | Aksiyon no-op + kısa feedback |
| WC kopuk | Local uygula; sonra sync |
| Prompt sırasında alarm çalar | Çalma ekranı öncelikli; prompt ertelenir veya birleşik UI |
| Yanlış pozitif prompt | Hayır / yok say güvenli; cooldown |
| Reduce Motion | Kısa fade; vestibular spring yok |

---

## 9. Test özeti

**Core (`swift test`):**

- Snooze: yeni fireDate = now + snoozeMinutes; eski pending cancelled
- `isWakeSchedule` tekillik
- `CancelAllInNextHours(3)` yalnızca pencere içi
- `HandleWakePrompt` Hayır → state değişmez
- `WatchMessage` Codable round-trip (yeni case’ler)
- Idempotent bulk cancel

**Cihaz (insan / PR notu):**

- Gerçek iPhone + Watch çift: prompt → Evet → her iki tarafta sessizlik
- Offline: Watch karar → Bluetooth sonrası iPhone sync
- HealthKit izinsiz: motor kapalı, çalma UI sağlam

Simülatör WCSession güvenilmez — E2E iddiası yok.

---

## 10. Bilinçli kapsam dışı (bu spec)

- Apple Sleep Focus / sistem Uyku programına resmi entegrasyon (private API yok)
- Kullanıcıya “sistem zili” vaadi
- Cloud sync / analytics
- F5 kalibrasyon dashboard’u (sonraki iterasyon)
- Complication W3 detayı (ayrı görev; prompt’tan bağımsız)

---

## 11. Doküman güncellemeleri (uygulama ile aynı set)

- `docs/03` — Alarm alanları, CancelReason, WatchMessage, repository metotları
- `docs/07` — S1/S2/S6/W1 çalma + prompt
- `docs/00` / `04` — F5’in bu milestone’a çekildiği notu
- `memory.md` — kapılar: Uyanma/Ertele/Saat-UI
- `CHANGELOG.md` — kullanıcı Türkçe notları (sürüm bump ile)

---

## 12. Uygulama sırası (plan için taslak)

1. Core model + snooze/dismiss/bulk + testler  
2. WatchMessage + docs/03  
3. iOS S1/S2 Saat-benzeri UI + ertele alanları  
4. iOS + Watch çalma 2 katman UI  
5. WC sync yolları  
6. WakeDetectionEngine + izinler + S7 toggle  
7. CHANGELOG / VERSION / memory  

---

## Onay kaydı

- Aksiyon seti: tek alarm / grup bugünü / 3 saat / bugün tümü  
- Çalma: 2 katman + alarm bazlı ertele  
- Tetikleme: otomatik pencere + manuel  
- Algılama: yaklaşım 3 (HK Sleep + motion + nabız yedek)  
- UI: Saat listesi + Ekle formu referansları  
- Tasarım dili: native Saat hissi (bölüm 3.5)  
- Brainstorm bölüm onayları: kapsam ✓ · veri/motor ✓ · dil ✓  
