//
//  ContentTableViewController.swift
//  HomeAssignmentUI
//
//  Created by Dmytro Yaropovetsky on 8/25/23.
//

import Combine
import UIKit

final class ContentTableViewController: UITableViewController {

    var viewModel: ContentTableViewModel!
    private var cancellables: [AnyCancellable] = []
    private var preservedRefreshControl: UIRefreshControl?

    override func viewDidLoad() {
        super.viewDidLoad()

        preservedRefreshControl = refreshControl
        refreshControl?.addTarget(self, action: #selector(refreshTableView(_:)), for: .valueChanged)

        viewModel = ContentTableViewModel(imageDownloader: ImageDownloader(), dataLoader: DataLoader())
        viewModel.$expectedNumberOfRows
            .removeDuplicates()
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        viewModel.$activityIndicatorEnabled
            .sink { [weak self] isEnabled in
                guard let self = self, let refreshControl = self.refreshControl else { return }
                if isEnabled {
                    refreshControl.beginRefreshing()
                    self.tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.frame.size.height - self.view.safeAreaInsets.top), animated: true)
                } else {
                    refreshControl.endRefreshing()
                    self.refreshControl = nil
                    self.refreshControl = self.preservedRefreshControl
                }
            }
            .store(in: &cancellables)
        viewModel.didUpdateIndexes
            .sink { [weak self] updatedIndexes in
                let rowIndexes = updatedIndexes.map { IndexPath(row: $0, section: 0) }
                self?.tableView.reloadRows(at: rowIndexes, with: .automatic)
            }
            .store(in: &cancellables)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let selectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedRow, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.expectedNumberOfRows
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        if let cell = cell as? ContantTableViewCell {
            viewModel.willRequesRow(at: indexPath.row)
            let rowModel = viewModel.rowModel(for: indexPath.row)
            cell.viewModel = rowModel
            rowModel?.loadIfNeeded()
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row >= 0 else { return }
        pushDetailsScreen(for: indexPath.row)
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if viewModel.rowModel(for: indexPath.row) != nil {
            return indexPath
        } else {
            return nil
        }
    }

    // MARK: - Actions

    @objc func refreshTableView(_ sender: UIRefreshControl) {
        viewModel.didRequestRefresh()
    }

    // MARK: - Navigation

    private func pushDetailsScreen(for rowIndex: Int) {
        guard let detailsViewModel = viewModel.detailsViewModel(for: rowIndex) else { return }
        guard let viewController = storyboard?.instantiateViewController(withIdentifier: "DetailsViewController") as? DetailsViewController else { return }

        viewController.viewModel = detailsViewModel

        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension ContentTableViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text else { return }

        if !text.isEmpty {
            print("Search: " + (searchBar.text ?? "nil"))
            viewModel.didRequestSearch(for: searchBar.text ?? "")
        }

        view.endEditing(false)
    }
}
