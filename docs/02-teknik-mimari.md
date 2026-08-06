# Teknik Mimari Dokümanı (Rev. 2 — Tamamen Native Swift)
## Akıllı Alarm Uygulaması

**İlişkili dokümanlar:** `00-PRD-urun-gereksinim-dokumani.md`, `03-veri-modeli-ve-arayuzler.md`
**Değişiklik notu:** Bu revizyon, Flutter + native Swift hibrit mimarisinden **tamamen native Swift/SwiftUI, tek codebase** mimarisine geçişi yansıtır. Önceki dokümandaki ADR-1 ve ADR-2 (Flutter/watchOS ayrımı, platform channel köprüsü) bu kararla birlikte geçersiz kalmıştır.

---

## 1. Mimari Kararlar ve Gerekçeleri (ADR — Güncel)

### ADR-1 (Rev.): Tek dil, tek workspace — SwiftUI (iOS) + SwiftUI (watchOS) + paylaşımlı Swift Package
**Karar:** iPhone ve Watch uygulamaları ayrı target'lar olarak aynı Xcode workspace'inde, ortak domain/data mantığı ise ayrı bir **Swift Package (Core)** içinde tutulur ve her iki target da bu paketi import eder.
**Gerekçe:** Flutter'ın watchOS'ta çalışmaması nedeniyle zaten iki ayrı kod tabanı gerekiyordu (bkz. Rev.1); Swift'e geçişle bu ayrım ortadan kalkmıyor (iOS ve watchOS hâlâ ayrı target'lar, ayrı UI) ama **ortak iş mantığı artık paylaşılabiliyor** — bu, önceki mimarideki en büyük sürtünme noktası olan platform channel köprüsünü tamamen ortadan kaldırıyor.
**Sonuç:** Daha az kod tekrarı, daha az senkronizasyon hatası riski, tek dilde debug edilebilirlik.

### ADR-2 (Rev.): WatchConnectivity doğrudan kullanılır, köprü katmanı yok
**Karar:** `WCSession` hem iOS hem watchOS tarafında doğrudan Swift kodundan kullanılır. Önceki mimarideki `MethodChannel`/`EventChannel` katmanı tamamen kaldırıldı.
**Etki:** Veri modeli dokümanındaki "Platform Kanal Sözleşmesi" bölümü artık geçersiz; WatchConnectivity mesaj sözleşmesi olduğu gibi korunuyor (bu zaten native bir API, dilden bağımsızdı).

### ADR-3: Local-first veri katmanı, sunucu yok (değişmedi)
**Karar:** Tüm veri cihaz üzerinde tutulur, bulut senkronizasyonu yok (PRD NG2).

### ADR-4 (Rev.): Persistans — SwiftData (iOS 17+/watchOS 10+ hedeflenirse) veya GRDB.swift (daha geniş sürüm desteği isteniyorsa)
**Karar:** İki seçenek değerlendirildi:
- **SwiftData:** Apple'ın native ORM'i, `@Model` makrosuyla çok az boilerplate, SwiftUI ile doğrudan entegre (`@Query`). Minimum iOS 17 gerektirir.
- **GRDB.swift:** Daha olgun, SQL'e daha yakın kontrol, minimum iOS sürümü daha esnek, migration yönetimi daha öngörülebilir.
**Öneri:** Proje yeni başladığı ve minimum iOS sürümü kısıtı yoksa **SwiftData** tercih edilsin (daha az kod, Apple'ın uzun vadeli yönü). Eğer geniş cihaz/sürüm desteği önemliyse **GRDB** tercih edilmeli. Bu doküman setinin geri kalanı SwiftData varsayımıyla yazılmıştır; GRDB'ye geçiş sadece veri katmanını etkiler, domain/UI katmanları etkilenmez (bkz. Bölüm 6, katman ayrımı).

### ADR-5 (Rev.): State management — SwiftUI native (`@Observable`, `@State`, `@Environment`)
**Karar:** Riverpod yerine Swift'in kendi `Observation` framework'ü (`@Observable` makrosu, iOS 17+) kullanılır. Domain katmanındaki use case'ler `@Observable` ViewModel'ler aracılığıyla View'lara bağlanır.
**Gerekçe:** Üçüncü parti state management kütüphanesine ihtiyaç kalmıyor; Apple'ın kendi ekosistemiyle tam uyumlu, öğrenme eğrisi düşük.

### ADR-6: Alarm tetikleme — UNUserNotificationCenter (değişmedi, artık doğrudan)
**Karar:** `UNUserNotificationCenter` doğrudan Swift'ten kullanılır (önceki mimaride `flutter_local_notifications` paketinin sarmaladığı native API'nin ta kendisi). Kritik Alert / tam ekran deneyimi hâlâ Apple onayına bağlı `.criticalAlert` entitlement'ıyla sınırlı (bkz. Rev.1 Risk Kaydı, değişmedi).

