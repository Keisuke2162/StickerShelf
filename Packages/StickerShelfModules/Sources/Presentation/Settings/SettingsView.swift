#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// マイページ（旧: 設定画面）から NavigationLink で表示されるライセンス画面。
/// 本体の設定フォームは `MyPageView` に統合済み。

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 書籍データのクレジット。NDL サーチと楽天ウェブサービスの利用条件で表示が求められている
                Text("書籍データ").font(FontToken.sectionTitle())
                Text("書誌情報は、国立国会図書館サーチの API を利用して取得しています。国立国会図書館の書誌データは、クリエイティブ・コモンズ 表示 4.0 国際 ライセンス（CC BY 4.0）で提供されています。")
                    .font(FontToken.bodyRegular())
                Link("国立国会図書館サーチ", destination: URL(string: "https://ndlsearch.ndl.go.jp/").unsafelyUnwrapped)
                    .font(FontToken.bodyRegular())
                Link("CC BY 4.0 ライセンス", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode.ja").unsafelyUnwrapped)
                    .font(FontToken.bodyRegular())
                Text("書影は、楽天ブックスの情報を利用しています。")
                    .font(FontToken.bodyRegular())
                Link("Supported by Rakuten Developers", destination: URL(string: "https://webservice.rakuten.co.jp/").unsafelyUnwrapped)
                    .font(FontToken.bodyRegular())

                Text("Fonts").font(FontToken.sectionTitle())
                Text("Dela Gothic One / Zen Kaku Gothic New: SIL Open Font License (OFL)")
                    .font(FontToken.bodyRegular())
            }.padding()
        }.navigationTitle("ライセンス")
    }
}

#endif
