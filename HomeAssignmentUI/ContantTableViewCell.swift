//
//  ContantTableViewCell.swift
//  HomeAssignmentUI
//
//  Created by Dmytro Yaropovetsky on 8/25/23.
//

import Combine
import UIKit

final class ContantTableViewCell: UITableViewCell {
    @IBOutlet var leftImageView: UIImageView!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var mainActivityIndicator: UIActivityIndicatorView!
    @IBOutlet var imageActivityIndicator: UIActivityIndicatorView!

    var viewModel: ContentCellViewModel? {
        didSet {
            bind(to: viewModel)
        }
    }
    private var cancellables: [AnyCancellable] = []

    private func bind(to viewModel: ContentCellViewModel?) {
        guard let viewModel = viewModel else {
            mainActivityIndicator.startAnimating()
            return
        }
        mainActivityIndicator.stopAnimating()

        cancellables = []
        viewModel.$thumbnail
            .sink { [weak self] image in
                self?.leftImageView.image = image
            }
            .store(in: &cancellables)
        viewModel.$description
            .sink { [weak self] text in
                self?.descriptionLabel.text = text
            }
            .store(in: &cancellables)
        viewModel.$isLoading
            .removeDuplicates()
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.imageActivityIndicator.startAnimating()
                } else {
                    self?.imageActivityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        mainActivityIndicator.startAnimating()

        leftImageView.layer.masksToBounds = true
        leftImageView.layer.borderWidth = 1
        leftImageView.layer.borderColor = UIColor.opaqueSeparator.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        leftImageView.layer.cornerRadius = leftImageView.frame.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        leftImageView.image = nil
        descriptionLabel.text = nil
    }
}
