enum ChainOrder {
    static func swapIndex(from index: Int, step: Int, isPlaced: [Bool]) -> Int? {
        var other = index + step
        while isPlaced.indices.contains(other) {
            if isPlaced[other] { return other }
            other += step
        }
        return nil
    }
}
