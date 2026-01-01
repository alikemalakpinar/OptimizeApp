//
//  AppStrings.swift
//  optimize
//
//  Centralized localization management for commercial-grade user experience.
//  All user-facing strings should be defined here for consistency and easy translation.
//

import Foundation

struct AppStrings {

    // MARK: - Processing Stages
    enum Process {
        static var ready: String { String(localized: "Hazır", comment: "Status: Ready") }
        static var initializing: String { String(localized: "Başlatılıyor...", comment: "Status: Initializing") }
        static var validating: String { String(localized: "Dosya doğrulanıyor...", comment: "Status: Validating document") }
        static var analyzing: String { String(localized: "İçerik analiz ediliyor...", comment: "Status: Analyzing content") }
        static var scanDetected: String { String(localized: "Taranmış belge iyileştiriliyor (MRC)...", comment: "Status: MRC processing") }
        static var vectorPreserving: String { String(localized: "Vektörler korunarak sıkıştırılıyor...", comment: "Status: Vector preservation") }
        static var aggressiveCompression: String { String(localized: "Agresif sıkıştırma uygulanıyor...", comment: "Status: Aggressive compression") }
        static var optimizing: String { String(localized: "Optimize ediliyor...", comment: "Status: Optimizing") }
        static var finalizing: String { String(localized: "Tamamlanıyor...", comment: "Status: Finalizing") }
        static var loadingImage: String { String(localized: "Görüntü yükleniyor...", comment: "Status: Loading image") }
        static var compressingImage: String { String(localized: "Görüntü sıkıştırılıyor...", comment: "Status: Compressing image") }
        static var preparingVideo: String { String(localized: "Video hazırlanıyor...", comment: "Status: Preparing video") }
        static var encodingVideo: String { String(localized: "Video kodlanıyor...", comment: "Status: Encoding video") }
        static var loadingFile: String { String(localized: "Dosya yükleniyor...", comment: "Status: Loading file") }
        static var compressing: String { String(localized: "Sıkıştırılıyor...", comment: "Status: Compressing") }
    }

    // MARK: - Error Messages
    enum Error {
        static var accessDenied: String { String(localized: "Dosya erişim izni reddedildi. Lütfen dosyayı tekrar seçin.", comment: "Error: Access denied") }
        static var invalidPDF: String { String(localized: "Geçersiz veya bozuk PDF dosyası. Lütfen başka bir dosya deneyin.", comment: "Error: Invalid PDF") }
        static var invalidFile: String { String(localized: "Bu dosya okunamıyor.", comment: "Error: Invalid file") }
        static var emptyPDF: String { String(localized: "PDF dosyası boş veya okunamıyor.", comment: "Error: Empty PDF") }
        static var encryptedPDF: String { String(localized: "Bu PDF şifreli. Lütfen önce şifresini kaldırın.", comment: "Error: Encrypted PDF") }
        static var contextFailed: String { String(localized: "İşlem başlatılamadı. Cihazınızın belleği yetersiz olabilir.", comment: "Error: Context creation failed") }
        static var saveFailed: String { String(localized: "Kaydetme başarısız. Depolama alanını kontrol edin.", comment: "Error: Save failed") }
        static var cancelled: String { String(localized: "İşlem kullanıcı tarafından iptal edildi.", comment: "Error: Cancelled") }
        static var memoryPressure: String { String(localized: "Yetersiz bellek. Lütfen bazı uygulamaları kapatın ve tekrar deneyin.", comment: "Error: Memory pressure") }
        static var fileTooLarge: String { String(localized: "Dosya çok büyük. Lütfen 500 sayfadan az dosyalar deneyin.", comment: "Error: File too large") }
        static var pageFailed: String { String(localized: "Sayfa işlenemedi. Dosya bozuk olabilir.", comment: "Error: Page processing failed") }
        static var timeout: String { String(localized: "İşlem zaman aşımına uğradı. Daha küçük bir dosya deneyin.", comment: "Error: Timeout") }
        static var exportFailed: String { String(localized: "Video dışa aktarılamadı. Daha düşük kalite deneyin.", comment: "Error: Export failed") }
        static var unsupportedType: String { String(localized: "Bu dosya türü henüz desteklenmiyor.", comment: "Error: Unsupported type") }
        static var generic: String { String(localized: "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.", comment: "Error: Generic") }
    }

