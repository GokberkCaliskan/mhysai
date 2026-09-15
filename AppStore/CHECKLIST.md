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
- [x] Gizlilik politikası ve destek sayfası → `docs/privacy.html`, `docs/support.html`
- [x] 21 birim testi (maaş, tatil, bordro — Verginet ile birebir, kaytarma)

## 🟡 Senin yapman gerekenler (hesabınla ilgili)
1. **Destek e-postasını belirle**
   - `Mesai/App/AppInfo.swift` → `supportEmail` (doldurulunca Ayarlar'da "Geri bildirim gönder" görünür)
   - `docs/privacy.html` ve `docs/support.html` içindeki `DESTEK_EPOSTASI`
2. **Gizlilik ve destek sayfalarını yayınla** — en kolayı GitHub Pages: repo'yu GitHub'a gönder → Settings → Pages → `main` / `docs`. Linkler `https://<kullanıcı>.github.io/<repo>/privacy.html` olur.
3. **Mağaza adını seç** — `metadata.md`'deki önerilerden; App Store Connect adın boşta olup olmadığını kayıt sırasında söyler.
4. **App Store Connect'te uygulama kaydı** — Uygulamalar → + → Yeni Uygulama
   - Platform: iOS · Birincil dil: Türkçe · Paket kimliği: `com.gokberk.Mesai` · SKU: `mesai-ios`
   - Paket kimliği listede yoksa Xcode'da bir kez Archive almak (otomatik imzalama) ya da developer.apple.com → Identifiers'dan eklemek yeterli.
5. **Xcode'dan yükle** — `Mesai.xcodeproj` → hedef cihaz "Any iOS Device" → Product → Archive → Distribute App → App Store Connect.
6. **TestFlight'ta kendi telefonunda dene** — özellikle gerçek mesai saatinde sayacı, bayram/arife günlerini, gizlilik modunu.
7. **Sürüm sayfasını doldur** — `metadata.md`'den metinler, ekran görüntüleri, App Privacy: "Veri Toplanmıyor", yaş 4+, fiyat.
8. **Kayıt sonrası** — App Store kimliğini `AppInfo.appStoreID`'ye yaz (Ayarlar'da "Uygulamayı değerlendir" görünür) ve bir sonraki sürümle gönder.

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