---

## 2. Sistem Mimarisi — Katmanlı Görünüm (Güncel)

```
┌─────────────────────────────────────────────────────────────────┐
│                     AlarmAppCore (Swift Package)                 │
│                  — iOS ve watchOS target'ları tarafından          │
│                    ortak kullanılır —                             │
│                                                                     │
│  Domain Layer                                                     │
│  ├── UseCases: CreateAlarmGroup, CancelGroupForToday,              │
│  │   SkipWeek, ScheduleException, HandleWakeEvent                  │
│  └── Entities: AlarmGroup, AlarmInstance, Exception                │
│                                                                     │
│  Data Layer                                                       │
│  ├── SwiftData ModelContainer / Repository protokolleri            │
│  └── NotificationScheduler (UNUserNotificationCenter sarmalayıcı) │
│                                                                     │
│  Connectivity Layer                                               │
│  └── WatchConnectivityService (WCSessionDelegate, her iki          │
│      target'ta da kullanılan ortak protokol + platform-specific    │
│      küçük implementasyon farkları #if os(watchOS) ile ayrılır)    │
└─────────────────────────────────────────────────────────────────┘
              │ import AlarmAppCore                │ import AlarmAppCore
              ▼                                      ▼
┌───────────────────────────┐          ┌───────────────────────────┐
│   iOS App Target (SwiftUI) │          │  watchOS App Target        │
│                              │          │  (SwiftUI)                  │
│  ├── Views (S1-S8)          │◄────────►│  ├── Views (W1-W3)          │
│  ├── @Observable ViewModels │  WCSession│  ├── @Observable ViewModels │
│  └── HealthKit erişimi (v2) │          │  ├── WakeDetectionEngine    │
│                              │          │  │   (v2: HealthKit+Motion) │
│                              │          │  └── ComplicationController│
└───────────────────────────┘          └───────────────────────────┘
```

