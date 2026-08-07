# UX Tasarım ve Kullanıcı Akışları
## Akıllı Alarm Uygulaması

**İlişkili doküman:** `00-PRD-urun-gereksinim-dokumani.md`

---

## 1. Tasarım Prensipleri

1. **Fail-safe varsayılan:** Belirsizlik durumunda alarm çalmaya devam eder. Sessizce iptal asla olmaz — her otomatik aksiyon kullanıcı onayı gerektirir.
2. **Bir dokunuşla erişim:** En sık kullanılan aksiyonlar ("bugün kapat") ana ekrandan, ekstra menüye girmeden ulaşılabilir olmalı.
3. **Geri alınabilirlik:** Her yıkıcı aksiyon (grup iptali, istisna oluşturma) 5-10 saniyelik "geri al" (undo) penceresi sunar.
4. **Watch = hızlı karar, Telefon = detaylı yönetim.** Watch arayüzü tek elle, göze bakmadan da anlaşılır büyüklükte olmalı; detaylı planlama (takvim, çoklu grup düzenleme) telefonda yapılır.

---

## 2. Ekran Envanteri (iPhone — SwiftUI)

| # | Ekran | Amaç |
|---|---|---|
| S1 | Ana Ekran (Grup Listesi) | Tüm alarm gruplarının özeti, hızlı aksiyonlar |
| S2 | Grup Oluştur / Düzenle | Zaman aralığı, sıklık, gün, ses ayarları |
| S3 | Grup Detay | Grup içindeki tekil alarmların listesi, durumları (pending/fired/cancelled) |
| S4 | Takvim / Yıllık Planlama | Ay görünümü, istisna renk kodlaması, gün detay paneli |
| S5 | Gün Detay (Takvimden) | Seçili günün alarm durumu, grup ata/iptal et |
| S6 | Onay Bildirimi (Uyanma) | "Kalan 6 alarmı iptal edelim mi?" — actionable notification + in-app banner |
| S7 | Ayarlar | HealthKit izinleri, Watch bağlantı durumu, bildirim izinleri, tema |
| S8 | Onboarding (ilk açılış) | İzin talepleri (bildirim, HealthKit — opsiyonel), ilk grup oluşturma sihirbazı |

## 3. Ekran Envanteri (Apple Watch — SwiftUI)

| # | Ekran | Amaç |
|---|---|---|
| W1 | Ana Watch Ekranı | Aktif/yaklaşan alarm durumu, büyük "Uyandım" butonu |
| W2 | Onay/Geri Al Ekranı | "Alarmlar iptal edildi. Geri al?" — 10 sn. undo |
| W3 | Complication | Kadranda sonraki alarm saati + hızlı "Uyandım" erişimi |

---

## 4. Ana Kullanıcı Akışları

### Akış 1 — İlk Kurulum (Onboarding)
```
Uygulama açılışı
   → Karşılama ekranı ("Alarmlarını grupla, uyandığında bilek seni anlasın")
   → Bildirim izni iste (zorunlu, F1-F4 için gerekli)
   → HealthKit izni iste (opsiyonel, "Şimdi değil" seçeneği var — F5 v2 için)
   → Watch eşleştirme durumu kontrol (varsa otomatik algıla, yoksa "Watch'sız da kullanılabilir" mesajı)
   → İlk grup oluşturma sihirbazı (S2 akışına yönlendirme)
   → Ana ekran (S1)
```

### Akış 2 — Sabah Otomatik Senaryo (Ana Değer Önerisi)
```
06:00 — İlk alarm çalar (Watch + iPhone eş zamanlı, ikisi de yerel olarak zamanlanmış)
06:20 — Kullanıcı 4. alarmda gerçekten uyanır
        → Watch ekranında zaten görünen "Uyandım" butonuna basar (W1)
        → Watch: "Kalan 6 alarm iptal ediliyor..." + 10 sn undo (W2)
        → WatchConnectivity ile iPhone'a event iletilir
        → iPhone: pending notification'lar kaldırılır, S1 ekranında grup durumu
          "Bugün tamamlandı ✓" olarak güncellenir
        → (v2) Eğer Watch algısı otomatikse: iPhone'da actionable notification
          gösterilir, kullanıcı Watch'a bakmadan da onaylayabilir/reddedebilir
```

**Kritik UX kararı:** Watch bağlantısı yoksa/gecikmeliyse, "Uyandım" aksiyonu **önce Watch'ta local olarak** uygulanır (Watch kendi bildirimlerini durdurur), iPhone senkronizasyonu arka planda tamamlanır. Kullanıcı asla "Watch'a bastım ama telefon hâlâ çalıyor" deneyimi yaşamamalı — bu yüzden Watch'ın kendi local notification kopyası da olmalı (bkz. Mimari doküman, çakışan cihaz senaryosu).

