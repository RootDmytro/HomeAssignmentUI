//
//  ContentCellViewModel.swift
//  HomeAssignment
//
//  Created by Dmytro Yaropovetsky on 8/24/23.
//

import Combine
import UIKit.UIImage

class ContentCellViewModel: ObservableObject {

    @Published var thumbnail: UIImage?
    @Published var description: String = ""
    @Published var isLoading: Bool = false

    private let photo: PhotoResult
    private let imageDownloader: ImageDownloader

    init(photo: PhotoResult, imageDownloader: ImageDownloader) {
        self.photo = photo
        self.imageDownloader = imageDownloader
    }

    func loadIfNeeded() {
        description = photo.description ?? photo.alt_description ?? ""

        guard !isLoading && thumbnail == nil else { return }
        guard let source = photo.urls.thumb, let sourceURL = URL(string: source) else { return }

        isLoading = true
        imageDownloader.startDownload(from: sourceURL, completion: { [weak self] (result: Result<UIImage, Error>) in
            self?.isLoading = false

            if case .success(let image) = result {
                self?.thumbnail = image
            }
        })
    }
}

final class MockContentCellViewModel: ContentCellViewModel {
    init(imageDownloader: ImageDownloader, thumbnail: UIImage, description: String, isLoading: Bool = false) {
        super.init(photo: PhotoResult(id: "", width: 0, height: 0, description: nil, alt_description: nil,
                                      urls: PhotoURLsResult(raw: nil, full: nil, regular: nil, small: nil, thumb: nil, small_s3: nil),
                                      user: UserResult(id: "", username: "", name: "", bio: "", profile_image: ProfileImageResult(small: "", medium: "", large: ""))),
                   imageDownloader: imageDownloader)
        self.thumbnail = thumbnail
        self.description = description
        self.isLoading = isLoading
    }
}
