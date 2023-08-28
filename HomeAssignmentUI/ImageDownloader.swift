//
//  ImageDownloader.swift
//  HomeAssignment
//
//  Created by Dmytro Yaropovetsky on 8/24/23.
//

import SwiftUI
import Combine

class ImageDownloader {
    static let cacheLimit = 100
    var imageCache: [URL: UIImage] = [:]
    var ramCacheItemsOrder: [URL] = []
    var imageFileCache: [URL: URL] = [:]
    var isFileStorageAllowed = false
    var fileCacheLock = DispatchQueue(label: "CacheLockingQueue")

    init() {
        let cachesDirectory = getCachesDirectory()
        do {
            try FileManager.default.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
            isFileStorageAllowed = true
        } catch {
            print("Failed to create directory with error: \(error)")
            isFileStorageAllowed = false
        }
    }

    func getCachesDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    func download(from source: URL?) -> AnyPublisher<UIImage, Error> {
        Future { promise in
            self.startDownload(from: source, completion: promise)
        }
        .eraseToAnyPublisher()
    }

    func startDownload(from source: URL?, completion: @escaping (_ result: Result<UIImage, Error>) -> Void) {
        DispatchQueue.global().async {
            guard let source = source else {
                self.complete(with: .failure(NSError(domain: NSURLErrorDomain,
                                                     code: NSURLErrorCannotDecodeContentData,
                                                     userInfo: [NSLocalizedDescriptionKey: "Source is nil"])), completion: completion)
                return
            }

            if let image = self.loadFromCache(source: source) {
                self.complete(with: .success(image), completion: completion)
                return
            }

            var data: Data
            do {
                data = try self.downloadData(source: source)
            } catch {
                print("Could not get contents of a file, error: \(error.localizedDescription)")
                self.complete(with: .failure(error), completion: completion)
                return
            }

            if let image = UIImage(data: data) {
                self.complete(with: .success(image), completion: completion)
                self.addToCache(source: source, image: image)
            } else {
                self.complete(with: .failure(NSError(domain: NSURLErrorDomain,
                                                     code: NSURLErrorCannotDecodeContentData,
                                                     userInfo: [
                                                         NSLocalizedDescriptionKey: "Could not decode image data",
                                                         "url": source,
                                                         "data": data
                                                     ])),
                              completion: completion)
            }
        }
    }

    // MARK: - Cache

    open func loadFromCache(source: URL) -> UIImage? {
        if let ramCacheImage = loadFromRAMCache(source: source) {
            return ramCacheImage
        }
        return loadFromFileCache(source: source)
    }

    private func loadFromRAMCache(source: URL) -> UIImage? {
        if let ramCacheImage = imageCache[source] {
            return ramCacheImage
        }
        return nil
    }

    private func loadFromFileCache(source: URL) -> UIImage? {
        if isFileStorageAllowed, let fileURL = imageFileCache[source] {
            var image: UIImage?
            do {
                let data = try Data(contentsOf: fileURL, options: .alwaysMapped)
                image = UIImage(data: data)
                if let image = image {
                    refreshInRAMCache(source: source, image: image)
                }
            } catch {
                print("Could not read contents from a file, error: \(error)")
            }
            return image
        }
        return nil
    }

    private func addToCache(source: URL, image: UIImage) {
        refreshInRAMCache(source: source, image: image)
        addToFileCache(source: source, image: image)
    }

    private func refreshInRAMCache(source: URL, image: UIImage) {
        if imageCache[source] != nil {
            imageCache.removeValue(forKey: source)
            ramCacheItemsOrder.removeAll { $0 == source }
        }

        if imageCache.count >= Self.cacheLimit, let oldestKey = ramCacheItemsOrder.first {
            imageCache.removeValue(forKey: oldestKey)
            ramCacheItemsOrder.removeFirst()
        }

        imageCache[source] = image
        ramCacheItemsOrder.append(source)
    }

    private func addToFileCache(source: URL, image: UIImage) {
        if let data = image.pngData() {
            let fileURL = getCachesDirectory().appending(component: UUID().uuidString).appendingPathExtension("png")

            do {
                try data.write(to: fileURL)
            } catch {
                print("Could not write contents to a file, error: \(error)")
            }

//            fileCacheLock.sync {
                self.imageFileCache[source] = fileURL
//            }
        }
    }

    // MARK: - Download

    open func downloadData(source: URL) throws -> Data {
        do {
            return try Data(contentsOf: source)
        } catch {
            throw error
        }
    }

    open func complete(with result: Result<UIImage, Error>, completion: @escaping (Result<UIImage, Error>) -> Void) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

final class MockImageDownloader: ImageDownloader {
    override func loadFromCache(source: URL) -> UIImage? {
        let image: UIImage
        if source.absoluteString.contains("profile") {
            image = UIImage(named: "profile-1557251674406-effb9d313841")!
        } else {
            image = UIImage(named: "photo-1564419320461-6870880221ad")!
        }
        return image
    }

    override func complete(with result: Result<UIImage, Error>, completion: @escaping (Result<UIImage, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1..<1.5)) {
            completion(result)
        }
    }
}
