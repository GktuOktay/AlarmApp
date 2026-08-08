# Kullanım Kılavuzu

AlarmApp'i günlük hayatta nasıl kullanacağını anlatan kısa bir rehber. Geliştirici/mimari dokümanlar için [`docs/`](docs/) klasörüne bakabilirsin.

## İlk açılış

Uygulamayı ilk açtığında 3 sayfalık kısa bir tanıtım (onboarding) karşına çıkar:

1. **Alarmlarını grupla** — Birden fazla alarmı bir grupta toplayabilirsin.
2. **Tek dokunuşla iptal et** — Gruptaki bir alarmı kapattığında, o günkü kalan alarmlar otomatik iptal edilir.
3. **Tatil günlerini önceden planla** — Takvim'den ileri tarihli günler için alarmları atlayabilirsin.

Bu ekranı "Atla" ile geçebilir, istediğin zaman tekrar görmek istersen uygulamayı silip yeniden kurman gerekir (yerel bir bayrakla bir kere gösterilir).

## Alarm oluşturma

1. **Alarmlar** sekmesinde sağ üstteki **+** butonuna dokun.
2. Saat ve isim gir.
3. Aşağıdaki satırlara dokunarak ayrıntıları düzenle — her biri kendi ekranına açılır (Apple Saat uygulamasındaki gibi):
   - **Tekrar** — hangi günler çalınsın
   - **Bitiş tarihi** — alarmın ne zamana kadar geçerli olacağı
   - **Erteleme** — erteleme süresi
   - **Uyanma programı** — otomatik uyanma algılamasıyla ilişkilendirme
   - **Grup** — bu alarmı bir gruba ekle
   - **Ses** — alarm sesi ve önizleme
4. Aynı gün/saat aralığında çakışan bir alarm varsa üstte uyarı belirir (kaydetmeden önce görürsün).

## Alarm grupları — uygulamanın kalbi

Gruplar isteğe bağlıdır ama asıl fark yaratan özellik burada:

- **Alarm Grupları** sekmesinden yeni bir grup oluştur (ör. "İş Günü Sabahı").
- Bir gruba istediğin kadar alarm ekle — mesela 06:00, 06:10, 06:20, 06:30 gibi art arda alarmlar.
- Sabah alarmlardan biri çaldığında ekranda üç seçenek görürsün:
  - **Kapat** — sadece o alarmı durdur
  - **Ertele** — birkaç dakika sonra tekrar çalsın
  - **Daha fazla** → **Grup — bugün** — o gruptaki **bugüne ait tüm kalan alarmları** tek dokunuşla iptal et

Bu sayede "art arda kurduğun alarmlardan biri çaldığında hepsini tek tek kapatma" derdi ortadan kalkar.

## Takvim ve tatil günleri

**Takvim** sekmesinde:

- Bir güne dokunarak o günün alarm/grup durumunu görürsün.
- Sağa/sola kaydırarak ay değiştirebilirsin.
- Bir alarmı veya grubu ileri tarihli bir gün için **atla (bypass)** olarak işaretleyebilirsin — böylece o gün için hiç alarm çalmaz, her sabah elle kapatmana gerek kalmaz (örn. tatile çıkarken).
- **Ayarlar → Takvimden atlama önerileri**'ni açarsan, uygulama sistem takvimindeki (izin/tatil gibi) günleri tespit edip sana atlama önerisi sunar. Bu özellik **opt-in**'dir ve veriler cihazdan dışarı çıkmaz.

## Apple Watch

- Watch uygulaması telefonla bağımsız çalışabilir (`WKRunsIndependentlyOfCompanionApp`).
- Alarm çaldığında bilekten **Kapat / Ertele / Daha fazla** aynı şekilde kullanılabilir.
- HealthKit izni verilirse ve **Otomatik uyanma sorusu** açıksa, sensörler uyanmış olabileceğini düşünürse Watch sana "Uyandın mı?" diye sorar; onaylamadan alarm kapanmaz.

## Ayarlar

- **Dil / Görünüm** — sistem varsayılanını kullan ya da elle seç.
- **Otomatik uyanma sorusu** — HealthKit tabanlı uyanma tahmini (isteğe bağlı, izin gerektirir).
- **Takvimden atlama önerileri** — yukarıda anlatılan opt-in özellik.
- **Bildirim İzni** — mevcut izin durumunu gösterir, reddedilmişse doğrudan Ayarlar uygulamasına yönlendirir.
- **Hakkında** — sürüm ve build numarası.

## Gizlilik

AlarmApp **local-first**'tür: hiçbir veri bir sunucuya gönderilmez, hesap oluşturman gerekmez. HealthKit ve Takvim verileri yalnızca cihazda işlenir. Ayrıntı için [`SECURITY.md`](SECURITY.md#gizlilik-notu).