### Akış 3 — Manuel "Bugün Kapat"
```
S1 (Ana Ekran) → Grup kartında sola kaydır (swipe)
   → "Bugün Kapat" butonu belirir
   → Dokunma → Onay yok (tek adımlı, düşük riskli aksiyon) ama
     ekranın altında Snackbar: "Sabah Grubu bugün için kapatıldı. [Geri Al]"
   → 8 saniye sonra Snackbar kaybolur, aksiyon kalıcılaşır
```

### Akış 4 — Manuel "Bu Hafta Pas Geç"
```
S1 → Grup üzerinde uzun bas → Aksiyon menüsü açılır
   → "Bu Hafta Pas Geç" seçilir
   → Önizleme dialog'u: "Pzt 8 - Cuma 12 arası, toplam 40 alarm etkilenecek. Onaylıyor musun?"
   → Onay → S1'de grup kartı "Bu hafta pasif" rozeti ile işaretlenir
```

### Akış 5 — İleri Tarih Planlama
```
S1 → Alt navigasyon → Takvim (S4)
   → Ay görünümünde günler renk kodlu (yeşil: normal aktif, gri: istisna var)
   → Bir güne dokun → Gün Detay paneli (S5) alttan açılır (bottom sheet)
      → O gün hangi gruplar aktif, hangileri pasif gösterilir
      → "Bu günü değiştir" → grup seç / iptal et / özel tek seferlik alarm ekle
   → Kaydet → Takvimde ilgili gün turuncu işaretlenir
```

### Akış 6 — Yanlış Pozitif Geri Alma (v2, otomatik algılama)
```
Watch, kullanıcı gerçekte uyanmamışken hareket+nabız artışını yanlış yorumlar
   → W1'de "Uyandığını algıladık" mesajı + [Evet] [Hayır, uyumaya devam] butonları
   → Kullanıcı "Hayır" derse → algılama modeli bu oturum için sessize alınır
     (aynı alarm penceresinde tekrar sormaz, ör. 15 dk cooldown)
   → Alarmlar normal akışına devam eder
```

---

## 5. Bildirim Tasarımı (Notification UX)

### Actionable Notification — Onay İsteği
```
Başlık: "Uyandığını fark ettik 👋"
Gövde: "Sabah Grubu'ndan kalan 6 alarm var. İptal edelim mi?"
Aksiyonlar: [Evet, İptal Et]  [Hayır, Devam Etsin]
Interruption Level: .timeSensitive (Critical Alert onayı gelirse yükseltilir)
```

### Alarm Bildirimi (Tekil)
```
Başlık: "⏰ Sabah Grubu"
Gövde: "06:25 — Uyanma vakti"
Ses: Uygulama CC0 ses paketi (katalog) veya sistem varsayılanı; kullanıcı seçimi + ses düzeyi (0–100)
Aksiyon: [Ertele 5dk] [Kapat]
```

---

## 6. Görsel Tasarım Yönü (Üst Seviye)

- **Ton:** Sakin, güven veren — sabah stresini artıran agresif kırmızı/turuncu alarm klişelerinden kaçınılır. Ana renk: yumuşak lacivert/gece mavisi + enerjik ama yumuşak bir vurgu rengi (ör. mercan/turuncu tonu sadece aktif alarm durumunda).
- **Tipografi:** Sistem fontu (SF Pro, SwiftUI `Font` API'siyle native hizalı), saat göstergeleri için `.monospacedDigit()` (rakamların hizalı görünmesi için).
- **Watch arayüzü:** Maksimum 2 ana eleman görünür olmalı (saat + tek buton), bilgi kirliliğinden kaçınılır — bilek ekranında karar verme süresi kritik.
- Detaylı komponent/spacing/renk token seti için geliştirme aşamasında `frontend-design` prensipleri uygulanacak (ör. tutarlı 8pt grid, erişilebilir kontrast oranları — WCAG AA minimum).

---

## 7. Erişilebilirlik Gereksinimleri

- Tüm swipe aksiyonları için VoiceOver ile erişilebilir alternatif (uzun basma menüsü) sağlanmalı.
- Dinamik tip (Dynamic Type) desteklenmeli — büyük yazı tipi ayarında sabah yarı uykulu kullanım senaryosu göz önünde.
- Watch'taki "Uyandım" butonu minimum 44x44pt dokunma alanına sahip olmalı, titreşimle (haptic) onaylanmalı.
- Renk kodlaması (takvimdeki yeşil/turuncu/gri) tek başına anlam taşımamalı, ikon/etiketle desteklenmeli (renk körlüğü).
