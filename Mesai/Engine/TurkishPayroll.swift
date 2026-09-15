import Foundation

/// Brüt ücretten net ücrete bordro hesabı (Türkiye).
///
/// Kaynaklar (2026): 332 Seri No'lu GVGT ücret tarifesi, brüt asgari ücret 33.030 ₺,
/// SGK tavanı asgari ücretin 9 katı, işçi SGK %14 + işsizlik %1, damga vergisi binde 7,59.
/// Asgari ücrete isabet eden gelir vergisi ve damga vergisi her çalışan için istisnadır.
struct PayrollParameters {
    struct Bracket {
        let upperBound: Double
        let rate: Double
    }

    let year: Int
    let minimumWageGross: Double
    let sgkCeilingMultiplier: Double
    let employeeSGKRate: Double
    let unemploymentRate: Double
    let stampTaxRate: Double
    /// Ücret gelirleri tarifesi; son dilimin üst sınırı sonsuz.
    let brackets: [Bracket]

    static let y2026 = PayrollParameters(
        year: 2026,
        minimumWageGross: 33_030,
        sgkCeilingMultiplier: 9,
        employeeSGKRate: 0.14,
        unemploymentRate: 0.01,
        stampTaxRate: 0.00759,
        brackets: [
            Bracket(upperBound: 190_000, rate: 0.15),
            Bracket(upperBound: 400_000, rate: 0.20),
            Bracket(upperBound: 1_500_000, rate: 0.27),
            Bracket(upperBound: 5_300_000, rate: 0.35),
            Bracket(upperBound: .infinity, rate: 0.40),
        ]
    )

    /// Tanımlı en yakın yılın parametreleri. Yeni yıl tarifeleri açıklandıkça eklenmeli.
    static func forYear(_ year: Int) -> PayrollParameters {
        .y2026
    }

    var sgkCeiling: Double { minimumWageGross * sgkCeilingMultiplier }

    /// Kümülatif matraha göre toplam gelir vergisi.
    func incomeTax(onCumulative base: Double) -> Double {
        var remaining = max(0, base)
        var lower = 0.0
        var tax = 0.0
        for bracket in brackets {
            let slice = min(remaining, bracket.upperBound - lower)
            guard slice > 0 else { break }
            tax += slice * bracket.rate
            remaining -= slice
            lower = bracket.upperBound
        }
        return tax
    }

    func marginalRate(atCumulative base: Double) -> Double {
        brackets.first { base < $0.upperBound }?.rate ?? brackets.last?.rate ?? 0
    }
}

struct PayrollMonth: Identifiable, Equatable {
    let month: Int
    let gross: Double
    let sgk: Double
    let unemployment: Double
    let incomeTax: Double
    let stampTax: Double
    /// Bu ayın ücretine uygulanan en yüksek vergi dilimi oranı.
    let bracketRate: Double

    var id: Int { month }
    var net: Double { gross - sgk - unemployment - incomeTax - stampTax }
    var totalDeductions: Double { gross - net }
}

enum TurkishPayroll {
    /// Yıl boyunca her ay aynı brüt ücret alındığı varsayımıyla 12 aylık bordro.
    static func months(monthlyGross gross: Double, parameters p: PayrollParameters) -> [PayrollMonth] {
        guard gross > 0 else { return [] }

        let sgkBase = min(gross, p.sgkCeiling)
        let sgk = sgkBase * p.employeeSGKRate
        let unemployment = sgkBase * p.unemploymentRate
        let taxBase = gross - sgk - unemployment

        let minimumSGKBase = p.minimumWageGross
        let minimumTaxBase = p.minimumWageGross - minimumSGKBase * (p.employeeSGKRate + p.unemploymentRate)
        let stampTax = max(0, gross - p.minimumWageGross) * p.stampTaxRate

        return (1...12).map { month in
            let previous = taxBase * Double(month - 1)
            let tax = p.incomeTax(onCumulative: previous + taxBase) - p.incomeTax(onCumulative: previous)

            let minimumPrevious = minimumTaxBase * Double(month - 1)
            let exemption = p.incomeTax(onCumulative: minimumPrevious + minimumTaxBase) - p.incomeTax(onCumulative: minimumPrevious)

            return PayrollMonth(
                month: month,
                gross: gross,
                sgk: sgk,
                unemployment: unemployment,
                incomeTax: max(0, tax - exemption),
                stampTax: stampTax,
                bracketRate: p.marginalRate(atCumulative: previous + taxBase)
            )
        }
    }
}
