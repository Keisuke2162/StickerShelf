//
//  BookAPIErrorMapper.swift
//  Infrastructure
//
//  Created by Kei on 2026/11/07.
//

import Foundation
import OSLog
import Domain

private let errorLogger = Logger(subsystem: "StickerShelf", category: "BookAPIErrorMapper")

/// 自前APIのエラー応答を DomainError に変換する。
enum BookAPIErrorMapper {
  /// ステータスコードが 2xx でなければ DomainError を投げる。
  static func validate(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "(binary \(data.count) bytes)"
      errorLogger.error("HTTP \(http.statusCode) body: \(body, privacy: .public)")
      throw map(statusCode: http.statusCode, data: data)
    }
  }
  
  static func map(statusCode: Int, data: Data) -> DomainError {
    let message = (try? JSONDecoder().decode(BookAPIErrorBodyDTO.self, from: data))?.message ?? ""
    switch statusCode {
    case 429:
      // 自前APIの回数制限（同じIPから60秒に30回まで）を超えた
      return .catalogQuotaExceeded
    case 500...599:
      // 502 は NDL も楽天も応答しなかったとき、500 は Worker 内の想定外のエラー
      return .catalogUnavailable(reason: "server error \(statusCode): \(message)")
    default:
      // 400（入力の誤り）など。404 は呼び出し側（ISBN検索）で「見つからない」として先に処理する
      return .catalogUnavailable(reason: "HTTP \(statusCode): \(message)")
    }
  }
  
  /// 通信そのものの失敗（オフラインなど）は .network に寄せる
  static func map(urlError: URLError) -> DomainError {
    .network
  }
}
