//
//  DetailsViewController.swift
//  HomeAssignmentUI
//
//  Created by Dmytro Yaropovetsky on 8/25/23.
//

import Combine
import UIKit

final class DetailsViewController: UIViewController {
    @IBOutlet var mainImage: UIImageView!
    @IBOutlet var mainImageAspectRatio: NSLayoutConstraint!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var userProfileImage: UIImageView!
    @IBOutlet var fullNameLabel: UILabel!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var userBioLabel: UILabel!
    @IBOutlet var imageActivityIndicator: UIActivityIndicatorView!

    var viewModel: DetailsViewModel! {
        didSet {
            bind(to: viewModel)
        }
    }
    private var cancellables: [AnyCancellable] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        mainImage.image = nil
        userProfileImage.image = nil

        bind(to: viewModel)
    }

    private func bind(to viewModel: DetailsViewModel) {
        guard isViewLoaded else { return }
        cancellables.removeAll()

        viewModel.$mainImage
            .sink { [weak self] image in
                self?.mainImage.image = image
            }
            .store(in: &cancellables)
        viewModel.$mainImageExpectedSize
            .sink { [weak self] size in
                if let size = size {
                    self?.updateImageAspectRatioContraint(with: size)
                }
            }
            .store(in: &cancellables)
        viewModel.$description
            .sink { [weak self] text in
                self?.descriptionLabel.text = text
            }
            .store(in: &cancellables)
        viewModel.$userProfilePicture
            .sink { [weak self] image in
                self?.userProfileImage.image = image
            }
            .store(in: &cancellables)
        viewModel.$userFullName
            .sink { [weak self] text in
                self?.fullNameLabel.text = text
            }
            .store(in: &cancellables)
        viewModel.$username
            .sink { [weak self] text in
                self?.usernameLabel.text = text
            }
            .store(in: &cancellables)
        viewModel.$userBio
            .sink { [weak self] text in
                self?.userBioLabel.text = text
            }
            .store(in: &cancellables)
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.imageActivityIndicator.startAnimating()
                } else {
                    self?.imageActivityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }

    func updateImageAspectRatioContraint(with size: CGSize) {
        let newConstraint = NSLayoutConstraint(item: mainImageAspectRatio.firstItem as Any,
                                               attribute: mainImageAspectRatio.firstAttribute,
                                               relatedBy: mainImageAspectRatio.relation,
                                               toItem: mainImageAspectRatio.secondItem,
                                               attribute: mainImageAspectRatio.secondAttribute,
                                               multiplier: size.width / size.height,
                                               constant: 0)
        newConstraint.priority = mainImageAspectRatio.priority

        mainImageAspectRatio.isActive = false
        mainImageAspectRatio = newConstraint
        newConstraint.isActive = true

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

}
