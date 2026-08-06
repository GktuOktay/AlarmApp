# Açık Kaynak Yönetişim (Governance) Dokümanı (Rev. 2 — Tamamen Native Swift)
## Akıllı Alarm Uygulaması

**Değişiklik notu:** Repo yapısı `mobile/` (Flutter) + `watch/` (Xcode) ikili yapısından, **tek Xcode workspace** içinde çoklu target/paket yapısına geçti.

---

## 1. Lisans Seçimi (değişmedi)

**Öneri: MIT Lisansı** (alternatif: Apache 2.0, patent koruması isteniyorsa).
Gerekçe (Rev.1'den değişmedi): App Store dağıtımıyla GPLv3'ün potansiyel sürtüşmesi, izin verici lisansın topluluk büyümesini teşvik etmesi.

---

## 2. Repo Yapısı (Güncel — Tek Xcode Workspace)

```
AlarmApp/
├── AlarmApp.xcworkspace
├── AlarmAppCore/                  # Swift Package — paylaşımlı domain/data/connectivity
│   ├── Sources/
│   │   ├── Domain/                # UseCase'ler, Entity'ler
│   │   ├── Data/                  # SwiftData modelleri, Repository implementasyonları
│   │   └── Connectivity/          # WatchConnectivityService
│   ├── Tests/
│   └── Package.swift
├── AlarmApp-iOS/                  # iOS app target
│   ├── Views/                     # S1-S8 SwiftUI ekranları
│   ├── ViewModels/
│   └── AlarmApp-iOSApp.swift
├── AlarmApp-Watch/                # watchOS app target
│   ├── Views/                     # W1-W3 SwiftUI ekranları
│   ├── ViewModels/
│   ├── WakeDetectionEngine/       # v2: HealthKit + CoreMotion
│   └── AlarmApp-WatchApp.swift
├── docs/                          # Bu doküman seti (00-06)
├── LICENSE
└── README.md
```

**Önceki yapıya göre fark:** `mobile/ios/WatchConnector/` gibi köprü-özel klasörler tamamen kalktı; `AlarmAppCore/Sources/Connectivity/` artık hem iOS hem Watch tarafından doğrudan kullanılan tek bir gerçek implementasyon.

---

## 3. Branch Stratejisi (değişmedi)

```
main            → her zaman yayınlanabilir durum
develop         → aktif geliştirme entegrasyon dalı
feature/*       → kısa ömürlü görev dalları
release/x.y.z   → sürüm hazırlığı
hotfix/*        → yayındaki kritik hata
```

Commit formatı: Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`).

---

## 4. Katkı Süreci (Güncel)

1. Büyük PR'lardan önce issue/tartışma (değişmedi).
2. **Yeni kural (Swift-only mimariye özgü):** `AlarmAppCore` paketine yapılan değişiklikler hem iOS hem watchOS target'ını etkilediği için, PR açıklamasında **her iki platformda da derlendiği/test edildiği** belirtilmeli (`swift build`, `swift test` çıktısı CI'da zaten zorunlu ama PR şablonunda da hatırlatma olmalı).
3. CI'da lint (SwiftLint) + `swift test` (paket seviyesi) + `xcodebuild test` (UI/entegrasyon) geçmeden merge edilmemeli.
4. WatchConnectivity/HealthKit içeren değişiklikler için gerçek cihazda test edildiğine dair not zorunlu (simülatör sınırlamaları, bkz. Test Planı).

---

## 5. Sürümleme (SemVer, değişmedi)

`MAJOR.MINOR.PATCH` — geliştirme başlangıcı: `0.0.0` (`VERSION` + `CHANGELOG.md`); Sprint 0 iskeleti sonrası aday: `0.0.1`; MVP: `0.1.0`; v1.0: `1.0.0`; v2.0: `2.0.0`.

---

## 6. Yayın Süreci (değişmedi, araç ismi güncel)

```
1. release/x.y.z dalı develop'tan açılır
2. Feature freeze, sadece kritik bugfix
3. Test QA planındaki regresyon kontrol listesi çalıştırılır
4. Fastlane ile TestFlight'a beta yüklenir (xcodebuild + fastlane pipeline,
   artık Flutter build adımı yok — CI süresi kısalır)
5. Onay sonrası main'e merge, git tag
6. App Store Connect'e gönderim, CHANGELOG.md güncellenir
7. GitHub Release notu yayınlanır
```

---

## 7. Topluluk Dosyaları (değişmedi)

| Dosya | Amaç |
|---|---|
| `README.md` | Proje tanıtımı, kurulum (artık tek adım: `AlarmApp.xcworkspace`'i aç), mimari özeti |
| `CONTRIBUTING.md` | Katkı süreci |
| `CODE_OF_CONDUCT.md` | Topluluk davranış kuralları |
| `SECURITY.md` | Güvenlik açığı bildirim süreci |
| `CHANGELOG.md` | Sürüm geçmişi |
| `docs/` | Bu doküman seti |

**Kurulum kolaylığı notu:** Flutter'ın kaldırılmasıyla katkıcılar için giriş engeli düşüyor — artık sadece Xcode + Apple Developer hesabı yeterli, ayrıca Flutter SDK/toolchain kurulumu gerekmiyor. Bu, açık kaynak katkı sürecini kolaylaştıran somut bir yan fayda.

---

## 8. Gizlilik ve Güvenlik Bildirimi (değişmedi)

- HealthKit verisi ağ üzerinden hiçbir zaman gönderilmez.
- Güvenlik açığı bildirimi `security@` adresine özel yapılır, embargo süreci uygulanır.
- Bağımlılık taraması: Swift Package Manager bağımlılıkları için `swift package show-dependencies` + Dependabot (SPM desteği) CI'a entegre edilir.

---

## 9. Topluluk Büyüme Planı (değişmedi)

- v1.1 sonrası "good first issue" etiketleme.
- Android/Wear OS desteği (PRD NG1) hâlâ ayrı bir companion proje olarak ele alınabilir — ancak artık bu projede paylaşılan Swift kodu doğrudan taşınamaz (Swift, Android'de native değil); bu senaryoda `AlarmAppCore`'daki **iş mantığı dokümantasyonu** (bu doküman seti) bir referans şartname olarak kullanılabilir, kod olarak değil.
