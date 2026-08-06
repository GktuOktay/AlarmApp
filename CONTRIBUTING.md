# Katkı Rehberi

AlarmApp’e katkı için teşekkürler.

## Dal stratejisi

- `main` — yayınlanabilir durum
- `develop` — aktif geliştirme (isteğe bağlı)
- `feature/*` — kısa ömürlü özellik dalları

## Commit mesajları

- **Türkçe**, tutarlı cümleler
- Conventional Commits öneki + Türkçe özet  
  Örnek: `özellik: bugün kapat aksiyonunu ana listeye ekle`
- IDE / yapay zekâ ortak yazar satırı **ekleme**

## Pull request

1. `AlarmAppCore` değiştiyse hem paket testlerinin (`swift test`) hem ilgili uygulama derlemesinin geçtiğini belirt.
2. WatchConnectivity veya HealthKit içeren PR’larda mümkünse gerçek cihaz notu ekle.
3. Kullanıcıya görünen değişiklik varsa `CHANGELOG.md` ve gerekirse `VERSION` güncelle (sade Türkçe).

## Kod kuralları

- `AlarmAppCore` içinde `import SwiftUI` yok.
- Ürün davranışı `docs/` ile çelişmesin; sözleşme değişince `docs/03` aynı PR’da güncellensin.
