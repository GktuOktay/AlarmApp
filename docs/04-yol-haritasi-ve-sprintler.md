# Yol Haritası ve Sprint Planlaması (Rev. 2 — Tamamen Native Swift)
## Akıllı Alarm Uygulaması

**Varsayım:** 1 kıdemli Swift/SwiftUI geliştirici + gerektiğinde part-time tasarım desteği. Sprint uzunluğu: 1 hafta.
**Değişiklik notu:** Flutter köprü katmanına ayrılan sprintler (önceki Sprint 6'nın büyük kısmı) kaldırıldı; toplam süre kısaldı.

---

## Sürüm Planı (Güncel)

| Sürüm | Kapsam | Hedef Süre |
|---|---|---|
| **MVP (v0.1)** | F1, F3 (manuel kontroller), SwiftData, temel bildirimler — Watch YOK | Sprint 1-3 |
| **v1.0** | + F2 (Watch "Uyandım"), F4 (takvim/ileri planlama) | Sprint 4-7 |
| **v1.1** | Cilalama, App Store hazırlığı, Critical Alert başvurusu | Sprint 8-9 |
| **v2.0** | F5 — otomatik uyanma algılama (HealthKit/CoreMotion) | Sprint 10-14 |

> **Not (2026-08-07):** F5 tarzı erken-uyanma **onay prompt’u** (Watch “Uyandın mı?”, S7 toggle, HealthKit Sleep + hareket; onaysız iptal yok) uyanma/ertele/Saat-UI milestone’una çekildi. Tam F5 kalibrasyon / saha testi hâlâ v2.0 kapsamındadır.

---

## Faz 0 — Proje Kurulumu (Sprint 0, 1 hafta)

| Görev | SP | Çıktı |
|---|---|---|
| Xcode workspace: iOS target + watchOS target + `AlarmAppCore` Swift Package | 5 | Çalışan iskelet, her iki target da paketi import ediyor |
| SwiftData `ModelContainer` kurulumu + ilk şema | 3 | Boş şema, migration altyapısı |
| CI pipeline (GitHub Actions: `xcodebuild test`, SwiftLint) | 5 | `.github/workflows/ci.yml` |
| Lisans, README, CONTRIBUTING iskeleti | 2 | Açık kaynak temel dosyalar |

**Sprint 0 Toplam:** 15 SP *(önceki revizyonla aynı — kurulum karmaşıklığı platformdan bağımsız benzer)*

---

## Faz 1 — MVP: Çekirdek Alarm Motoru (Sprint 1-3, 3 hafta — önceki revizyonda 4 hafta idi)

### Sprint 1 — Domain + Data Katmanı
| Görev | SP |
|---|---|
| `AlarmGroup`, `AlarmInstance`, `AlarmException` SwiftData modelleri | 3 *(SwiftData boilerplate'i SQL+Drift'e göre daha az)* |
| `AlarmRepository` protokolü + `SwiftDataAlarmRepository` implementasyonu | 5 |
| `CreateAlarmGroup` use case + alarm örneği üretme algoritması | 8 |
| Birim testleri (XCTest): sınır durumları | 5 |

**Sprint 1 Toplam:** 21 SP

### Sprint 2 — Bildirim Zamanlama
| Görev | SP |
|---|---|
| `UNUserNotificationCenter` doğrudan entegrasyon (sarmalayıcı katman ince, native API zaten Swift) | 3 |
| `NotificationScheduler`: grup oluşturulduğunda instance'lar için zamanlama | 5 *(Flutter plugin sarmalama maliyeti yok)* |
| İptal mekanizması | 2 |
| Actionable notification aksiyonları (Ertele/Kapat) | 5 |
| Gerçek cihaz entegrasyon testi | 3 |

**Sprint 2 Toplam:** 18 SP

### Sprint 3 — S1/S2/S3 Ekranları + Manuel Kontroller + Onboarding
| Görev | SP |
|---|---|
| S1 Ana Ekran (SwiftUI `List` + swipe actions — native `.swipeActions()` modifier, Flutter'da custom yazmaktan daha az efor) | 5 |
| S2 Grup Oluştur/Düzenle formu (SwiftUI `Form`) | 5 |
| S3 Grup Detay ekranı | 3 |
| F3 "Bugün Kapat" / "Bu Hafta Pas Geç" uçtan uca | 8 |
| S8 Onboarding akışı | 5 |
| Bug bash + MVP regresyon testi | 5 |

**Sprint 3 Toplam:** 31 SP

**Faz 1 Milestone:** MVP TestFlight'a dağıtılabilir, Watch olmadan tam fonksiyonel.

---

## Faz 2 — v1.0: Watch Entegrasyonu ve Takvim (Sprint 4-7, 4 hafta — önceki revizyonda 5 hafta idi)

### Sprint 4 — Watch Companion + WatchConnectivity (birleşik sprint)
| Görev | SP |
|---|---|
| SwiftUI W1 ana ekran | 5 |
| `WatchConnectivityService` implementasyonu (her iki taraf, ortak protokol `AlarmAppCore`'da) | 8 |
| `updateApplicationContext` ile "bugünkü grup" senkronu | 5 |
| `wakeConfirmed` uçtan uca akış — **köprü katmanı olmadığı için tek sprintte tamamlanabiliyor** (önceki revizyonda bu 2 ayrı sprint gerektiriyordu: Sprint 5 + Sprint 6) | 8 |

**Sprint 4 Toplam:** 26 SP

### Sprint 5 — Watch UX Cilalama + Offline Senaryolar
| Görev | SP |
|---|---|
| W2 Onay/Geri Al ekranı + 10 sn undo | 5 |
| Watch-local alarm iptali (offline-first) | 5 *(aynı `HandleWakeEvent` use case'i paylaşıldığı için önceki revizyona göre daha az efor)* |
| `transferUserInfo` fallback + kuyruklama testi | 5 |
| Watch tarafı XCTest paketleri | 5 |

**Sprint 5 Toplam:** 20 SP

### Sprint 6 — Takvim / İleri Tarih Planlama (F4)
| Görev | SP |
|---|---|
| S4 Ay görünümü takvim komponenti (SwiftUI, `Calendar`/`DateComponents` native destek) | 8 |
| S5 Gün Detay bottom sheet (`.sheet()` modifier) | 3 |
| `AlarmException` CRUD UI | 5 |
| 1 yıl sınırı validasyonu | 2 |

**Sprint 6 Toplam:** 18 SP

### Sprint 7 — Complication + v1.0 Sıkılaştırma
| Görev | SP |
|---|---|
| Watch complication (WidgetKit tabanlı, sonraki alarm saati) | 5 |
| Uçtan uca regresyon | 8 |
| Erişilebilirlik denetimi (VoiceOver, Dynamic Type) | 5 |

**Sprint 7 Toplam:** 18 SP

**Faz 2 Milestone:** v1.0 aday sürüm.

---

## Faz 3 — v1.1: App Store Hazırlığı (Sprint 8-9, 2 hafta — değişmedi)

| Görev | SP |
|---|---|
| Critical Alert entitlement başvurusu | 3 |
| App Store metadata, ekran görüntüleri, Privacy Nutrition Label | 5 |
| Lokalizasyon (TR + EN) — `String Catalog` (Xcode 15+) ile native destek | 3 |
| Performans/pil profili (Instruments) | 5 |
| Beta geri bildirim döngüsü | 8 |

**Faz 3 Toplam:** 24 SP

---

## Faz 4 — v2.0: Otomatik Uyanma Algılama (Sprint 10-14, 5 hafta — değişmedi, zaten native Swift işiydi)

Bu faz önceki revizyonla neredeyse aynı kalıyor çünkü HealthKit/CoreMotion entegrasyonu zaten native Swift gerektiriyordu (hibrit mimaride de bu kod native tarafta yazılacaktı).

| Sprint | Odak | SP |
|---|---|---|
| Sprint 10 | HealthKit izin akışı + `HKAnchoredObjectQuery` + bazal nabız hesaplama | 18 |
| Sprint 11 | CoreMotion + heuristik algoritma + cooldown | 21 |
| Sprint 12 | Kullanıcı onay akışı + fail-safe testleri | 16 |
| Sprint 13 | Saha testi ve kalibrasyon (yanlış pozitif <%15 hedefi) | 16 |
| Sprint 14 | Regresyon + App Store güncelleme gönderimi | 13 |

**Faz 4 Toplam:** 84 SP

---

## Özet Zaman Çizelgesi (Güncel)

```
Sprint:   0   1   2   3   4   5   6   7   8   9   10  11  12  13  14
Faz:      |Kur.|-- MVP (Faz 1) --|--- v1.0 (Faz 2) ---|v1.1|--- v2.0 (Faz 4) ---|
Hafta:    1   2   3   4   5   6   7   8   9   10  11  12  13  14  15

Toplam süre: ~15 hafta (~3.5 ay) — önceki hibrit mimariye göre ~2 hafta kazanç,
esas olarak Sprint 6 (platform channel köprüsü) tamamen ortadan kalktığı için.
```

**Not (değişmedi):** F5 (v2.0) opsiyonel görülürse proje **Sprint 9 sonunda (v1.1)** tamamlanmış sayılabilir, toplam süre ~9 haftaya (~2 ay) iner.
