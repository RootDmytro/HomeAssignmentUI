//
//  DataLoader.swift
//  HomeAssignmentUI
//
//  Created by Dmytro Yaropovetsky on 8/25/23.
//

import Combine
import CoreData

struct ProfileImageResult: Codable {
    let small: String
    let medium: String
    let large: String
}

struct UserResult: Codable {
    let id: String
    let username: String
    let name: String
    let bio: String?
    let profile_image: ProfileImageResult
}

struct PhotoURLsResult: Codable {
    let raw: String?
    let full: String?
    let regular: String?
    let small: String?
    let thumb: String?
    let small_s3: String?
}

struct PhotoResult: Codable {
    let id: String
    let width: Int
    let height: Int
    let description: String?
    let alt_description: String?
    let urls: PhotoURLsResult
    let user: UserResult
}

struct SearchPhotosResultPage: Decodable {
    var total: Int
    var total_pages: Int
    var results: [PhotoResult]
}

class DataLoader {
    private enum APIConstants {
        static let searchPhotosEndpoint = "https://api.unsplash.com/search/photos"
        static let pageKey = "page"
        static let clientIdKey = "client_id"
        static let queryKey = "query"
    }

    func request(searchTerm: String, page: Int) -> AnyPublisher<SearchPhotosResultPage, Error> {
        Future { promise in
            self.startRequest(searchTerm: searchTerm, page: page, completion: promise)
        }
        .eraseToAnyPublisher()
    }

    func startRequest(searchTerm: String, page: Int, completion: @escaping (Result<SearchPhotosResultPage, Error>) -> Void) {
        DispatchQueue.global().async {
            let query = searchTerm

            var components = URLComponents(string: APIConstants.searchPhotosEndpoint)!
            components.queryItems = [
                URLQueryItem(name: APIConstants.pageKey, value: String(page + 1)),
                URLQueryItem(name: APIConstants.clientIdKey, value: "c99a7e7599297260b46b7c9cf36727badeb1d37b1f24aa9ef5d844e3fbed76fe"),
                URLQueryItem(name: APIConstants.queryKey, value: query)
            ]
            let source = components.url!

            print("requesting page: \(page + 1), query: \(query)")

            var data: Data
            do {
                data = try self.downloadData(source: source)
            } catch {
                print("Could not get contents of a file, error: \(error.localizedDescription)")
                self.complete(with: .failure(error), completion: completion)
                return
            }

            let page: SearchPhotosResultPage
            do {
                page = try self.convertData(data: data)
            } catch {
                print("Decoding error: \(error.localizedDescription)")
                self.complete(with: .failure(error), completion: completion)
                return
            }

            self.complete(with: .success(page), completion: completion)
        }
    }

    open func downloadData(source: URL) throws -> Data {
        do {
            return try Data(contentsOf: source)
        } catch {
            throw error
        }
    }

    open func convertData(data: Data) throws -> SearchPhotosResultPage {
        try! JSONDecoder().decode(SearchPhotosResultPage.self, from: data)
    }

    open func complete(with result: Result<SearchPhotosResultPage, Error>, completion: @escaping (Result<SearchPhotosResultPage, Error>) -> Void) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

final class MockDataLoader: DataLoader {
    override func downloadData(source: URL) throws -> Data {
        let path = Bundle.main.path(forResource: "testpage", ofType: "json")
        let json = try String(contentsOfFile: path!)
        let data = json.data(using: .utf8)
        return data!
    }

    override func complete(with result: Result<SearchPhotosResultPage, Error>, completion: @escaping (Result<SearchPhotosResultPage, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion(result)
        }
    }
}
