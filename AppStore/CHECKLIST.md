# App Store'a çıkış kontrol listesi

## ✅ Projede hazır olanlar
- [x] Uygulama ikonu (1024×1024, saydamlıksız)
- [x] Açılış ekranı rengi (beyaz flaş yok)
- [x] `PrivacyInfo.xcprivacy` gizlilik bildirimi (UserDefaults · CA92.1, takip yok, veri toplama yok)
- [x] Şifreleme beyanı: `ITSAppUsesNonExemptEncryption = NO` (her yüklemede soru sorulmaz)
- [x] Kategori: Finans · Sürüm 1.0.0 (1) · yalnızca iPhone, dikey
- [x] VoiceOver etiketleri (sayaç, kartlar, +/− butonları, gün seçici)
- [x] Uygulama içi "Gizlilik" ve "Nasıl hesaplanıyor?" sayfaları, sürüm bilgisi
- [x] Değerlendirme isteği (3 farklı gün kullanımdan sonra, sürüm başına bir kez)
- [x] Maaş değişince geçmiş günlerin kaytarma tutarları korunuyor
- [x] Mağaza metinleri → `AppStore/metadata.md`
- [x] 6,9" ekran görüntüleri → `AppStore/Screenshots/`
- [x] Gizlilik politikası, destek ve tanıtım sayfası → `docs/` (GitHub Pages)
- [x] 21 birim testi (maaş, tatil, bordro — Verginet ile birebir, kaytarma)

## 🟡 Kalan adımlar
1. **App Store Connect'te uygulama kaydı** (senin hesabınla, tarayıcıdan) — Uygulamalar → + → Yeni Uygulama
   - Platform: iOS · Ad: **Mhysai: Maaş Sayacı** · Birincil dil: Türkçe · Paket kimliği: `com.gokberk.Mesai` · SKU: `com.gokberk.Mesai` · Kullanıcı erişimi: Tam erişim
2. **Derleme yükleme** — `xcodebuild archive` + `-exportArchive` (App Store Connect'e upload). Kayıt açılmadan yükleme reddedilir.
3. **TestFlight'ta kendi telefonunda dene** — gerçek mesai saatinde sayaç, gizlilik modu, paylaşım.
4. **Sürüm sayfasını doldur** — `metadata.md`'deki metinler, `Screenshots/` görselleri, App Privacy: "Veri Toplanmıyor", yaş 4+, fiyat: ücretsiz → **İncelemeye gönder**.
5. **Yayın sonrası** — App Store kimliğini `AppInfo.appStoreID`'ye yaz (Ayarlar'da "Uygulamayı değerlendir" görünür).

## 📅 Periyodik bakım
- **Her ocak:** yeni gelir vergisi dilimleri, asgari ücret ve SGK tavanı → `Mesai/Engine/TurkishPayroll.swift` içine yeni yıl parametresi ekle ve `forYear` güncelle.
- **Yıl ortası asgari ücret zammı olursa:** aynı dosyada o yılın parametresi.
- **Fiyat karşılaştırmaları** (çay, simit, dürüm…): `Mesai/Models/Activity.swift` → `PriceComparison.all`.

## 🧪 Ekran görüntülerini yeniden almak
Debug derlemesini iPhone 17 Pro Max simülatöründe şu argümanlarla aç:
```
-demoData YES -demoReveal YES -demoNow 2026-09-15T14:32:00
```
Durum çubuğu için: `xcrun simctl status_bar booted override --time 14:32 --batteryState charged --batteryLevel 100`
Demo modu yalnızca Debug derlemesinde vardır; App Store sürümüne girmez.