    // MARK: - UI Labels
    enum UI {
        static var original: String { String(localized: "Orijinal", comment: "Label: Original") }
        static var optimized: String { String(localized: "Optimize", comment: "Label: Optimized") }
        static var saveSpace: String { String(localized: "Alan Kazan", comment: "Label: Save space") }
        static var compressing: String { String(localized: "Sıkıştırılıyor", comment: "Label: Compressing") }
        static var selectFile: String { String(localized: "Dosya Seç", comment: "Button: Select file") }
        static var compress: String { String(localized: "Sıkıştır", comment: "Button: Compress") }
        static var share: String { String(localized: "Paylaş", comment: "Button: Share") }
        static var save: String { String(localized: "Kaydet", comment: "Button: Save") }
        static var cancel: String { String(localized: "İptal", comment: "Button: Cancel") }
        static var retry: String { String(localized: "Tekrar Dene", comment: "Button: Retry") }
        static var done: String { String(localized: "Tamam", comment: "Button: Done") }
        static var newFile: String { String(localized: "Yeni Dosya", comment: "Button: New file") }
        static var history: String { String(localized: "Geçmiş", comment: "Tab: History") }
        static var settings: String { String(localized: "Ayarlar", comment: "Tab: Settings") }
    }

    // MARK: - Screen Titles
    enum Titles {
        static var home: String { String(localized: "Optimize", comment: "Screen title: Home") }
        static var analyze: String { String(localized: "Analiz", comment: "Screen title: Analyze") }
        static var presets: String { String(localized: "Kalite Seçimi", comment: "Screen title: Presets") }
        static var processing: String { String(localized: "İşleniyor", comment: "Screen title: Processing") }
        static var result: String { String(localized: "Sonuç", comment: "Screen title: Result") }
        static var history: String { String(localized: "Geçmiş", comment: "Screen title: History") }
        static var settings: String { String(localized: "Ayarlar", comment: "Screen title: Settings") }
    }

    // MARK: - Preset Names
    enum Presets {
        static var mail: String { String(localized: "E-posta (25 MB)", comment: "Preset: Mail") }
        static var mailDescription: String { String(localized: "E-posta ekleri için mükemmel", comment: "Preset description: Mail") }
        static var whatsapp: String { String(localized: "WhatsApp", comment: "Preset: WhatsApp") }
        static var whatsappDescription: String { String(localized: "Hızlı paylaşım için optimize", comment: "Preset description: WhatsApp") }
        static var quality: String { String(localized: "En İyi Kalite", comment: "Preset: Quality") }
        static var qualityDescription: String { String(localized: "Minimum kayıp, maksimum sıkıştırma", comment: "Preset description: Quality") }
        static var custom: String { String(localized: "Özel Boyut", comment: "Preset: Custom") }
        static var customDescription: String { String(localized: "Hedef boyutunuzu belirleyin", comment: "Preset description: Custom") }
    }

    // MARK: - Result Screen
    enum Result {
        static var success: String { String(localized: "Başarılı!", comment: "Result: Success") }
        static var saved: String { String(localized: "Kazandığınız Alan", comment: "Result: Space saved") }
        static var reduction: String { String(localized: "küçültme", comment: "Result: Reduction percentage") }
        static var beforeAfter: String { String(localized: "Öncesi / Sonrası", comment: "Result: Before/After") }
    }

    // MARK: - Onboarding
    enum Onboarding {
        static var welcomeTitle: String { String(localized: "Hoş Geldiniz", comment: "Onboarding: Welcome title") }
        static var welcomeSubtitle: String { String(localized: "PDF, görüntü ve videoları saniyeler içinde küçültün", comment: "Onboarding: Welcome subtitle") }
        static var privacyTitle: String { String(localized: "Gizlilik Öncelikli", comment: "Onboarding: Privacy title") }
        static var privacySubtitle: String { String(localized: "Dosyalarınız asla cihazınızdan çıkmaz. %100 cihaz içi işlem.", comment: "Onboarding: Privacy subtitle") }
        static var qualityTitle: String { String(localized: "Profesyonel Kalite", comment: "Onboarding: Quality title") }
        static var qualitySubtitle: String { String(localized: "Akıllı algoritma metinleri korur, sadece gereksiz veriyi atar", comment: "Onboarding: Quality subtitle") }
        static var getStarted: String { String(localized: "Başlayalım", comment: "Onboarding: Get started button") }

