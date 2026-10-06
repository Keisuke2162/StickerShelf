#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// マイページタブ。ユーザー情報（仮）と既存の設定項目をまとめて 1 画面に表示する。
public struct MyPageView: View {
    private let container: PresentationContainer
    @State private var viewModel: SettingsViewModel
    @Environment(ThemeStore.self) private var theme

    public init(container: PresentationContainer) {
        self.container = container
        self._viewModel = State(initialValue: SettingsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                settingsForm
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.reload() }
        }
    }

    /// 本棚/積読/カレンダーと同じ screenTitle 風ヘッダー。
    private var header: some View {
        HStack {
            Text("マイページ")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var settingsForm: some View {
        Form {
                Section {
                    userInfoRow
                }

                Section("テーマカラー") {
                    themeColorPicker
                }

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
                    Button {
                        if let s = UIPasteboard.general.string {
                            viewModel.apiKeyInput = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Label("ペースト", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .tint(ColorToken.accent)
                    .accessibilityLabel("クリップボードから貼り付け")
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
            .scrollContentBackground(.hidden)
    }

    /// アプリ全体の背景色を選ぶカラースウォッチ。
    private var themeColorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(BoardColor.allCases, id: \.self) { c in
                Button {
                    theme.set(c)
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BoardAppearanceStyle.background(c))
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.color == c ? ColorToken.accent : ColorToken.hairline,
                                            lineWidth: theme.color == c ? 3 : 1)
                            )
                        Text(c.displayName)
                            .font(FontToken.caption())
                            .foregroundStyle(ColorToken.ink)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    /// 仮のユーザー情報。将来 Account 機能が入ったら差し替える。
    private var userInfoRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(ColorToken.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("ゲストユーザー")
                    .font(FontToken.sectionTitle())
                    .foregroundStyle(ColorToken.ink)
                Text("StickerShelf")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.inkSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
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

#endif
