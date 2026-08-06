# Ürün Gereksinim Dokümanı (PRD)
## Akıllı Alarm Uygulaması — iOS + Apple Watch

**Doküman sahibi:** Ürün/Teknik Tasarım
**Platform:** iOS + watchOS — tamamen native Swift/SwiftUI, tek codebase (paylaşımlı Swift Package mimarisi)
**Versiyon:** 1.1 (Swift'e geçiş sonrası revizyon)
**Durum:** Taslak — geliştirme öncesi onay bekliyor

---

## 1. Vizyon

Sabahları birden fazla alarm kurarak "erteleme güvenliği" arayan kullanıcılar için, uyandığı anda gereksiz alarm gürültüsüyle uğraşmak zorunda kalmayan; bunu hem bilekten gelen otomatik sinyalle hem de birkaç dokunuşla manuel olarak yönetebilen bir alarm deneyimi.

**Tek cümlelik konumlandırma:** *"Alarmlarını grupla, uyandığında bilek seni anlasın, gerisini kapatsın."*

---

## 2. Problem Tanımı

- Ağır uyuyan / erteleme (snooze) alışkanlığı olan kullanıcılar bir zaman aralığına yayılmış çoklu alarm kurar.
- Erken uyandıklarında, geri kalan alarmların tek tek kapatılması hem zaman kaybı hem rahatsız edicidir (özellikle telefon uzaktaysa, ör. şarjda başka odada).
- Hafta içi düzenli kalkılan saatlerin, izin/tatil günlerinde manuel olarak her seferinde iptal edilmesi gerekir — tekrarlayan bir sürtünme noktasıdır.
- Yıl içinde tekil, düzensiz erken kalkışlar (uçuş, sınav vb.) için mevcut alarm uygulamaları uzun vadeli planlama arayüzü sunmaz.

---

## 3. Hedef Kullanıcı Personaları

### Persona A — "Tekrar Erteleyen Ece" (Ana persona)
- 28 yaşında, ofis çalışanı, Apple Watch her gece uyurken takılı.
- Sabah 06:00-07:00 arası 8-10 alarm kuruyor, genelde 3-4. alarmda uyanıyor.
- İhtiyaç: kalan alarmların otomatik/hızlı susturulması.

### Persona B — "Planlı Kaan"
- Vardiyalı çalışan veya sık seyahat eden, haftanın farklı günlerinde farklı kalkış saatleri var.
- İhtiyaç: haftalık/aylık bazda önceden planlama, istisna tanımlama.

### Persona C — "Gizlilik Odaklı Deniz"
- Açık kaynak topluluğundan, verisinin bulutta tutulmasını istemiyor.
- İhtiyaç: tamamen local-first, üçüncü taraf sunucuya veri göndermeyen bir mimari.

---

## 4. Hedefler (Goals) ve Hedef Olmayanlar (Non-Goals)

### Goals (v1 kapsamı)
- G1: Kullanıcı bir zaman aralığına gruplanmış çoklu alarm oluşturabilmeli.
- G2: Watch'ta manuel "Uyandım" onayıyla kalan grup alarmları iptal edilebilmeli.
- G3: Telefon üzerinden "bugün kapat" / "bu hafta pas geç" aksiyonları tek dokunuşla yapılabilmeli.
- G4: Yıl içindeki herhangi bir tarih için önceden istisna/plan tanımlanabilmeli.
- G5: Uygulama tamamen local-first çalışmalı, internet bağlantısı gerektirmemeli.

### Goals (v2 kapsamı — sonraki faz)
- G6: HealthKit + CoreMotion tabanlı **otomatik** uyanma algılama (kullanıcı onayı ile).
- G7: Watch complication ile hızlı erişim.

### Non-Goals (bilinçli olarak kapsam dışı)
- NG1: Android / Wear OS desteği (v1'de yok, ileride ayrı proje kararı gerektirir).
- NG2: Bulut senkronizasyonu / çoklu cihaz senkronizasyonu (local-first prensibiyle çelişir; talep gelirse opsiyonel iCloud yedekleme değerlendirilebilir).
- NG3: Sosyal özellikler (alarm paylaşma, arkadaşlarla yarışma vb.)
- NG4: Sistem "Rehber Modu"nu (Do Not Disturb) her koşulda kesin kırma garantisi — bu Apple'ın Critical Alert onayına bağlı, garanti edilemez (bkz. Risk Kaydı).

---

## 5. Özellik Spesifikasyonları ve Kabul Kriterleri

### F1 — Alarm Grubu Oluşturma
**Açıklama:** Kullanıcı bir başlangıç saati, bitiş saati, aralık (dakika) ve tekrar günleri (Pzt-Paz) girerek bir "Alarm Grubu" oluşturur. Uygulama bu aralıktaki tüm tekil alarmları otomatik üretir.

**Kabul Kriterleri:**
- [ ] Kullanıcı 06:00 başlangıç, 07:00 bitiş, 5 dk aralık girdiğinde 13 adet alarm örneği (`AlarmInstance`) üretilmeli (dahil-dahil aralık, ürün kararı olarak netleştirilecek — bkz. Açık Sorular).
- [ ] Grup adı, ses seçimi, tekrar günleri özelleştirilebilmeli.
- [ ] Grup oluşturma ekranı 3 adımdan fazla olmamalı (zaman aralığı → aralık/sıklık → gün seçimi).
- [ ] Aynı gün içinde çakışan iki grup varsa kullanıcı uyarılmalı.

### F2 — Watch Manuel "Uyandım" Onayı
**Açıklama:** Watch'ta aktif alarm çalarken veya son 30 dakika içinde çalmışsa, ekranda büyük "Uyandım" butonu görünür.

**Kabul Kriterleri:**
- [ ] Butona basıldığında ilgili grubun o günkü kalan tüm `pending` alarmları `cancelled` durumuna geçmeli.
- [ ] İşlem geri alınabilir olmalı ("Hayır, devam etsin" — 10 saniyelik geri alma penceresi, toast/undo pattern).
- [ ] Watch-iPhone bağlantısı yoksa (Bluetooth kapalı, menzil dışı), buton yerel olarak Watch tarafında alarmları durdurmalı ve bağlantı geldiğinde senkronize etmeli (offline-first kuyruklama).

### F3 — Manuel Grup Kontrolü (Telefon)
**Açıklama:** Ana ekranda her grup için hızlı aksiyon menüsü: "Bugün kapat", "Bu hafta pas geç", "Kalıcı olarak durdur".

**Kabul Kriterleri:**
- [ ] "Bugün kapat" sadece bugüne ait alarm örneklerini etkilemeli, gelecekteki tekrarları etkilememeli.
- [ ] "Bu hafta pas geç" seçilen haftanın tamamı için `Exception(dateRange)` kaydı oluşturmalı, kullanıcı önizleme görmeli ("Pzt-Cuma arası 5 gün, 40 alarm etkilenecek" gibi).
- [ ] Aksiyonlar swipe-to-action + uzun basma menüsü olarak iki erişim yoluyla sunulmalı (erişilebilirlik).

### F4 — Yıllık Takvim / İleri Tarih Planlama
**Açıklama:** Kullanıcı takvim görünümünden herhangi bir güne dokunup o gün için grup ata / iptal et / özel tek seferlik alarm tanımlayabilir.

**Kabul Kriterleri:**
- [ ] Takvim, mevcut istisnaları renkli işaretlerle göstermeli (ör. yeşil: normal, turuncu: istisna var, gri: tüm gruplar pasif).
- [ ] Bir istisna en fazla 1 yıl ileriye tanımlanabilmeli (veri şişmesini önlemek için sınır).
- [ ] Geçmiş tarihler için istisna oluşturulamamalı.

### F5 (v2) — Otomatik Uyanma Algılama
**Açıklama:** HealthKit kalp atış hızı + CoreMotion hareket verisiyle uyanma anı tahmin edilir, kullanıcıya onay sorulur.

**Kabul Kriterleri (yüksek seviye, v2 detayları ayrı teknik dokümanda):**
- [ ] Algılama asla kullanıcı onayı olmadan alarm iptal etmemeli (fail-safe: sessiz kalırsa alarm çalmaya devam eder).
- [ ] Yanlış pozitif oranı kullanıcı testinde ölçülmeli, %15'in üzerinde ise F5 varsayılan kapalı gelmeli.

---

## 6. Başarı Metrikleri

| Metrik | Hedef | Ölçüm Yöntemi |
|---|---|---|
| Grup oluşturma tamamlama oranı | Onboarding sonrası kullanıcıların %70'i ilk grubu oluşturur | Local event log (analytics eklenmeyecekse App Store review + kullanıcı geri bildirimi) |
| Manuel "bugün kapat" kullanım sıklığı | Aktif kullanıcı başına haftada ortalama 2+ kullanım | Local kullanım sayacı (opt-in, cihazda kalır) |
| Watch onay akışı tamamlanma süresi | Bildirimden onaya ortalama < 5 saniye | UX test / kronometre |
| Crash-free session oranı | > %99.5 | Xcode Organizer / açık kaynak crash reporting (opsiyonel, gizlilik onayı ile) |

> Not: Gizlilik önceliği nedeniyle varsayılan olarak **hiçbir veri dışarı gönderilmez**. Yukarıdaki metrikler ya tamamen cihaz-lokal sayaçlarla ya da App Store'un kendi (opt-in) analytics'iyle ölçülür.

---

## 7. Kapsam Dışı Riskler / Ürün Kararları Gerektiren Açık Sorular

1. Alarm aralığı hesaplanırken bitiş saati dahil mi hariç mi? (06:00-07:00, 5dk aralık → son alarm 06:55 mi 07:00 mi?)
2. "Bu hafta pas geç" ifadesi takvim haftası mı (Pzt-Paz) yoksa bugünden itibaren 7 gün mü?
3. Kullanıcı grubu sildiğinde geçmiş istisna kayıtları da silinsin mi, yoksa arşivlensin mi?
4. Critical Alert entitlement başvurusu reddedilirse, ürünün "sessiz modu delme" vaadi nasıl konumlandırılacak? (Pazarlama/App Store açıklaması buna göre revize edilmeli.)

Bu sorular **F1-F4 geliştirmesi başlamadan önce** karara bağlanmalı; aksi halde veri modeli ve UX akışlarında geriye dönük değişiklik riski var.

---

## 8. Bağımlı Dokümanlar

- `01-ux-tasarim-ve-akislar.md` — Ekran envanteri, kullanıcı akışları, etkileşim tasarımı
- `02-teknik-mimari.md` — Sistem mimarisi, modül tasarımı, senkronizasyon stratejisi
- `03-veri-modeli-ve-arayuzler.md` — Veri şeması, platform kanalı sözleşmeleri
- `04-yol-haritasi-ve-sprintler.md` — Faz/sprint bazlı planlama
- `05-test-qa-plani.md` — Test stratejisi
- `06-acik-kaynak-governance.md` — Katkı süreci, versiyonlama, yayın politikası
