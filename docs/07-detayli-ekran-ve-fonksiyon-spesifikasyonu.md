# Detaylı Ekran ve Fonksiyon Spesifikasyonu
## Akıllı Alarm Uygulaması

**İlişkili dokümanlar:** `01-ux-tasarim-ve-akislar.md` (üst seviye akışlar), `02-teknik-mimari.md` (use case'ler), `03-veri-modeli-ve-arayuzler.md` (veri modeli)
**Amaç:** Bu doküman, S1-S8 (iPhone) ve W1-W3 (Watch) ekranlarının her birini; bileşen bileşen, her durumu (empty/loading/error/dolu) ve her fonksiyonun hangi use case'i hangi parametrelerle tetiklediğini içerecek şekilde, geliştiriciye doğrudan uygulanabilir netlikte tanımlar.

**Okuma rehberi:** Her ekran şu 7 başlıkla anlatılır: **Amaç · Giriş Noktaları · Bileşen Haritası · Durumlar · Fonksiyonlar · Veri Bağımlılıkları · Kenar Durumları / Çıkış Noktaları.**

---

# İPHONE EKRANLARI

## S1 — Ana Ekran (Alarm Listesi)

### Amaç
Kullanıcının tüm alarmlarını tek bakışta görmesi; gruplu olanlarda toplu “bugün kapat” / “bu hafta pas geç” aksiyonlarına erişmesi.

### Giriş Noktaları
- Uygulama açılışı (onboarding tamamlanmışsa varsayılan ekran)
- Tab bar "Alarmlar"

### Bileşen Haritası
```
TabView
├── Tab "Alarmlar" → NavigationStack
│   ├── Title: "Alarmlar"
│   ├── Trailing: "+" → S2 (yeni alarm)
│   └── List — her Alarm için satır (saat, günler, isteğe bağlı grup badge)
│       └── swipe: Bugün kapat (alarm veya bağlı grup)
└── Tab "Takvim" → S4
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Boş** | "Henüz alarm yok" + "Alarm oluştur" CTA |
| **Dolu** | Alarm listesi (oluşturma / saate göre) |

### Fonksiyonlar
| Eylem | Use Case |
|---|---|
| "+" | → S2 CreateAlarm |
| Satıra dokun | → S3 Alarm detay |
| Swipe Bugün kapat | `cancelToday(alarmId:)` veya grupluysa `cancelToday(groupId:)` |

---

## S2 — Alarm Oluştur / Düzenle

### Amaç
Tek bir alarmı saat, tekrar günleri, ses ve isteğe bağlı grup ile tanımlamak.

### Bileşen Haritası
```
Form
├── Ad (title)
├── Saat (DatePicker hourAndMinute)
├── Tekrar günleri (Pzt–Paz)
├── Grup (Picker: Grup yok | mevcut gruplar | + yeni grup adı)
├── Ses (katalog listesi + önizleme)
├── Ses düzeyi (Slider 0–100)
└── Kaydet → CreateAlarm (+ optional groupId; soundId + soundVolume)
```

---

## S3 — Alarm Detay

### Amaç
Seçili alarmın özeti ve planlanmış `AlarmInstance` satırları; ses adı + düzey yüzdesi özeti.

---

## S4 — Takvim

### Amaç
Ay görünümünde instance’ı olan günleri işaretlemek; güne dokununca o günün alarm listesini göstermek.

### Bileşen Haritası
```
NavigationStack
├── Ay ileri/geri
├── CalendarGrid — gün hücresi + nokta (o gün pending/aktif instance varsa)
└── Seçili gün → liste (saat + alarm adı + grup badge)
```

### Not
Eski S2/S3 grup-aralık metinleri alarm-first ile üstünlendi. S5+ istisna düzenleme sonraki iterasyonda.

---

## S5 — Gün Detay (Bottom Sheet) — v1.1+

### Amaç
Seçili gün için istisna / özel alarm (şimdilik S4 liste salt okunur iskelet yeterli).

---

## S6 — Onay Bildirimi (Uyanma)

### Amaç
Watch'tan gelen wake event sonrası (ya da v2'de otomatik algılamada) kullanıcıdan onay almak.

### Giriş Noktaları
- Sistem bildirimi (uygulama arka planda/kapalıyken) — `UNNotificationContent` actionable notification
- Uygulama ön plandayken — in-app banner (aynı içerik, native `UNUserNotificationCenterDelegate` ile ön planda da gösterilir)

### Bileşen Haritası
```
Actionable Notification
├── Başlık: "Uyandığını fark ettik 👋"
├── Gövde: "Sabah Grubu'ndan kalan N alarm var. İptal edelim mi?"
└── Aksiyonlar: [Evet, İptal Et] [Hayır, Devam Etsin]

In-App Banner (ön planda, üstten kayan)
├── Aynı içerik
└── Otomatik kaybolma: 15 saniye (yanıt verilmezse alarm normal çalmaya devam eder)
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **watch_manual kaynaklı** (F2, kullanıcı Watch'ta zaten "Uyandım"a basmış) | Bu bildirim aslında **bilgilendirme** amaçlı, aksiyonlar yerine tek "Tamam" butonu — çünkü Watch zaten kararı uyguladı |
| **watch_auto kaynaklı** (v2, F5) | Gerçek onay isteniyor, iki aksiyon butonu aktif |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "Evet, İptal Et" | `HandleWakeEvent(groupId:, confirmed: true)` | Kalan instance'lar cancelled |
| "Hayır, Devam Etsin" | `HandleWakeEvent(groupId:, confirmed: false)` + cooldown kaydı | Alarmlar devam eder, aynı grup için 15dk yeniden sorulmaz (v2 cooldown) |
| Yanıt yok, 15sn geçer | — | Hiçbir şey değişmez (fail-safe varsayılan, PRD F5 kabul kriteri) |

### Veri Bağımlılıkları
- `WakeEventLog` kaydı her durumda oluşturulur (confirmed: true/false)

### Kenar Durumları / Çıkış Noktaları
- Kullanıcı bildirime dokunup uygulamayı açarsa → doğrudan S3 (ilgili grubun detayı) açılır, karar orada da verilebilir.

---

## S7 — Ayarlar

### Amaç
İzinler, Watch bağlantı durumu, genel tercihlerin yönetimi.

### Giriş Noktaları
- TabBar "Ayarlar"

### Bileşen Haritası
```
Form
├── Section("Apple Watch")
│   ├── Bağlantı durumu satırı (Bağlı ✓ / Bağlı Değil / Eşleşmemiş)
│   └── "Watch'ı Yeniden Eşleştir" (sorun giderme linki)
├── Section("İzinler")
│   ├── Bildirim izni durumu + "Ayarlar'ı Aç" (Sistem Ayarları'na deep link)
│   └── HealthKit izni (v2) — toggle, açıklama metniyle
├── Section("Otomatik Uyanma Algılama") — sadece v2'de görünür
│   └── Toggle: F5 açık/kapalı (PRD F5 kabul kriteri: varsayılan durum, kalibrasyon sonucuna göre)
├── Section("Veri")
│   ├── "Uyanma Geçmişini Temizle" (WakeEventLog temizliği)
│   └── Otomatik temizlik süresi seçici (30/90/180 gün)
├── Section("Hakkında")
│   ├── Versiyon numarası
│   ├── Açık kaynak lisans bilgisi (→ LICENSE görüntüleme)
│   └── GitHub repo linki
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Bildirim izni reddedilmiş** | Kırmızı uyarı: "Bildirimler kapalı, alarmlar çalışmayacak" + "Ayarlar'ı Aç" CTA |
| **HealthKit izni reddedilmiş (v2)** | "Otomatik Uyanma Algılama" bölümü disabled, açıklama: "HealthKit izni gerekli" |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "Ayarlar'ı Aç" | `UIApplication.openSettingsURLString` | Sistem Ayarları'na yönlendirme |
| F5 toggle | `UpdateSettings(autoWakeDetectionEnabled: Bool)` | v2 algılama motoru açılır/kapanır |
| "Uyanma Geçmişini Temizle" | `ClearWakeEventLog()` | Onay dialog'u sonrası tüm `WakeEventLog` silinir |

### Veri Bağımlılıkları
- `WatchConnectivityService.connectionState`
- `UNUserNotificationCenter.notificationSettings()`
- `HKHealthStore.authorizationStatus(for:)` (v2)

### Kenar Durumları / Çıkış Noktaları
- Yok — bu ekran terminal bir ekran, tüm aksiyonlar yerinde tamamlanır.

---

## S8 — Onboarding (İlk Açılış)

### Amaç
İlk kurulumda gerekli izinleri almak ve kullanıcıyı ilk grup oluşturmaya yönlendirmek.

### Giriş Noktaları
- Uygulamanın ilk açılışı (`UserDefaults` / `AppStorage` flag: `hasCompletedOnboarding == false`)

### Bileşen Haritası
```
TabView (paging, sayfa göstergeli)
├── Sayfa 1 — Karşılama
│   └── İllüstrasyon + "Alarmlarını grupla, uyandığında bilek seni anlasın" + "Devam Et"
├── Sayfa 2 — Bildirim İzni
│   └── Açıklama + "İzin Ver" (sistem dialog'unu tetikler) / "Şimdi Değil" (devam eder ama uyarı gösterilir)
├── Sayfa 3 — HealthKit İzni (opsiyonel)
│   └── Açıklama + "İzin Ver" / "Şimdi Değil" (S7'den sonra da istenebilir)
├── Sayfa 4 — Watch Durumu
│   └── Otomatik algılanan durum: "Apple Watch'ın bağlı ✓" / "Watch'sız da tam kullanılabilir"
└── Sayfa 5 — İlk Grup Oluşturma Sihirbazı
    └── S2'nin basitleştirilmiş embedded versiyonu, "Bitir" → S1
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Bildirim izni reddedildi** | Sayfa 2'de kalıcı uyarı ikonu, ama "Devam Et" yine de aktif (zorlayıcı değil, ama S7'de tekrar hatırlatılır) |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "İzin Ver" (bildirim) | `UNUserNotificationCenter.requestAuthorization` | Sistem dialog'u, sonuç kaydedilir |
| "İzin Ver" (HealthKit) | `HKHealthStore.requestAuthorization` | Sistem dialog'u |
| Sihirbaz "Bitir" | `CreateAlarm` + `AppStorage.hasCompletedOnboarding = true` | S1'e geçiş |
| "Bu adımı atla" (sihirbaz) | `AppStorage.hasCompletedOnboarding = true` | S1'e boş listeyle geçiş (S1'deki boş durum devreye girer) |

### Veri Bağımlılıkları
- `@AppStorage("hasCompletedOnboarding")`

### Kenar Durumları / Çıkış Noktaları
- Onboarding tamamlanmadan uygulama kapatılırsa → bir sonraki açılışta kaldığı sayfadan değil, **Sayfa 1'den** yeniden başlar (izin durumları sistem tarafından zaten hatırlanır, tekrar sorulmaz).

---

# APPLE WATCH EKRANLARI

## W1 — Ana Watch Ekranı

### Amaç
Aktif/yaklaşan alarm durumunu göstermek ve "Uyandım" aksiyonuna anlık erişim sağlamak.

### Giriş Noktaları
- Watch app açılışı
- Complication dokunma (→ W1)
- Alarm çaldığında otomatik ön plana gelme

### Bileşen Haritası
```
NavigationStack (watchOS, tek sayfa ağırlıklı)
├── Üst: Sonraki/aktif grup adı (küçük, gri)
├── Orta: Büyük saat gösterimi (sonraki alarm saati) VEYA
│         "Şu an çalıyor: 06:25" (alarm aktifken, animasyonlu)
└── Alt: BÜYÜK "Uyandım" butonu (tam genişlik, yüksek kontrast)
         — sadece bugün aktif bir grup varsa görünür
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Bugün aktif grup yok** | "Bugün alarm yok" mesajı, buton gizli |
| **Grup aktif ama henüz ilk alarm çalmadı** | Saat + "İlk alarm: 06:00" — buton görünür ama ikincil stilde (henüz uyanma anlamlı değil, ama erken de basılabilir) |
| **Alarm çalıyor** | Kırmızı/turuncu vurgulu, titreşen saat gösterimi, buton birincil (dolu renk) stilde |
| **Tüm alarmlar zaten iptal/bitmiş** | "Bugün tamamlandı ✓" + buton gizli |
| **iPhone ile senkron kopuk** | Küçük üst ikon (bulut-çizgili), ama buton yine de çalışır (local-first, bkz. Mimari Bölüm 3) |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "Uyandım" butonu | `HandleWakeEvent(groupId:, source: .watchManual)` — **doğrudan Watch'ın local `AlarmAppCore` instance'ında çalışır** | 1) Watch local notification'ları hemen iptal 2) Haptic geri bildirim 3) W2'ye geçiş 4) Arka planda `WatchConnectivityService.send(.wakeConfirmed)` |
| Uzun basma (buton üzerinde) | — | Tooltip: "Bu grubun bugünkü kalan alarmlarını iptal eder" (ilk kullanımda otomatik gösterilir, sonra gizlenebilir) |

### Veri Bağımlılıkları
- `TodayContext` (iPhone'dan `updateApplicationContext` ile senkronize, Watch local cache)

### Kenar Durumları / Çıkış Noktaları
- Birden fazla grup aynı anda "bugün aktif" ise (nadir ama mümkün, ör. sabah + öğle grubu çakışırsa), W1'de bir segment/liste görünümüne geçilir — her grup için ayrı "Uyandım" satırı. Bu durum PRD'de netleştirilmemiş bir edge case, ürün kararı gerektirir (bkz. Açık Sorular).
- Çıkış: buton → W2

---

## W2 — Onay / Geri Al Ekranı

### Amaç
"Uyandım" aksiyonunun geri alınabilir olduğunu göstermek.

### Giriş Noktaları
- W1 "Uyandım" butonu

### Bileşen Haritası
```
├── Büyük onay ikonu (checkmark, animasyonlu)
├── Metin: "Kalan 6 alarm iptal edildi"
├── Geri sayım göstergesi (10 → 0, dairesel progress)
└── "Geri Al" butonu (10sn boyunca görünür, sonra otomatik kaybolur → W1'e döner)
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **10sn içinde** | "Geri Al" aktif, geri sayım animasyonu |
| **10sn doldu** | Otomatik W1'e döner, aksiyon kalıcılaşır |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "Geri Al" | `UndoWakeEvent(groupId:)` | İptal edilen instance'lar `pending`'e geri döner, notification'lar yeniden zamanlanır, `WatchConnectivityService.send()` ile iPhone'a da bildirilir |
| Hiçbir şey yapmama (10sn) | — | W1'e döner, "Bugün tamamlandı ✓" durumu |

### Veri Bağımlılıkları
- Yerel geri sayım `Timer`, `HandleWakeEvent` çağrısının döndürdüğü "geri alınabilir instance ID listesi"

### Kenar Durumları / Çıkış Noktaları
- Kullanıcı 10sn dolmadan Watch app'ten çıkarsa (ekranı kapatırsa) → aksiyon otomatik kalıcılaşır (fail-safe: "geri alma" bir varsayılan değil, açık bir kullanıcı eylemi olmalı).

---

## W3 — Complication

### Amaç
Kadrandan tek bakışta sonraki alarm saatini görmek, dokunarak W1'e hızlı erişim.

### Giriş Noktaları
- Watch kadranı (kullanıcı complication'ı kadranına eklemişse)

### Bileşen Haritası
```
WidgetKit Complication (watchOS)
├── .accessoryCircular — saat + küçük alarm ikonu
├── .accessoryRectangular — "Sabah Grubu · 06:25" + durum rengi
└── .accessoryInline — "⏰ 06:25"
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Aktif alarm var** | Saat + ikon, nötr renk |
| **Alarm çalıyor** | Vurgulu renk (kırmızı/turuncu) |
| **Bugün alarm yok** | Boş/silik ikon, "—" |

### Fonksiyonlar
| Eylem | Sonuç |
|---|---|
| Dokunma | Watch app'i açar, doğrudan W1'e yönlendirir |

### Veri Bağımlılıkları
- `TodayContext` — `WidgetKit` timeline provider, `updateApplicationContext` geldiğinde `WidgetCenter.shared.reloadTimelines()` ile yenilenir

### Kenar Durumları / Çıkış Noktaları
- Timeline yenileme sistem tarafından kısıtlı sıklıkta yapılabilir (WidgetKit bütçesi) — bu nedenle complication verisi birkaç dakika gecikmeli olabilir, kullanıcıya bu garanti edilmemeli.

---

## Ek: Fonksiyon → Use Case Çapraz Referans Tablosu

Bu tablo, hangi ekran fonksiyonlarının hangi ortak `AlarmAppCore` use case'ini tetiklediğini tek bakışta gösterir (bkz. `02-teknik-mimari.md` Bölüm 2, `03-veri-modeli-ve-arayuzler.md` Bölüm 3).

| Use Case | Kullanıldığı Ekranlar |
|---|---|
| `CreateAlarm` | S2, S8 |
| `UpdateAlarmGroup` | S2 |
| `DeleteGroup` | S1 |
| `CancelGroupForToday` | S1, S3 |
| `SkipWeek` | S1, S3 |
| `ScheduleException` | S5 |
| `RemoveException` | S3 |
| `HandleWakeEvent` | S6, W1 |
| `UndoWakeEvent` | W2 |
| `UpdateSettings` | S7 |

---

## Ek: Açık Sorular (Bu Dokümana Özgü, PRD'ye Eklenmesi Önerilir)

1. **W1 çoklu grup çakışması:** Aynı anda birden fazla grup "bugün aktif" ise Watch arayüzü nasıl davranmalı? (Bkz. W1 Kenar Durumları)
2. **S3 "hangi cihazdan iptal edildi" bilgisi:** Bu düzeyde şeffaflık kullanıcı için değerli mi, yoksa gereksiz bilgi kirliliği mi? Kullanıcı testiyle doğrulanmalı.
3. **S8 onboarding'de HealthKit izninin zamanlaması:** İlk açılışta mı (F5 henüz aktif değilken) yoksa sadece kullanıcı F5'i S7'den açmak istediğinde mi istenmeli? (İzin yorgunluğunu azaltmak için ikinci seçenek önerilir.)