        // Page 1
        static var page1Title: String { String(localized: "Dosyalar Artık\nEngel Değil", comment: "Onboarding 1 Title") }
        static var page1Sub: String { String(localized: "Kaliteden ödün vermeden GB'larca veriyi MB'lara dönüştür. E-posta limitlerine takılma.", comment: "Onboarding 1 Sub") }

        // Page 2
        static var page2Title: String { String(localized: "Tamamen Cihaz İçi\nTamamen Güvenli", comment: "Onboarding 2 Title") }
        static var page2Sub: String { String(localized: "Dosyaların asla telefonundan çıkmaz. İnternet olmasa bile güvenle çalışır.", comment: "Onboarding 2 Sub") }

        // Page 3
        static var page3Title: String { String(localized: "Tek Dokunuşla\nÖzgürlük", comment: "Onboarding 3 Title") }
        static var page3Sub: String { String(localized: "Karmaşık ayarlar yok. Dosyanı seç, sıkıştır ve anında paylaş.", comment: "Onboarding 3 Sub") }

        static var `continue`: String { String(localized: "Devam Et", comment: "Onboarding: Continue button") }
        static var start: String { String(localized: "Başlayalım", comment: "Onboarding: Start button") }
        static var skip: String { String(localized: "Şimdilik Geç", comment: "Onboarding: Skip button") }
    }

    // MARK: - Paywall
    enum Paywall {
        static var title: String { String(localized: "Pro'ya Yükselt", comment: "Paywall: Title") }
        static var subtitle: String { String(localized: "Sınırsız sıkıştırma ve tüm özellikler", comment: "Paywall: Subtitle") }
        static var monthlyPrice: String { String(localized: "Aylık", comment: "Paywall: Monthly") }
        static var yearlyPrice: String { String(localized: "Yıllık", comment: "Paywall: Yearly") }
        static var yearlySavings: String { String(localized: "%50 Tasarruf", comment: "Paywall: Yearly savings") }
        static var feature1: String { String(localized: "Sınırsız dosya sıkıştırma", comment: "Paywall: Feature 1") }
        static var feature2: String { String(localized: "Tüm kalite seçenekleri", comment: "Paywall: Feature 2") }
        static var feature3: String { String(localized: "Özel boyut hedefleme", comment: "Paywall: Feature 3") }
        static var feature4: String { String(localized: "Reklamsız deneyim", comment: "Paywall: Feature 4") }
        static var privacyBadge: String { String(localized: "Dosyalarınız cihazınızdan çıkmaz", comment: "Paywall: Privacy badge") }
        static var restorePurchases: String { String(localized: "Satın Alımları Geri Yükle", comment: "Paywall: Restore purchases") }

        // Subscription flow
        static var header: String { String(localized: "Abonelik Nasıl Çalışır?", comment: "Paywall Header") }
        static var yearlyPlan: String { String(localized: "Yıllık", comment: "Plan Title") }
        static var yearlyDetail: String { String(localized: "₺899,99 (₺75/ay)", comment: "Plan Detail") }
        static var monthlyPlan: String { String(localized: "Aylık", comment: "Plan Title") }
        static var monthlyDetail: String { String(localized: "₺99,99", comment: "Plan Detail") }
        static var savings: String { String(localized: "%58 Tasarruf", comment: "Savings Badge") }
        static var startPro: String { String(localized: "Pro'yu Başlat", comment: "CTA Button") }
        static var secureApple: String { String(localized: "Apple ile Güvenli", comment: "Trust Badge") }
        static var cancelAnytime: String { String(localized: "İstediğin zaman iptal et", comment: "Trust Badge") }
        static var restore: String { String(localized: "Satın Alımları Geri Yükle", comment: "Restore Button") }

        // Timeline
        static var today: String { String(localized: "Bugün", comment: "Timeline") }
        static var todayDesc: String { String(localized: "Tüm Pro özelliklere anında erişim. Sınırsız dosya boyutu ve toplu işlem.", comment: "Timeline Desc") }
        static var anytime: String { String(localized: "İstediğin Zaman", comment: "Timeline") }
        static var anytimeDesc: String { String(localized: "Ayarlar'dan aboneliğini kolayca iptal edebilirsin.", comment: "Timeline Desc") }
        static var renewal: String { String(localized: "Yenileme", comment: "Timeline") }
        static var renewalDescYearly: String { String(localized: "Yıllık faturalandırılır. İstediğin zaman iptal et.", comment: "Timeline Desc") }
        static var renewalDescMonthly: String { String(localized: "Aylık faturalandırılır. İstediğin zaman iptal et.", comment: "Timeline Desc") }

