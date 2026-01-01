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
}
