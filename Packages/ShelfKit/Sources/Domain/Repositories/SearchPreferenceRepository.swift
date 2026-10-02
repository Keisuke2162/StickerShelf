public protocol SearchPreferenceRepository: Sendable {
    func restrictToJapanese() -> Bool
    func setRestrictToJapanese(_ value: Bool)
}