        // Features
        static var featureNoAds: String { String(localized: "Reklam yok, temiz arayüz", comment: "Feature") }
        static var featureAllFiles: String { String(localized: "PDF, görüntü, video ve ofis dosyaları", comment: "Feature") }
        static var featureSmartTarget: String { String(localized: "Akıllı hedef boyutlar ve kalite profilleri", comment: "Feature") }
        static var featurePriority: String { String(localized: "Öncelikli sıkıştırma motoru", comment: "Feature") }

        // Social Proof
        static var filesOptimized: String { String(localized: "dosya optimize edildi", comment: "Social Proof") }
    }

    // MARK: - Gamification
    enum Stats {
        static var totalSaved: String { String(localized: "Toplam Kazanılan Alan", comment: "Stats: Total saved") }
        static var filesProcessed: String { String(localized: "İşlenen Dosya", comment: "Stats: Files processed") }
        static var todaySaved: String { String(localized: "Bugün Kazandığınız", comment: "Stats: Today saved") }
    }

    // MARK: - Fun Facts (Progress Screen)
    enum FunFacts {
        static var fact1: String { String(localized: "Biliyor muydunuz? PDF'lerin %40'ı insan gözüne görünmeyen veri içerir.", comment: "Fun fact 1") }
        static var fact2: String { String(localized: "Fontlarınızı diyete sokuyoruz...", comment: "Fun fact 2") }
        static var fact3: String { String(localized: "Sıkıştırılan her MB bir kediyi mutlu eder. (Kaynak: Biz)", comment: "Fun fact 3") }
        static var fact4: String { String(localized: "Dosyanızdaki fazlalıkları buduyoruz...", comment: "Fun fact 4") }
        static var fact5: String { String(localized: "Dijital detoks uyguluyoruz...", comment: "Fun fact 5") }
        static var fact6: String { String(localized: "Gereksiz piksellere tek tek veda ediyoruz...", comment: "Fun fact 6") }
        static var fact7: String { String(localized: "Dosyanızı e-postaya sığdırma sanatında ustalaşıyoruz...", comment: "Fun fact 7") }
        static var fact8: String { String(localized: "Görünmez metadata avındayız...", comment: "Fun fact 8") }

        static var all: [String] {
            [fact1, fact2, fact3, fact4, fact5, fact6, fact7, fact8]
        }
    }

    // MARK: - Home Screen Specific
    enum Home {
        static var recentActivity: String { String(localized: "Son İşlemler", comment: "Home: Recent Activity") }
        static var viewAll: String { String(localized: "Tümü", comment: "Home: View All") }
        static var performanceTitle: String { String(localized: "Performans Özeti", comment: "Home: Performance Title") }
        static var performanceSubtitle: String { String(localized: "Gerçek tasarruf verileri", comment: "Home: Performance Subtitle") }
        static var totalSaved: String { String(localized: "Toplam", comment: "Home: Total Saved") }
        static var avgSavings: String { String(localized: "Ortalama", comment: "Home: Avg Savings") }
        static var bestResult: String { String(localized: "En İyi", comment: "Home: Best Result") }
        static var dropFile: String { String(localized: "Dosyayı Bırak", comment: "Home: Drop File") }
        static var selectFile: String { String(localized: "Dosya Seç", comment: "Home: Select File") }
        static var dropHint: String { String(localized: "Optimize etmek için bırak", comment: "Home: Drop Hint") }
        static var selectHint: String { String(localized: "Dokun veya dosyayı sürükle", comment: "Home: Select Hint") }

        // Empty State
        static var storageTitle: String { String(localized: "Depolama Alanın", comment: "Empty: Title") }
        static var storageSubtitle: String { String(localized: "Rahatlamak İstiyor", comment: "Empty: Subtitle") }
        static var storageBody: String { String(localized: "İlk dosyanı seç ve sihri başlat", comment: "Empty: Body") }
    }

