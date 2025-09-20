import Foundation

// Very small demo translation store. Replace with SQLite or better lookup in production.
// This class demonstrates the translation API surface: translate(text: String) -> String.
// In a full app you may want async APIs, caching, and fuzzy matching.
final class TranslationStore: ObservableObject {
    // Simple in-memory dictionary for demo. Keys are lowercase source strings.
    private var dict: [String: String] = [:]

    init() {
        loadSample()
    }

    private func loadSample() {
        // A tiny sample mapping English -> Chinese (Simplified) and vice versa.
        dict = [
            "hello": "你好",
            "thank you": "谢谢",
            "goodbye": "再见",
            "yes": "是",
            "no": "不",
            "你好": "hello",
            "谢谢": "thank you"
        ]
    }

    // Simple exact-match translate. If not found, returns original string.
    // Replace with a better lookup: fuzzy match, phrase splits, or ML model output.
    func translate(text: String) -> String {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return dict[key] ?? text
    }
}
