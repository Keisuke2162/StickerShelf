#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// マイページ（旧: 設定画面）から NavigationLink で表示されるヘルプ・ライセンス画面群。
/// 本体の設定フォームは `MyPageView` に統合済み。

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
