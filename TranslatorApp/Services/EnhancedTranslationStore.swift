import Foundation
import Translation

// Enhanced translation store that supports:
// 1. Apple's on-device Translation framework (iOS 14+)
// 2. Google Translate API as fallback
// 3. Local dictionary for offline support
@available(iOS 14.0, *)
final class EnhancedTranslationStore: ObservableObject {
    // Published translation results for UI binding
    @Published var translations: [String: String] = [:]
    @Published var isTranslating: Bool = false
    @Published var supportedLanguages: [String] = []
    
    // Local dictionary for offline fallback
    private var localDict: [String: String] = [:]
    
    // Configuration for source and target languages
    private var sourceLanguage: Locale = Locale(identifier: "en")
    private var targetLanguage: Locale = Locale(identifier: "zh-Hans")
    
    // Google Translate API configuration (optional)
    private let googleAPIKey: String? = nil // Replace with your API key
    private let googleTranslateBaseURL = "https://translation.googleapis.com/language/translate/v2"
    
    init() {
        loadLocalDictionary()
        checkTranslationSupport()
    }
    
    private func loadLocalDictionary() {
        // Enhanced local dictionary with more entries
        localDict = [
            "hello": "你好",
            "thank you": "谢谢",
            "goodbye": "再见",
            "yes": "是",
            "no": "不",
            "please": "请",
            "excuse me": "不好意思",
            "sorry": "对不起",
            "help": "帮助",
            "water": "水",
            "food": "食物",
            "restaurant": "餐厅",
            "hotel": "酒店",
            "airport": "机场",
            "station": "车站",
            "taxi": "出租车",
            "bus": "公交车",
            "train": "火车",
            "how much": "多少钱",
            "where": "哪里",
            "what": "什么",
            "when": "什么时候",
            "why": "为什么",
            "how": "怎么",
            "open": "开放",
            "closed": "关闭",
            "entrance": "入口",
            "exit": "出口",
            "toilet": "厕所",
            "emergency": "紧急情况",
            // Reverse mappings
            "你好": "hello",
            "谢谢": "thank you",
            "再见": "goodbye",
            "是": "yes",
            "不": "no",
            "请": "please",
            "对不起": "sorry",
            "帮助": "help",
            "水": "water",
            "食物": "food"
        ]
    }
    
    private func checkTranslationSupport() {
        // Check if Apple Translation is available for the language pair
        if #available(iOS 14.0, *) {
            // Note: This is a simplified check. In a real app, you'd check specific language pairs
            supportedLanguages = ["en", "zh-Hans", "es", "fr", "de", "ja", "ko"]
        }
    }
    
    // Main translation method with multiple fallbacks
    func translate(text: String) async -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first
        if let cached = translations[cleanText] {
            return cached
        }
        
        DispatchQueue.main.async {
            self.isTranslating = true
        }
        
        var result = cleanText
        
        // Try Apple Translation first (most accurate and private)
        if #available(iOS 14.0, *) {
            result = await translateWithAppleFramework(text: cleanText) ?? result
        }
        
        // If Apple Translation fails, try Google Translate API
        if result == cleanText && googleAPIKey != nil {
            result = await translateWithGoogleAPI(text: cleanText) ?? result
        }
        
        // If all else fails, use local dictionary
        if result == cleanText {
            result = translateWithLocalDictionary(text: cleanText)
        }
        
        // Cache the result
        DispatchQueue.main.async {
            self.translations[cleanText] = result
            self.isTranslating = false
        }
        
        return result
    }
    
    // Synchronous version for backward compatibility
    func translate(text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try cached result first
        if let cached = translations[cleanText] {
            return cached
        }
        
        // Use local dictionary for immediate response
        return translateWithLocalDictionary(text: cleanText)
    }
    
    @available(iOS 14.0, *)
    private func translateWithAppleFramework(text: String) async -> String? {
        do {
            // Create translation session
            let session = TranslationSession(from: sourceLanguage, to: targetLanguage)
            
            // Perform translation
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            print("Apple Translation error: \(error)")
            return nil
        }
    }
    
    private func translateWithGoogleAPI(text: String) async -> String? {
        guard let apiKey = googleAPIKey else { return nil }
        
        guard let url = URL(string: googleTranslateBaseURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "q": text,
            "source": sourceLanguage.languageCode ?? "en",
            "target": targetLanguage.languageCode ?? "zh",
            "key": apiKey
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let translations = data["translations"] as? [[String: Any]],
               let firstTranslation = translations.first,
               let translatedText = firstTranslation["translatedText"] as? String {
                return translatedText
            }
        } catch {
            print("Google Translate error: \(error)")
        }
        
        return nil
    }
    
    private func translateWithLocalDictionary(text: String) -> String {
        let key = text.lowercased()
        return localDict[key] ?? text
    }
    
    // Configuration methods
    func setLanguages(source: String, target: String) {
        sourceLanguage = Locale(identifier: source)
        targetLanguage = Locale(identifier: target)
        translations.removeAll() // Clear cache when languages change
    }
    
    func addToLocalDictionary(source: String, target: String) {
        localDict[source.lowercased()] = target
        localDict[target.lowercased()] = source // Add reverse mapping
    }
}