**Katman kuralı:** `AlarmAppCore` paketi hiçbir şekilde `SwiftUI` veya platforma özel UI kod içermez (sadece `Foundation`, `SwiftData`, `WatchConnectivity`, `HealthKit`, `CoreMotion` gibi framework'lere bağımlıdır) — böylece ileride bu paket teorik olarak bir Android/diğer platform portu için de referans domain mantığı olarak kalabilir (kod paylaşımı olmasa da mantık paylaşımı).

---

## 3. Kritik Akış: "Uyandım" Sinyali Uçtan Uca (Güncel, Köprüsüz)

```
1. [Watch] Kullanıcı W1'de "Uyandım" butonuna basar
2. [Watch] WakeConfirmationViewModel (@Observable), AlarmAppCore'daki
   HandleWakeEvent use case'ini DOĞRUDAN çağırır (aynı süreç içinde,
   ara katman/köprü yok)
3. [Watch] Watch'ın kendi local SwiftData store'undaki (hafif önbellek)
   bugünkü instance'lar cancelled işaretlenir, Watch'ın kendi
   UNUserNotificationCenter'ından pending notification'lar kaldırılır
4. [Watch → iPhone] WatchConnectivityService.send(.wakeConfirmed(groupId:timestamp:))
   - WCSession.sendMessage (reachable ise) veya
   - WCSession.transferUserInfo (kuyruklu, garanti teslim)
5. [iPhone] WatchConnectivityService, WCSessionDelegate callback'inde
   mesajı alır → AynıAlarmAppCore paketindeki HandleWakeEvent use case'ini
   çağırır (iPhone tarafında da AYNI use case kodu, farklı repository
   implementasyonu üzerinden çalışır — kod tekrarı yok)
6. [iPhone] SwiftData üzerinden ana veritabanı güncellenir, pending
   UNNotificationRequest'ler kaldırılır
7. [iPhone/UI] @Query ile SwiftData'yı dinleyen SwiftUI View'lar
   otomatik yeniden render olur (S1 grup kartı "Bugün tamamlandı ✓")
```

**Önceki mimariyle fark:** Adım 2 ve 5'te artık `HandleWakeEvent` use case'i **tek bir yerde tanımlı, iki farklı runtime'da (Watch ve iPhone) aynı kod olarak çalışıyor**. Flutter+Swift hibrit mimaride bu mantığın bir kısmı Dart'ta bir kısmı Swift'te ayrı ayrı yazılmak zorundaydı; şimdi tek seferde yazılıp test ediliyor.

---

## 4. Veri Senkronizasyon Stratejisi (değişmedi, mekanizma aynı)

| Veri | Yön | Mekanizma | Sıklık |
|---|---|---|---|
| Bugünkü aktif alarm grupları özeti | iPhone → Watch | `WCSession.updateApplicationContext` | Grup değiştiğinde / gün başında |
| Wake event onayı | Watch → iPhone | `sendMessage` (reachable) / `transferUserInfo` (kuyruklu) | Kullanıcı aksiyonunda anlık |
| Tam grup/istisna geçmişi | — | Sadece iPhone'daki SwiftData store'da | — |

---

## 5. Performans ve Pil Tüketimi Önlemleri (değişmedi, native olması avantaj)

- Zamanlama önceden yapılır (`UNNotificationRequest`), arka planda sürekli çalışma gerekmez.
- HealthKit (v2): `HKAnchoredObjectQuery` + `enableBackgroundDelivery`, polling değil.
- CoreMotion: sadece alarm penceresinde aktif.
- **Ek avantaj:** Flutter engine'in başlatma/köprü maliyeti ortadan kalktığı için soğuk başlatma (cold start) süresi ve bellek ayak izi native SwiftUI ile genelde daha düşük olur — özellikle Watch tarafında pil/performans kritik olduğundan bu doğrudan fayda sağlar.

---

## 6. Modül Bağımlılık Diyagramı (Güncel)

```
iOS Views/ViewModels  ─┐
                        ├─→  AlarmAppCore (Domain + Data + Connectivity)  ─→  SwiftData / WCSession / HealthKit
watchOS Views/ViewModels─┘
```

Tek yönlü bağımlılık: UI katmanları (`iOS`, `watchOS`) her zaman `AlarmAppCore`'a bağımlıdır, asla tersi değil. Bu, veri katmanının (`ADR-4`) SwiftData'dan GRDB'ye veya başka bir çözüme geçirilmesi gerekirse **sadece `AlarmAppCore` içindeki Data Layer'ın değişmesini, UI katmanlarının hiç etkilenmemesini** garanti eder.

---

## 7. Hata Senaryoları ve Dayanıklılık (değişmedi)

| Senaryo | Davranış |
|---|---|
| Watch takılı değil / eşleşmemiş | Uygulama tamamen manuel modda (F1, F3, F4) sorunsuz çalışır |
| Bluetooth kapalı, Watch yakın ama bağlı değil | `transferUserInfo` kuyruklanır, bağlantı kurulunca senkron tamamlanır |
| SwiftData şema değişimi | `VersionedSchema` + `SchemaMigrationPlan` ile versiyon bazlı geçiş |
| HealthKit izni sonradan geri çekilirse (v2) | F5 sessizce devre dışı kalır, kullanıcıya bildirim gösterilir |
