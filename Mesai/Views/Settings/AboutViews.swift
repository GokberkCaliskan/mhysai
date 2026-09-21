import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                block("Kısaca", "\(AppInfo.name) hiçbir kişisel verini toplamaz, saklamaz ya da paylaşmaz. Hesap, sunucu, reklam ve analiz aracı yoktur.")
                block("Girdiğin bilgiler", "Maaşın, mesai saatlerin, kaytarma süreleri, giderlerin ve isteklerin yalnızca bu cihazda, uygulamanın kendi alanında saklanır. Uygulamayı silersen tüm veriler de silinir.")
                block("İnternet", "Uygulama yalnızca \"Varlıklarım\" sekmesinde fiyat çekerken internete çıkar. Gönderilen tek şey sembol adıdır (ör. NVDA, GC=F); maaşın, giderlerin ve kaç adet varlığın olduğu asla gönderilmez. Varlık eklemezsen uygulama hiç internete çıkmaz.")
                block("Kanıtı nasıl görürsün?", "Uygulamanın tüm kaynak kodu herkese açık: Ayarlar → Kaynak kodu. Telefonu uçak moduna alırsan sayaç, kaytarma ve gider hesapları aynen çalışmaya devam eder; yalnızca fiyatlar güncellenemez.")
                block("Paylaşım", "Paylaşım kartını yalnızca sen \"Paylaş\" dediğinde, seçtiğin uygulamaya gönderilir.")
                block("Hesaplamalar", "Maaş, vergi ve SGK hesapları bilgilendirme amaçlıdır; bordro, vergi ya da finansal danışmanlık yerine geçmez. Gerçek bordronla farklar olabilir.")
                block("İletişim", "Soru ve önerilerini Ayarlar → Destek ve geri bildirim bağlantısından iletebilirsin.")
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Gizlilik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).foregroundStyle(.secondary)
        }
    }
}

struct CalculationInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                info("Günlük kazanç", "Aylık net maaşın, o ayın ücretli çalışma saniyelerine bölünür. 20 iş günü çeken ayda günlük kazanç, 23 iş günü çeken aydan yüksektir. Öğle arası ücretsiz sayılabilir.")
                info("Resmî tatiller", "Yılbaşı, 23 Nisan, 1 Mayıs, 19 Mayıs, 15 Temmuz, 30 Ağustos, 29 Ekim ile Ramazan ve Kurban bayramlarında sayaç çalışmaz. Arifelerde ve 28 Ekim'de 13:00'ten sonrası tatildir. Dinî bayram tarihleri takvimden hesaplanır; Diyanet ilanıyla nadiren bir gün fark olabilir.")
                info("Brüt maaş", "İşçi SGK primi %14, işsizlik primi %1 (SGK tavanına kadar), ücret gelir vergisi dilimleri (%15–%40), damga vergisi binde 7,59 ve asgari ücret gelir/damga vergisi istisnası uygulanır. Vergi matrahı yıl içinde biriktikçe net maaş azalır.")
                info("Sınırlar", "Her ay aynı brütün alındığı varsayılır. BES, özel sağlık sigortası, engellilik indirimi, ikramiye, prim ve yan haklar hesaba katılmaz. Vergi parametreleri her yıl güncellenir.")
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Nasıl hesaplanıyor?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func info(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).foregroundStyle(.secondary)
        }
    }
}
