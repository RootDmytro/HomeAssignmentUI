//
//  DetailsViewModel.swift
//  HomeAssignment
//
//  Created by Dmytro Yaropovetsky on 8/24/23.
//

import SwiftUI
import Combine

final class DetailsViewModel: ObservableObject {
    @Published var mainImage: UIImage = UIImage()
    @Published var mainImageExpectedSize: CGSize?
    @Published var description: String = ""
    @Published var userProfilePicture: UIImage = UIImage()
    @Published var userFullName: String = ""
    @Published var username: String = ""
    @Published var userBio: String = ""
    @Published var isLoading: Bool = false

    private let photo: PhotoResult
    private var cancellables: [AnyCancellable] = []

    init(photo: PhotoResult, imageDownloader: ImageDownloader) {
        self.photo = photo

        mainImageExpectedSize = CGSize(width: photo.width, height: photo.height)

        if let urlString = photo.urls.thumb,
           let sourceURL = URL(string: urlString),
           let cachedImage = imageDownloader.loadFromCache(source: sourceURL) {
            mainImage = cachedImage
        }

        if let urlString = photo.urls.full {
            let sourceURL = URL(string: urlString)
            isLoading = true
            imageDownloader.startDownload(from: sourceURL) { [weak self] result in
                if case .success(let image) = result {
                    self?.mainImage = image
                }
                self?.isLoading = false
            }
        }

        description = photo.description ?? photo.alt_description ?? ""

        let sourceURL = URL(string: photo.user.profile_image.medium)
        imageDownloader.startDownload(from: sourceURL) { [weak self] result in
            if case .success(let image) = result {
                self?.userProfilePicture = image
            }
        }

        userFullName = photo.user.name
        username = photo.user.username
        userBio = photo.user.bio ?? ""
    }

}
