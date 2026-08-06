# Detaylı Ekran ve Fonksiyon Spesifikasyonu
## Akıllı Alarm Uygulaması

**İlişkili dokümanlar:** `01-ux-tasarim-ve-akislar.md` (üst seviye akışlar), `02-teknik-mimari.md` (use case'ler), `03-veri-modeli-ve-arayuzler.md` (veri modeli)
**Amaç:** Bu doküman, S1-S8 (iPhone) ve W1-W3 (Watch) ekranlarının her birini; bileşen bileşen, her durumu (empty/loading/error/dolu) ve her fonksiyonun hangi use case'i hangi parametrelerle tetiklediğini içerecek şekilde, geliştiriciye doğrudan uygulanabilir netlikte tanımlar.

**Okuma rehberi:** Her ekran şu 7 başlıkla anlatılır: **Amaç · Giriş Noktaları · Bileşen Haritası · Durumlar · Fonksiyonlar · Veri Bağımlılıkları · Kenar Durumları / Çıkış Noktaları.**

---

# İPHONE EKRANLARI

## S1 — Ana Ekran (Grup Listesi)

### Amaç
Kullanıcının tüm alarm gruplarını tek bakışta görmesi ve en sık kullanılan aksiyonlara (bugün kapat, bu hafta pas geç) tek dokunuşla erişmesi.

### Giriş Noktaları
- Uygulama açılışı (onboarding tamamlanmışsa varsayılan ekran)
- Herhangi bir alt ekrandan "geri" / tab bar'dan "Ana Sayfa"

### Bileşen Haritası
```
NavigationStack
├── NavigationBar
│   ├── Title: "Alarmlarım"
│   └── Trailing: "+" butonu (→ S2, yeni grup)
├── Watch Bağlantı Rozeti (üst banner, koşullu — bkz. Durumlar)
├── ScrollView
│   └── LazyVStack — her AlarmGroup için bir GroupCard
│       ├── GroupCard
│       │   ├── Başlık (grup adı)
│       │   ├── Alt başlık ("06:00–07:00 · Pzt-Cum · 13 alarm")
│       │   ├── Durum rozeti ("Aktif" / "Bugün tamamlandı ✓" / "Bu hafta pasif" / "Devre dışı")
│       │   ├── Sonraki alarm zamanı (varsa)
│       │   └── .swipeActions(): [Bugün Kapat] [Bu Hafta Pas Geç] (sola kaydır)
│       └── .contextMenu() (uzun bas): [Düzenle] [Bugün Kapat] [Bu Hafta Pas Geç]
│                                       [Kalıcı Durdur] [Sil]
└── TabBar: [Ana Sayfa] [Takvim] [Ayarlar]
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Boş (hiç grup yok)** | Ortada illüstrasyon + "Henüz alarm grubun yok" + "İlk Grubunu Oluştur" CTA butonu (→ S2) |
| **Dolu** | Yukarıdaki GroupCard listesi, oluşturulma tarihine göre değil, **sonraki çalma saatine göre** sıralı |
| **Watch bağlı değil** | Üstte kalıcı olmayan (dismissible) banner: "Apple Watch bağlı değil — otomatik uyanma algılama kullanılamıyor, manuel kontroller çalışmaya devam ediyor" |
| **Watch senkron bekliyor** | GroupCard'da küçük saat ikonu rozeti: "Watch senkron bekliyor" (Bluetooth kopukluğu durumunda) |
| **Yükleniyor (ilk açılış, DB henüz okunmadı)** | `ProgressView`, skeleton kart placeholder'ları |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| "+" butonuna dokun | — (navigasyon) | S2'ye boş formla geçiş |
| Karta dokun | — (navigasyon) | S3 (Grup Detay) |
| Swipe → "Bugün Kapat" | `CancelGroupForToday(groupId:)` | Bugünkü `pending` instance'lar `cancelled`, pending notification'lar kaldırılır, kart rozeti "Bugün tamamlandı ✓" olur |
| Swipe → "Bu Hafta Pas Geç" | Önce onay dialog'u açılır (bkz. altta), onay sonrası `SkipWeek(groupId:, weekStart:)` | Haftalık `AlarmException` kaydı oluşur |
| Context menu → "Kalıcı Durdur" | `UpdateGroup(groupId:, isActive: false)` | Grup pasif hale gelir, gelecekteki tüm instance'lar iptal edilir, ama grup silinmez (geri açılabilir) |
| Context menu → "Sil" | Onay dialog'u → `DeleteGroup(groupId:)` | Grup ve tüm ilişkili instance/exception kayıtları cascade silinir (SwiftData `deleteRule: .cascade`) |
| "Bu Hafta Pas Geç" onay dialog'u | — | "Pzt 8 - Cum 12 arası, toplam 40 alarm etkilenecek. Onaylıyor musun?" [Vazgeç] [Onayla] |

### Veri Bağımlılıkları
- `@Query(sort: \AlarmGroup.nextFireDate)` — SwiftData'dan canlı, reaktif liste
- Watch bağlantı durumu: `WatchConnectivityService.connectionState` (`@Observable` published property)

### Kenar Durumları / Çıkış Noktaları
- Aynı gün içinde bir grup için hem "Bugün Kapat" hem sonradan yeni bir alarm eklenirse (grup düzenlenirse): "Bugün kapat" durumu o günün **mevcut** instance'larını etkiler, yeni eklenen instance'lar etkilenmez — kullanıcıya bunu netleştiren bir uyarı gösterilir.
- Çıkış noktaları: S2 (yeni/düzenle), S3 (detay), S4 (takvim, tab bar), S7 (ayarlar, tab bar)

---

## S2 — Grup Oluştur / Düzenle

### Amaç
Kullanıcının bir zaman aralığı, sıklık, tekrar günleri ve ses seçerek alarm grubu tanımlaması.

### Giriş Noktaları
- S1 "+" butonu (yeni grup, boş form)
- S1 context menu "Düzenle" (mevcut grup, dolu form)
- S3 "Düzenle" butonu

### Bileşen Haritası
```
NavigationStack (modal, .sheet olarak açılır)
├── NavigationBar
│   ├── Leading: "Vazgeç"
│   ├── Title: "Yeni Grup" / "Grubu Düzenle"
│   └── Trailing: "Kaydet" (validasyon geçmeden disabled)
├── Form
│   ├── Section("Ad")
│   │   └── TextField (placeholder: "ör. Sabah Grubu")
│   ├── Section("Zaman Aralığı")
│   │   ├── DatePicker (.hourAndMinute) — Başlangıç
│   │   ├── DatePicker (.hourAndMinute) — Bitiş
│   │   └── Stepper — Aralık (dakika), 1-60 arası
│   │   └── Canlı önizleme metni: "13 alarm oluşturulacak (06:00, 06:05, ..., 07:00)"
│   ├── Section("Tekrar Günleri")
│   │   └── 7 günlük toggle chip'leri (Pzt-Paz), çoklu seçim
│   ├── Section("Ses")
│   │   └── NavigationLink → Ses seçim listesi (önizleme çalma özellikli)
│   └── Section("Uyarılar") — koşullu, sadece çakışma varsa görünür
│       └── "Bu grup, 'Öğle Molası' grubuyla 06:30'da çakışıyor" (kırmızı metin)
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Yeni grup (boş form)** | Tüm alanlar varsayılan (06:00-07:00, 5dk, hiç gün seçili değil) |
| **Düzenleme (dolu form)** | Mevcut `AlarmGroup` değerleriyle önyüklenmiş |
| **Validasyon hatası** | "Kaydet" disabled + ilgili alan altında kırmızı hata metni (ör. "Bitiş saati başlangıçtan önce olamaz") |
| **Çakışma uyarısı** | Kaydetmeyi engellemez, sadece bilgilendirir (sarı/turuncu uyarı kutusu) |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| Alan değişikliği (her keystroke/picker) | Local form state güncellenir, **canlı önizleme** yeniden hesaplanır (debounce 200ms) | "N alarm oluşturulacak" metni güncellenir |
| "Kaydet" (yeni) | `CreateAlarmGroup(params)` | Grup + tüm `AlarmInstance`'lar oluşturulur, `UNNotificationRequest`ler zamanlanır, S1'e dönülür |
| "Kaydet" (düzenleme) | `UpdateAlarmGroup(groupId:, params)` | Mevcut pending instance'lar silinip yeniden oluşturulur; **zaten `fired`/`cancelled` olan geçmiş instance'lara dokunulmaz |
| "Vazgeç" | — | Kaydedilmeden kapatılır, değişiklik varsa onay dialog'u ("Değişiklikleri kaydetmeden çık?") |

### Veri Bağımlılıkları
- `AlarmGroupFormViewModel` (`@Observable`) — form state + canlı validasyon + önizleme hesaplama
- Çakışma kontrolü için diğer aktif grupların zaman aralıklarını okur (`AlarmRepository.activeGroups()`)

### Kenar Durumları / Çıkış Noktaları
- Aralık, toplam süreyi aşarsa (ör. 65 dakikalık aralık, 60 dakikalık pencere) → sadece 1 alarm oluşur, kullanıcı bilgilendirilir.
- Hiç gün seçilmezse → "Kaydet" disabled, "En az bir gün seçmelisin" uyarısı.
- Çıkış: Kaydet → S1; Vazgeç → önceki ekran (S1 veya S3).

---

## S3 — Grup Detay

### Amaç
Bir grubun içindeki tüm tekil alarmları ve durumlarını (pending/fired/cancelled) şeffaf şekilde göstermek.

### Giriş Noktaları
- S1 kart dokunma

### Bileşen Haritası
```
NavigationStack
├── NavigationBar: Title (grup adı), Trailing: "Düzenle" (→ S2)
├── Header — grup özeti (saat aralığı, gün, ses)
├── Segmented Control: [Bugün] [Bu Hafta] [Tüm Zamanlar]
├── List — AlarmInstance satırları
│   └── Her satır: saat + durum ikonu (● pending, ✓ fired, ✕ cancelled) + iptal nedeni (varsa, küçük gri metin)
└── Alt aksiyon barı: [Bugün Kapat] [Bu Hafta Pas Geç] [Kalıcı Durdur]
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **"Bugün" sekmesi, grup bugün aktif değil (istisna var)** | Liste yerine bilgi kutusu: "Bugün bu grup için istisna tanımlı: [nedeni]" + "İstisnayı Kaldır" butonu |
| **"Tüm Zamanlar", çok uzun liste** | Sayfalama/lazy loading (SwiftData `@Query` + `fetchLimit`) |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| Segment değişimi | — (yerel filtre) | Liste yeniden filtrelenir |
| Alt bar "Bugün Kapat" | `CancelGroupForToday` | S1'deki aynı davranış |
| "İstisnayı Kaldır" | `RemoveException(exceptionId:)` | İlgili `AlarmException` silinir, o günün alarmları normale döner |
| Bir instance satırına dokun | — | Detay bottom sheet: saat, durum, iptal nedeni, (varsa) hangi cihazdan iptal edildiği ("Watch'tan iptal edildi, 06:22") |

### Veri Bağımlılıkları
- `@Query` — seçili gruba ait `AlarmInstance`'lar, segment'e göre tarih filtreli

### Kenar Durumları / Çıkış Noktaları
- Grup silinmişse (başka bir ekrandan) ve kullanıcı hâlâ bu ekrandaysa → otomatik S1'e yönlendirme + toast "Bu grup silindi".

---

## S4 — Takvim / Yıllık Planlama

### Amaç
Yıl içindeki herhangi bir güne gidip o gün için grup atama/iptal etme.

### Giriş Noktaları
- TabBar "Takvim"

### Bileşen Haritası
```
NavigationStack
├── NavigationBar: Title "Takvim", ay ileri/geri okları
├── Ay Görünümü (CalendarGrid, native `Calendar`/`DateComponents` tabanlı custom view)
│   └── Her gün hücresi: rakam + renk noktası
│       (yeşil: normal aktif · turuncu: istisna var · gri: tüm gruplar pasif · nokta yok: alarm yok)
├── Alt Legend: renk açıklamaları (erişilebilirlik: renk + ikon birlikte, bkz. UX dokümanı Bölüm 7)
└── Gün seçilince → S5 bottom sheet olarak açılır
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Geçmiş ay** | Günler salt-okunur (dokunulabilir ama S5'te "Geçmiş tarih düzenlenemez" mesajı) |
| **Bugünden 1 yıl sonrası** | Ay ileri oku disabled, "İstisnalar en fazla 1 yıl ileriye tanımlanabilir" tooltip |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| Gün hücresine dokun | — (navigasyon) | S5 bottom sheet açılır, o güne ait veri yüklenir |
| Ay ileri/geri ok | — | `CalendarGrid` yeniden render, `@Query` tarih aralığı güncellenir |

### Veri Bağımlılıkları
- Görünen ay aralığındaki tüm `AlarmException` kayıtları + hangi günlerde hangi gruplar aktif (hesaplanmış, cache'lenmiş `MonthSummary`)

### Kenar Durumları / Çıkış Noktaları
- Performans: 1 yıllık görünümde her gün için canlı hesaplama yapmak yerine, ay değiştikçe lazy hesaplanan `MonthSummary` cache'i kullanılır (bkz. Test Planı, performans testi < 300ms hedefi).

---

## S5 — Gün Detay (Bottom Sheet)

### Amaç
Seçili bir günün alarm durumunu gösterip değiştirme imkânı sunmak.

### Giriş Noktaları
- S4 gün hücresine dokunma

### Bileşen Haritası
```
.sheet (medium/large detent)
├── Header: Tarih ("6 Ağustos 2026, Perşembe")
├── "Bu gün aktif gruplar" listesi
│   └── Her grup: ad, saat aralığı, toggle (aktif/pasif bu gün için)
├── "Özel tek seferlik alarm ekle" butonu (→ mini form, aynı sheet içinde genişler)
└── Alt bar: [Vazgeç] [Kaydet]
```

### Durumlar
| Durum | Görünüm |
|---|---|
| **Hiç grup yok bu gün için normalde** | "Bu gün için tanımlı alarm grubu yok" + "Özel alarm ekle" CTA |
| **Geçmiş tarih** | Tüm kontroller disabled, "Geçmiş tarihler düzenlenemez" mesajı |

### Fonksiyonlar
| Eylem | Tetiklenen Use Case | Sonuç |
|---|---|---|
| Grup toggle kapatma | Yerel state, henüz kaydedilmez | Toggle görsel olarak kapanır |
| "Kaydet" | `ScheduleException(type: .singleDay, groupId:, action: .skip)` (kapatılan her grup için) | İlgili `AlarmException` kayıtları oluşur, S4'e dönülür, gün turuncu işaretlenir |
| "Özel alarm ekle" | Mini form açılır → "Kaydet" | `ScheduleException(type: .singleDay, action: .replace, replacementGroupId: <yeni tek seferlik grup>)` |

### Veri Bağımlılıkları
- Seçili tarih için `AlarmRepository.dayDetail(date:)` — o gün aktif olması gereken gruplar + mevcut istisnalar

### Kenar Durumları / Çıkış Noktaları
- Aynı gün için hem "grup kapat" hem "özel alarm ekle" yapılırsa, ikisi de ayrı `AlarmException` kayıtları olarak saklanır — çakışma yoksa sorun değil, çakışma varsa S2'deki gibi uyarı gösterilir.

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
| Sihirbaz "Bitir" | `CreateAlarmGroup` + `AppStorage.hasCompletedOnboarding = true` | S1'e geçiş |
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
| `CreateAlarmGroup` | S2, S8 |
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
