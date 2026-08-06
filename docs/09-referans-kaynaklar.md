# Referans Kaynaklar

Bu dosya **link kataloğudur**. Üçüncü taraf uygulamaları klonlama / submodule ekleme. Pattern’leri oku, AlarmApp dokümanlarına (`docs/00`–`07`) göre yeniden uygula; lisans uyumsuz kodu körü körüne kopyalama.

---

## Kod / mimari ilham

| Kaynak | URL | Ne zaman bak | AlarmApp eşlemesi |
|---|---|---|---|
| awesome-swiftui | https://github.com/onmyway133/awesome-swiftui | SwiftUI örnek uygulama ararken | Genel keşif listesi |
| Clendar | https://github.com/vinhnx/Clendar | Takvim UI / ay görünümü | **S4** yıllık/aylık planlama |
| Ice Cubes | https://github.com/Dimillian/IceCubesApp | Modüler SwiftUI, prodüksiyon organizasyonu | Paket/target ayrımı, View/ViewModel düzeni (Ice Cubes’un fediverse domain’ini kopyalama) |
| example-ios-apps | https://github.com/jogendra/example-ios-apps | Küçük odaklı örneklere bakarken | Genel |
| Countio | example-ios-apps listesindeki SwiftUI Watch örneği | Watch companion sade UI | **W1–W3** basitlik referansı |

> Not: Clendar / Ice Cubes / Countio URL’lerini kullanmadan önce GitHub’da güncel path’i doğrula; repo taşınmış olabilir.

---

## Apple resmi

| Kaynak | URL | Ne zaman bak | AlarmApp eşlemesi |
|---|---|---|---|
| HIG — Notifications | https://developer.apple.com/design/human-interface-guidelines/notifications | Bildirim zamanlama, actionable, Time Sensitive | Alarm tetikleme, S6, Critical Alert konumlandırması |
| HIG — Complications | https://developer.apple.com/design/human-interface-guidelines/complications | Kadran komplikasyonu | **W3** |
| SF Symbols (Mac app) | https://developer.apple.com/sf-symbols/ | İkon seçimi | Tüm ekranlar; tutarlı sembol seti |

---

## Görsel ilham (kod değil)

| Kaynak | URL | Ne zaman bak | AlarmApp eşlemesi |
|---|---|---|---|
| Mobbin | https://mobbin.com | Onboarding / alarm / takvim ekran görüntüsü tarama | **S8** onboarding, bildirim ve takvim akışları için görsel referans |

---

## Bilinçli olarak hariç

- Web odaklı “apple-design” (CSS / Framer Motion) skill’leri — bu native Swift projesine karıştırılmaz.
- Referans uygulamaların tam kopyası veya `vendor/` altına gömülmesi.
