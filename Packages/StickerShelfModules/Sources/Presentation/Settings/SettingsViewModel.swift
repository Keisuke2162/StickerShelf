#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class SettingsViewModel {
    public var apiKeyInput: String = ""
    public private(set) var apiKeyStatus: APIKeyStatus = .notSet
    public var isAPIKeyVisible: Bool = false
    public private(set) var connectionResult: CatalogConnectionTestResult?
    public private(set) var isTestingConnection = false
    public var restrictToJapanese: Bool
    public var errorMessage: String?

    private let container: PresentationContainer

    public init(container: PresentationContainer) {
        self.container = container
        self.restrictToJapanese = container.searchPreferences.restrictToJapanese()
    }

    public func reload() async {
        do { apiKeyStatus = try container.loadAPIKeyStatus.execute() } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func saveAPIKey() async {
        guard let key = APIKey(apiKeyInput) else {
            errorMessage = "APIキーが空です"
            return
        }
        do {
            try container.saveAPIKey.execute(key)
            apiKeyInput = ""
            await reload()
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func deleteAPIKey() async {
        do {
            try container.deleteAPIKey.execute()
            await reload()
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        connectionResult = await container.testConnection.execute()
    }

    public func didToggleJapanese(_ value: Bool) {
        restrictToJapanese = value
        container.searchPreferences.setRestrictToJapanese(value)
    }
}

#endif
