#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// マイページタブ。ユーザー情報（仮）と設定項目をまとめて 1 画面に表示する。
public struct MyPageView: View {
    private let container: PresentationContainer
    private let router: Router
    @Environment(ThemeStore.self) private var theme

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                settingsForm
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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

                Section("メモ") {
                    NavigationLink {
                        MemoListView(container: container, router: router)
                    } label: {
                        Label("気になる本メモ", systemImage: "list.bullet.clipboard")
                    }
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
}

#endif