    // MARK: - Settings Screen
    enum Settings {
        static var title: String { String(localized: "Ayarlar", comment: "Settings: Title") }
        static var membership: String { String(localized: "Üyelik", comment: "Settings: Section") }
        static var compression: String { String(localized: "Sıkıştırma", comment: "Settings: Section") }
        static var history: String { String(localized: "Geçmiş", comment: "Settings: Section") }
        static var privacy: String { String(localized: "Gizlilik", comment: "Settings: Section") }
        static var support: String { String(localized: "Destek", comment: "Settings: Section") }

        static var defaultPreset: String { String(localized: "Varsayılan Kalite", comment: "Settings: Row") }
        static var wifiOnly: String { String(localized: "Sadece Wi-Fi ile İşle", comment: "Settings: Row") }
        static var wifiOnlySubtitle: String { String(localized: "Mobil veri kullanma", comment: "Settings: Row Subtitle") }
        static var deleteOriginal: String { String(localized: "İşlemden Sonra Orijinali Sil", comment: "Settings: Row") }
        static var deleteOriginalSubtitle: String { String(localized: "Orijinal dosyayı kaldır", comment: "Settings: Row Subtitle") }
        static var keepHistory: String { String(localized: "Geçmişi Sakla", comment: "Settings: Row") }
        static var clearHistory: String { String(localized: "Geçmişi Temizle", comment: "Settings: Button") }
        static var clearHistoryTitle: String { String(localized: "Geçmişi Temizle", comment: "Settings: Alert Title") }
        static var clear: String { String(localized: "Temizle", comment: "Settings: Button") }
        static var cancel: String { String(localized: "İptal", comment: "Settings: Button") }
        static var clearAll: String { String(localized: "Tümünü Temizle", comment: "Settings: Button") }
        static var items: String { String(localized: "öğe", comment: "Settings: Items count") }

        static var anonymousData: String { String(localized: "Anonim kullanım verileri", comment: "Settings: Row") }
        static var anonymousDataSubtitle: String { String(localized: "Uygulamayı geliştirmemize yardım et", comment: "Settings: Row Subtitle") }
        static var privacyPolicy: String { String(localized: "Gizlilik Politikası", comment: "Settings: Link") }
        static var termsOfService: String { String(localized: "Kullanım Koşulları", comment: "Settings: Link") }

        static var helpFAQ: String { String(localized: "Yardım & SSS", comment: "Settings: Link") }
        static var sendFeedback: String { String(localized: "Geri Bildirim Gönder", comment: "Settings: Link") }
        static var rateApp: String { String(localized: "Uygulamayı Değerlendir", comment: "Settings: Link") }
        static var manageSubscription: String { String(localized: "Aboneliği Yönet", comment: "Settings: Link") }

        static var madeWith: String { String(localized: "İstanbul'da ❤️ ile yapıldı", comment: "Settings: Footer") }

        static func daysFormat(_ days: Int) -> String {
            String(localized: "\(days) gün", comment: "Settings: Days format")
        }

        static func clearHistoryMessage(_ count: Int) -> String {
            String(localized: "Bu işlem \(count) sıkıştırma geçmişi öğesini kalıcı olarak silecek. Bu işlem geri alınamaz.", comment: "Settings: Clear history message")
        }
    }

    // MARK: - Result Screen
    enum ResultScreen {
        static var greatJob: String { String(localized: "Harika İş!", comment: "Result: Title") }
        static var featherText: String { String(localized: "Dosyan artık tüy gibi hafif", comment: "Result: Subtitle") }
        static var before: String { String(localized: "Öncesi", comment: "Result: Label") }
        static var after: String { String(localized: "Sonrası", comment: "Result: Label") }
        static var saved: String { String(localized: "Kazanılan", comment: "Result: Label") }
        static var share: String { String(localized: "Şimdi Paylaş", comment: "Result: Button") }
        static var saveFiles: String { String(localized: "Dosyalara Kaydet", comment: "Result: Button") }
        static var newFile: String { String(localized: "Yeni Dosya Seç", comment: "Result: Button") }
    }

