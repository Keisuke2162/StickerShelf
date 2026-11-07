//
//  BookAPIClient.swift
//  Infrastructure
//
//  Created by Kei on 2026/11/07.
//

import Foundation
import OSLog
import Domain

private let clientLogger = Logger(subsystem: "StickerShelf", category: "BookAPIClient")

/// 自前の書籍検索API（Cloudflare Workers の book-api）を呼ぶクライアント。
public struct BookAPIClient: Sendable {
  public let session: URLSession
  public let baseURL: URL
  public let userAgent: String
  
  public init(session: URLSession, baseURL: URL, userAgent: String = "StickerShelf/1.0 iOS") {
    self.session = session
    self.baseURL = baseURL
    self.userAgent = userAgent
  }
  
  /// GET /v1/books/search?q=…&page=…（page は 1 始まり）
  func search(query: String, page: Int) async throws -> BookAPISearchResponseDTO {
    let endpoint = baseURL.appending(path: "v1/books/search")
    guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
      throw DomainError.catalogUnavailable(reason: "invalid endpoint")
    }
    
    // URLQueryItem に入れた日本語は URLComponents が自動で URL エンコードする
    components.queryItems = [
      .init(name: "q", value: query),
      .init(name: "page", value: String(page))
    ]
    guard let url = components.url else {
      throw DomainError.catalogUnavailable(reason: "invalid URL")
    }
    let (data, response) = try await perform(request: makeRequest(url: url))
    
    // ステータスコードが200-299じゃなければエラーをthrow
    try BookAPIErrorMapper.validate(response: response, data: data)
    
    // DTO変換
    return try decode(BookAPISearchResponseDTO.self, from: data)
  }
  
  /// GET /v1/books/isbn/{isbn}。見つからない（404）ときは nil。
  func book(isbn: ISBN) async throws -> BookAPIBookDTO? {
    let url = baseURL.appending(path: "v1/books/isbn").appending(path: isbn.value)
    let (data, response) = try await perform(request: makeRequest(url: url))
    if let http = response as? HTTPURLResponse, http.statusCode == 404 {
      // 404
      return nil
    }
    try BookAPIErrorMapper.validate(response: response, data: data)
    return try decode(BookAPIBookResponseDTO.self, from: data).book
  }
  
  /// URLをURLRequestに変換
  private func makeRequest(url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    return request
  }
  
  /// 通信処理の実行関数
  private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      return try await session.data(for: request)
    } catch let urlError as URLError {
      if urlError.code == .cancelled {
        // デバウンスで前の検索を取り消したときのキャンセルは、エラーに変換せずそのまま伝える
        clientLogger.debug("URL request cancelled")
        throw urlError
      }
      clientLogger.error("URLError: code=\(urlError.code.rawValue) description=\(urlError.localizedDescription, privacy: .public)")
      throw BookAPIErrorMapper.map(urlError: urlError)
    }
  }
  
  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      clientLogger.error("decode failed: \(String(describing: error), privacy: .public)")
      throw DomainError.catalogUnavailable(reason: "invalid response")
    }
  }
}
