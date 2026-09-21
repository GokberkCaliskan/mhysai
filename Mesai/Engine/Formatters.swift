import Foundation

enum Format {
    static let locale = Locale(identifier: "tr_TR")

    static func lira(_ value: Double, fractionDigits: Int = 2) -> String {
        // NaN/sonsuz değerler biçimlendirmede ve Int dönüşümlerinde çökmeye yol açabilir
        let value = value.isFinite ? value : 0
        return value.formatted(
            .currency(code: "TRY")
                .locale(locale)
                .precision(.fractionLength(fractionDigits))
        )
    }

    /// "1.234,56" ve ayrı gösterilecek küçük kuruş altı haneler ("78").
    static func tickingLira(_ value: Double) -> (main: String, tail: String) {
        let main = lira(value, fractionDigits: 2)
        let scaled = (value * 10_000).rounded(.down)
        let subKurus = scaled.isFinite ? Int(scaled.clamped(to: 0...9_007_199_254_740_991)) % 100 : 0
        return (main, String(format: "%02d", subKurus))
    }

    static func number(_ value: Double, fractionDigits: Int = 1) -> String {
        let value = value.isFinite ? value : 0
        return value.formatted(.number.locale(locale).precision(.fractionLength(0...fractionDigits)))
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }

    static func dayAndClock(_ date: Date, relativeTo now: Date = AppClock.now) -> String {
        let calendar = Calendar.turkish
        if calendar.isDate(date, inSameDayAs: now) { return "bugün \(clock(date))" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "yarın \(clock(date))"
        }
        let day = date.formatted(.dateTime.weekday(.wide).locale(locale))
        return "\(day) \(clock(date))"
    }

    /// 3 sa 12 dk / 12 dk 05 sn
    static func duration(_ interval: TimeInterval) -> String {
        let safe = interval.isFinite ? interval.clamped(to: 0...(400 * 24 * 3600)) : 0
        let total = Int(safe)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours) sa \(minutes) dk" }
        if minutes > 0 { return "\(minutes) dk \(String(format: "%02d", seconds)) sn" }
        return "\(seconds) sn"
    }

    /// 45 dk / 1 sa 20 dk
    static func minutes(_ minutes: Int) -> String {
        let minutes = max(0, minutes)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) dk" }
        return rest == 0 ? "\(hours) sa" : "\(hours) sa \(rest) dk"
    }

    /// Çalışma süresini iş günü cinsinden yazar: "3 iş günü 2 sa", "5 sa 20 dk".
    static func workTime(_ seconds: TimeInterval, dailyPaidMinutes: Int) -> String {
        let safe = seconds.isFinite ? seconds.clamped(to: 0...(500 * 365 * 24 * 3600)) : 0
        let totalMinutes = Int((safe / 60).rounded())
        guard dailyPaidMinutes > 0 else { return self.minutes(totalMinutes) }
        let days = totalMinutes / dailyPaidMinutes
        let rest = totalMinutes % dailyPaidMinutes
        guard days > 0 else { return self.minutes(max(rest, 1)) }
        let hours = rest / 60
        return hours > 0 ? "\(days) iş günü \(hours) sa" : "\(days) iş günü"
    }

    static func dayMonthClock(_ date: Date) -> String {
        let day = date.formatted(.dateTime.day().month(.wide).locale(locale))
        return "\(day) \(clock(date))"
    }

    static func minutesToDate(_ minutes: Int) -> Date {
        Calendar.turkish.date(byAdding: .minute, value: minutes, to: Calendar.turkish.startOfDay(for: AppClock.now))!
    }

    static func dateToMinutes(_ date: Date) -> Int {
        let c = Calendar.turkish.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}


extension Double {
    /// Aralık dışına taşan (ya da NaN olan) değerleri güvenli sınıra çeker.
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.lowerBound }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