    // MARK: - Modern Paywall
    enum ModernPaywall {
        static var premiumTitle: String { String(localized: "Optimize Premium", comment: "Modern Paywall: Title") }
        static var featureTitle: String { String(localized: "Sınırsız Erişimi Aç", comment: "Modern Paywall: Feature Title") }
        static var featureDescription: String { String(localized: "Dosya boyutu limiti yok. Reklam yok.\nEn hızlı sıkıştırma.", comment: "Modern Paywall: Feature Description") }
        static var unlimitedBadge: String { String(localized: "Sınırsız", comment: "Modern Paywall: Unlimited Badge") }

        // Weekly Plan (low barrier entry)
        static var weeklyTitle: String { String(localized: "Haftalık", comment: "Modern Paywall: Weekly Title") }
        static var weeklySubtitle: String { String(localized: "İstediğin zaman iptal et", comment: "Modern Paywall: Weekly Subtitle") }
        static var weeklyPrice: String { String(localized: "₺29,99", comment: "Modern Paywall: Weekly Price") }
        static var weeklyPriceUS: String { String(localized: "$1.99", comment: "Modern Paywall: Weekly Price US") }

        // Yearly Plan (best value - anchor pricing)
        static var yearlyTitle: String { String(localized: "Yıllık", comment: "Modern Paywall: Yearly Title") }
        static var yearlySubtitle: String { String(localized: "₺7,69 / hafta", comment: "Modern Paywall: Yearly Subtitle") }
        static var yearlySubtitleUS: String { String(localized: "$0.38 / week", comment: "Modern Paywall: Yearly Subtitle US") }
        static var yearlyPrice: String { String(localized: "₺399,99", comment: "Modern Paywall: Yearly Price") }
        static var yearlyPriceUS: String { String(localized: "$19.99", comment: "Modern Paywall: Yearly Price US") }
        static var yearlySavings: String { String(localized: "%75 TASARRUF", comment: "Modern Paywall: Yearly Savings Badge") }
        static var yearlySavingsUS: String { String(localized: "80% OFF", comment: "Modern Paywall: Yearly Savings Badge US") }

        static var popularBadge: String { String(localized: "POPÜLER", comment: "Modern Paywall: Popular Badge") }
        static var bestValueBadge: String { String(localized: "EN İYİ DEĞER", comment: "Modern Paywall: Best Value Badge") }

        // Features for paywall
        static var feature1: String { String(localized: "Sınırsız dosya sıkıştırma", comment: "Modern Paywall: Feature 1") }
        static var feature2: String { String(localized: "1 GB'a kadar büyük dosyalar", comment: "Modern Paywall: Feature 2") }
        static var feature3: String { String(localized: "Reklamsız, temiz arayüz", comment: "Modern Paywall: Feature 3") }
        static var feature4: String { String(localized: "Öncelikli sıkıştırma motoru", comment: "Modern Paywall: Feature 4") }

        // Legacy - keeping for compatibility
        static var monthlyTitle: String { String(localized: "Aylık", comment: "Modern Paywall: Monthly Title") }
        static var monthlySubtitle: String { String(localized: "Esneklik ve kontrol için en iyisi", comment: "Modern Paywall: Monthly Subtitle") }
        static var monthlyPrice: String { String(localized: "₺29,99/hafta", comment: "Modern Paywall: Monthly Price") }
        static var monthlyBilled: String { String(localized: "Haftalık faturalandırılır", comment: "Modern Paywall: Monthly Billed") }
        static var yearlyBilled: String { String(localized: "Yıllık faturalandırılır", comment: "Modern Paywall: Yearly Billed") }

        static var tryFree: String { String(localized: "Devam Et", comment: "Modern Paywall: Try Free Button") }
        static var startTrial: String { String(localized: "1 Hafta Ücretsiz Dene", comment: "Modern Paywall: Start Trial Button") }
        static var cancelAnytime: String { String(localized: "İstediğin zaman iptal et. Soru sorulmaz.", comment: "Modern Paywall: Cancel Anytime") }

        // Social proof
        static var userCount: String { String(localized: "+100.000 kullanıcı", comment: "Modern Paywall: User Count") }
    }

