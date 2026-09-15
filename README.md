# Mhysai: Maaş Sayacı

Mesaide her saniye ne kazandığını gösteren iOS uygulaması.

- **Canlı maaş sayacı** — maaşın mesai saatlerinde saniye saniye akar; öğle arası, hafta sonu, resmî tatil ve bayramlarda durur
- **Net ya da brüt maaş** — brütte 2026 SGK, gelir vergisi dilimleri, damga vergisi ve asgari ücret istisnasıyla aylık net
- **Kaytarma sayacı** — tuvalette, çay molasında, boş toplantıda kazandığın
- **Kaç Mesai?** — giderlerin ve istediğin şeyler kaç iş günü, kaç maaş ediyor
- **Gizlilik** — hesap yok, sunucu yok; tüm veriler cihazda

## Geliştirme

```bash
brew install xcodegen
xcodegen generate
open Mesai.xcodeproj
```

Testler: `xcodebuild test -project Mesai.xcodeproj -scheme Mesai -destination 'platform=iOS Simulator,name=iPhone 17'`

- [Gizlilik Politikası](https://gokberkcaliskan.github.io/mhysai/privacy.html)
- [Destek](https://github.com/GokberkCaliskan/mhysai/issues)
