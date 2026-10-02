#if canImport(UIKit)
import SwiftUI
import Domain
import Application

public struct SettingsView: View {
    private let container: PresentationContainer
    @State private var viewModel: SettingsViewModel

    public init(container: PresentationContainer) {
        self.container = container
        self._viewModel = State(initialValue: SettingsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("書籍検索API") {
                    HStack {
                        if viewModel.isAPIKeyVisible {
                            TextField("APIキー", text: $viewModel.apiKeyInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.password)
                        } else {
                            SecureField("APIキー", text: $viewModel.apiKeyInput)
                                .textContentType(.password)
                        }
                        Button(action: { viewModel.isAPIKeyVisible.toggle() }) {
                            Image(systemName: viewModel.isAPIKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.isAPIKeyVisible ? "APIキーを隠す" : "APIキーを表示")
                    }
                    PasteButton(payloadType: String.self) { strings in
                        if let value = strings.first {
                            Task { @MainActor in
                                viewModel.apiKeyInput = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    .tint(ColorToken.accent)
                    switch viewModel.apiKeyStatus {
                    case .notSet:
                        Text("未設定").font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
                    case .set(let masked):
                        Text("現在のキー: \(masked)").font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
                    }
                    Button("保存") { Task { await viewModel.saveAPIKey() } }
                    Button("接続テスト") { Task { await viewModel.testConnection() } }
                    if viewModel.isTestingConnection {
                        ProgressView()
                    }
                    if let result = viewModel.connectionResult {
                        connectionLabel(for: result)
                    }
                    Button("削除", role: .destructive) { Task { await viewModel.deleteAPIKey() } }
                    NavigationLink("APIキーの取得方法") { APIKeyHelpView() }
                }

                Section("検索") {
                    Toggle("日本語の本に限定", isOn: Binding(
                        get: { viewModel.restrictToJapanese },
                        set: { viewModel.didToggleJapanese($0) }
                    ))
                }

                Section("このアプリについて") {
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    NavigationLink("ライセンス") { LicenseView() }
                }
            }
            .navigationTitle("設定")
            .scrollContentBackground(.hidden)
            .background(ColorToken.boardBackground.ignoresSafeArea())
            .task { await viewModel.reload() }
        }
    }

    @ViewBuilder
    private func connectionLabel(for result: CatalogConnectionTestResult) -> some View {
        switch result {
        case .success:
            Label("接続 OK", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .invalidAPIKey:
            Label("APIキーが正しくありません", systemImage: "xmark.circle.fill").foregroundStyle(ColorToken.sunday)
        case .quotaExceeded:
            Label("検索上限に達しました。APIキーを設定すると安定します", systemImage: "exclamationmark.triangle.fill").foregroundStyle(ColorToken.sunday)
        case .networkUnavailable:
            Label("インターネットに接続されていません", systemImage: "wifi.slash").foregroundStyle(ColorToken.sunday)
        case .serviceUnavailable:
            Label("検索サービスに接続できません", systemImage: "exclamationmark.triangle").foregroundStyle(ColorToken.sunday)
        case .unknown:
            Label("不明なエラー", systemImage: "questionmark.circle").foregroundStyle(ColorToken.sunday)
        }
    }
}

struct APIKeyHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("APIキーの取得手順").font(FontToken.sectionTitle())
                Text("""
                1. Google Cloud Console にログイン、プロジェクトを作成
                2. 「APIとサービス」→「ライブラリ」で Books API を有効化
                3. 「認証情報」→「APIキーを作成」
                4. iOS アプリ制限で Bundle ID を登録、API 制限で Books API のみに
                5. 作成されたキーをコピーし、設定画面に貼り付けて保存→接続テスト
                """).font(FontToken.bodyRegular())
            }.padding()
        }.navigationTitle("APIキーの取得方法")
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fonts").font(FontToken.sectionTitle())
                Text("Dela Gothic One / Zen Kaku Gothic New: SIL Open Font License (OFL)")
                    .font(FontToken.bodyRegular())
            }.padding()
        }.navigationTitle("ライセンス")
    }
}

#endif