    // MARK: - Commitment Signing
    enum Commitment {
        static var title: String { String(localized: "Taahhütünüzü İmzalayın", comment: "Commitment: Title") }
        static var subtitle: String { String(localized: "Bu günden itibaren ben:", comment: "Commitment: Subtitle") }
        static var item1: String { String(localized: "Dosyalarımı düzenli tutacağım", comment: "Commitment: Item 1") }
        static var item2: String { String(localized: "Depolama alanımı verimli kullanacağım", comment: "Commitment: Item 2") }
        static var item3: String { String(localized: "Gereksiz dosyaları silmek yerine optimize edeceğim", comment: "Commitment: Item 3") }
        static var item4: String { String(localized: "Kaliteden ödün vermeyeceğim", comment: "Commitment: Item 4") }
        static var item5: String { String(localized: "Paylaşımlarımı kolaylaştıracağım", comment: "Commitment: Item 5") }
        static var clear: String { String(localized: "Temizle", comment: "Commitment: Clear button") }
    }

    // MARK: - Rating Request
    enum Rating {
        static var title: String { String(localized: "Bizi Değerlendirin!", comment: "Rating: Title") }
        static var description: String { String(localized: "Bu uygulama sizin gibi kullanıcılar için tasarlandı. Puanınız ne kadar yüksek olursa, o kadar çok kişiye yardım edebiliriz.", comment: "Rating: Description") }
        static var userCount: String { String(localized: "+100.000 kullanıcı", comment: "Rating: User count") }
        static var next: String { String(localized: "İleri", comment: "Rating: Next button") }

        // Testimonials
        static var testimonial1: String { String(localized: "Sıkıştırma özellikleri muhteşem. Sonunda dosyalarımı kontrol altına aldım.", comment: "Rating: Testimonial 1") }
        static var testimonial2: String { String(localized: "Basit, etkili ve kullanışlı. Tam ihtiyacım olan şeydi.", comment: "Rating: Testimonial 2") }
        static var testimonial3: String { String(localized: "Temiz tasarımı ve kolay kullanımı sevdim. Kesinlikle tavsiye ederim.", comment: "Rating: Testimonial 3") }
        static var testimonial4: String { String(localized: "Sonunda bilgiyi anlayan bir uygulama. 5 yıldız.", comment: "Rating: Testimonial 4") }
    }

    // MARK: - Error Messages
    enum ErrorMessage {
        static var generic: String { String(localized: "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.", comment: "Error: Generic") }
        static var accessDenied: String { String(localized: "Dosya erişimi reddedildi. Lütfen dosyayı tekrar seçin.", comment: "Error: Access Denied") }
        static var invalidPDF: String { String(localized: "Geçersiz veya bozuk PDF dosyası. Dosyanın hasarlı olmadığından emin olun.", comment: "Error: Invalid PDF") }
        static var invalidFile: String { String(localized: "Bu dosya okunamadı.", comment: "Error: Invalid File") }
        static var emptyPDF: String { String(localized: "PDF dosyası boş veya okunamıyor.", comment: "Error: Empty PDF") }
        static var encryptedPDF: String { String(localized: "Bu PDF şifre korumalı. Lütfen önce şifreyi kaldırın.", comment: "Error: Encrypted PDF") }
        static var contextFailed: String { String(localized: "PDF işleme başlatılamadı. Cihazınızın belleği yetersiz olabilir.", comment: "Error: Context Failed") }
        static var saveFailed: String { String(localized: "Dosya kaydedilemedi. Lütfen depolama alanınızı kontrol edin.", comment: "Error: Save Failed") }
        static var cancelled: String { String(localized: "İşlem kullanıcı tarafından iptal edildi.", comment: "Error: Cancelled") }
        static var memoryPressure: String { String(localized: "Yetersiz bellek. Lütfen bazı uygulamaları kapatıp tekrar deneyin.", comment: "Error: Memory Pressure") }
        static var fileTooLarge: String { String(localized: "Dosya çok büyük. Lütfen 500 sayfadan az dosyalar deneyin.", comment: "Error: File Too Large") }
        static var pageFailed: String { String(localized: "Sayfa işlenemedi. Dosya bozuk olabilir.", comment: "Error: Page Failed") }
        static var timeout: String { String(localized: "İşlem zaman aşımına uğradı. Lütfen daha küçük bir dosya deneyin.", comment: "Error: Timeout") }
        static var exportFailed: String { String(localized: "Video dışa aktarma başarısız. Lütfen daha düşük kalite deneyin.", comment: "Error: Export Failed") }
        static var unsupportedType: String { String(localized: "Bu dosya türü henüz desteklenmiyor.", comment: "Error: Unsupported Type") }
    }
}
