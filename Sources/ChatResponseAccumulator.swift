struct ChatResponseAccumulator {
    private(set) var text = ""

    mutating func append(_ delta: String) {
        text += delta
    }

    mutating func useCompletedTextIfEmpty(_ completedText: String) {
        guard text.isEmpty else { return }
        text = completedText
    }

    mutating func reset() {
        text = ""
    }
}
