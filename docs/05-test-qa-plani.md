# Test ve QA Planı (Rev. 2 — Tamamen Native Swift)
## Akıllı Alarm Uygulaması

**Değişiklik notu:** `flutter_test`/`mocktail`/widget testleri kaldırıldı; tüm test katmanı `XCTest` (+ `XCTest` UI testleri) üzerinden yürütülüyor. Test piramidi kavramsal olarak değişmedi.

---

## 1. Test Piramidi

```
        ┌─────────────────┐
        │  Manuel/Uçtan Uca│  (gerçek cihaz, Watch senaryoları)     ~10%
        ├─────────────────┤
        │  Entegrasyon     │  (SwiftData, WatchConnectivity, notif.) ~25%
        ├─────────────────┤
        │  Birim Testleri  │  (AlarmAppCore: domain/use case)        ~65%
        └─────────────────┘
```

**Önemli avantaj:** `AlarmAppCore` paketi UI'dan tamamen bağımsız olduğu için, domain katmanı **hem iOS hem watchOS hedefine karşı aynı test paketiyle** doğrulanabilir (`swift test` komutu, simülatöre bile gerek kalmadan paket seviyesinde çalışır) — bu, hibrit mimaride mümkün olmayan bir hız avantajıdır.

---

## 2. Birim Testleri (`AlarmAppCore` — `XCTest`, saf Swift, UI bağımsız)

### Alarm Örneği Üretimi
| Test Case | Beklenen |
|---|---|
| 06:00-07:00, 5dk aralık | Ürün kararına göre 12 veya 13 örnek (PRD Açık Soru 1) |
| Başlangıç = bitiş saati | 1 örnek veya validasyon hatası |
| Aralık = 0 veya negatif | Validasyon hatası |
| Gece yarısını geçen aralık (23:30-00:30) | Tarih taşması `Calendar`/`DateComponents` ile doğru hesaplanır |
| Çakışan iki grup aynı gün aynı saatte | Uyarı tetiklenir |

### İstisna Hesaplama
| Test Case | Beklenen |
|---|---|
| `singleDay` istisna bugüne denk geliyor | O günün instance'ları `cancelled` |
| `dateRange` kısmen geçmişe taşıyor | Sadece bugün ve sonrası etkilenir |
| `weeklyOverride` — takvim haftası mı, 7 gün mü (PRD Açık Soru 2) | Ürün kararına göre kilitlenmiş davranış |
| Çakışan istisnalar | Öncelik kuralı test edilmiş olmalı |

### HandleWakeEvent Use Case (kritik: hem iOS hem Watch'ta aynı kod çalışıyor)
| Test Case | Beklenen |
|---|---|
| Geçerli `groupId` ile wake event | Pending instance'lar cancelled, notification'lar kaldırılır |
| Bilinmeyen/silinmiş `groupId` | Sessizce yok sayılır, crash olmaz |
| Duplicate wake event | Idempotent — ikinci çağrı no-op |
| **Watch context'inde çalıştırıldığında** | Aynı use case, `WatchCacheAlarmRepository` implementasyonuyla da doğru sonuç üretir — bu, paylaşımlı domain kodunun her iki platformda da güvenilir olduğunu kanıtlayan kritik bir test |

---

## 3. Entegrasyon Testleri

| Alan | Test | Ortam |
|---|---|---|
| SwiftData migration | `SchemaMigrationPlan` ile versiyon geçişi veri kaybı olmadan | CI, in-memory `ModelContainer` |
| `UNUserNotificationCenter` | Zamanlanmış bildirim `pendingNotificationRequests` içinde doğru görünüyor mu | Gerçek cihaz / simülatör |
| `WatchConnectivityService` | Mesaj encode/decode round-trip doğru mu | Birim test seviyesinde (Codable, cihaz gerektirmez) |
| `WCSession` reachability | `sendMessage` başarısız olduğunda `transferUserInfo` fallback tetikleniyor mu | **Gerçek cihaz çifti zorunlu** (simülatör WatchConnectivity'yi güvenilir taklit edemez) |

---

## 4. Uçtan Uca / Manuel Test Senaryoları (Gerçek Cihaz Zorunlu — değişmedi)

| # | Senaryo | Kabul Kriteri |
|---|---|---|
| E2E-1 | 10 alarmlı grup kur, 4. alarmda Watch'ta "Uyandım"a bas | Kalan 6 alarm hem Watch hem iPhone'da susar, 5sn içinde |
| E2E-2 | Watch Bluetooth'u kapalıyken "Uyandım"a bas, sonra aç | Watch anında susar; Bluetooth açılınca iPhone senkronize olur |
| E2E-3 | "Uyandım"a bas, 5sn içinde "Hayır, devam etsin" de | Alarmlar normal akışına döner |
| E2E-4 | Uygulama arka plandayken zamanlanmış alarm çalsın | Bildirim doğru saatte/sesle gelir |
| E2E-5 | "Rahatsız Etmeyin" modundayken alarm | Critical Alert onayı öncesi/sonrası davranış farkı test edilir |
| E2E-6 | "Bu hafta pas geç" sonrası hafta bitince | Bir sonraki hafta gruplar normale döner |
| E2E-7 (v2) | Uyurken doğal hareket → yanlış pozitif | Cooldown mekanizması sınırlar |

---

## 5. UI Testleri (Yeni Bölüm — SwiftUI'ye özgü)

Flutter widget testlerinin yerini `XCUITest` (Xcode UI Testing) alıyor:

| Test | Kapsam |
|---|---|
| S1 → S2 → grup oluşturma tam akışı | `XCUIApplication` ile uçtan uca navigasyon, form doldurma |
| Swipe-to-action (`.swipeActions()`) | Sola kaydırma jesti + buton tıklama simülasyonu |
| Dynamic Type ekran görüntüsü karşılaştırması | Snapshot testing (ör. `swift-snapshot-testing` kütüphanesi) ile büyük yazı tipinde layout kırılması kontrolü |

---

## 6. Performans ve Kararlılık Testleri (değişmedi)

- **Instruments (Time Profiler, Energy Log):** Sprint 7 ve Sprint 13'te pil/CPU profili.
- **Yük testi:** 1 yıl / günlük 10 alarm / 50 istisna ile SwiftData sorgu performansı (takvim ekranı açılış < 300ms hedefi).
- **Crash-free session:** TestFlight + Xcode Organizer crash raporları (>%99.5 hedefi).

---

## 7. Erişilebilirlik Testleri (değişmedi, artık native modifier'larla daha kolay doğrulanabilir)

- VoiceOver ile S1-S5 tam tamamlanabilirlik (`accessibilityLabel`, `accessibilityHint` modifier denetimi).
- Dynamic Type en büyük ayarında layout testi.
- Watch'ta her etkileşimde `WKInterfaceDevice.current().play(_:)` haptic tetiklemesi doğrulaması.

---

## 8. Regresyon Test Kontrol Listesi (Her Sürüm Öncesi — değişmedi)

- [ ] Tüm F1-F4 manuel akışları uçtan uca çalışıyor
- [ ] Watch bağlı değilken uygulama hiçbir crash/deadlock vermiyor
- [ ] Bildirim izinleri reddedildiğinde anlamlı uyarı gösteriliyor
- [ ] SwiftData migration'lar veri kaybı yaratmıyor
- [ ] `AlarmAppCore` paket testleri (`swift test`) CI'da yeşil
- [ ] Açık kaynak lisans/telif başlıkları tüm yeni dosyalarda mevcut
