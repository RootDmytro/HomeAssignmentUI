//
//  ContentTableViewModel.swift
//  HomeAssignment
//
//  Created by Dmytro Yaropovetsky on 8/24/23.
//

import Foundation
import Combine

class PageItem {
    let index: Int
    var sourceData: SearchPhotosResultPage?
    var rowViewModels: [ContentCellViewModel]

    init(index: Int, sourceData: SearchPhotosResultPage? = nil, rowViewModels: [ContentCellViewModel] = []) {
        self.index = index
        self.sourceData = sourceData
        self.rowViewModels = rowViewModels
    }
}

final class ContentTableViewModel {
    private enum ErrorConstants {
        static let errorDomain = "ContentTableViewModel"
        static let redundantUpdateRequestError = -1
    }

    @Published var term: String?
    @Published var items: [Int: PageItem] = [:]
    @Published var activityIndicatorEnabled: Bool = false
    @Published var expectedNumberOfRows: Int = 0
    var didUpdateIndexes = PassthroughSubject<Range<Int>, Never>()

    private let imageDownloader: ImageDownloader
    private let dataLoader: DataLoader
    
    private var cancellables: [AnyCancellable] = []
    private var pageSize: Int = 10
    private var pagesBeingLoaded = Set<Int>()

    init(imageDownloader: ImageDownloader, dataLoader: DataLoader) {
        self.imageDownloader = imageDownloader
        self.dataLoader = dataLoader
    }

    private func clearData() {
        items = [:]
        expectedNumberOfRows = 0
    }

    // MARK: - Getters

    private func pageIndex(from rowIndex: Int) -> Int {
        rowIndex / pageSize
    }

    private func rowIndexPath(from rowIndex: Int) -> IndexPath {
        IndexPath(row: rowIndex % pageSize, section: pageIndex(from: rowIndex))
    }

    private func rowIndexRange(from pageIndex: Int) -> Range<Int> {
        Range(NSRange(location: pageIndex * pageSize, length: pageSize))!
    }

    func rowModel(for index: Int) -> ContentCellViewModel? {
        let path = rowIndexPath(from: index)
        var row: ContentCellViewModel?
        if path.section < items.count {
            if let page = items[path.section], path.row < page.rowViewModels.count {
                row = page.rowViewModels[path.row]
            }
        }
        return row
    }

    func detailsViewModel(for index: Int) -> DetailsViewModel? {
        let path = rowIndexPath(from: index)
        var detailsViewModel: DetailsViewModel?
        if path.section < items.count {
            if let page = items[path.section], let sourceData = page.sourceData, path.row < sourceData.results.count {
                let rowData = sourceData.results[path.row]
                detailsViewModel = DetailsViewModel(photo: rowData, imageDownloader: imageDownloader)
            }
        }
        return detailsViewModel
    }

    // MARK: - Events

    func didRequestRefresh() {
        if let term = term {
            didRequestSearch(for: term)
        }
    }

    func didRequestSearch(for term: String) {
        clearData()
        activityIndicatorEnabled = true
        self.term = term
        loadPage(at: 0) { [weak self] result in
            self?.activityIndicatorEnabled = false
        }
    }

    func willRequesRow(at rowIndex: Int) {
        let pageIndex = pageIndex(from: rowIndex)
        ensurePageItemIsLoaded(at: pageIndex)
        let nextPageIndex = pageIndex + 1
        ensurePageItemIsLoaded(at: nextPageIndex)
    }

    // MARK: - Data Loading

    private func ensurePageItemIsLoaded(at pageIndex: Int) {
        if pageIndex < items.count {
            if items[pageIndex]?.sourceData == nil {
                loadPage(at: pageIndex) { result in
                    if case .success = result {
                        self.didUpdateIndexes.send(self.rowIndexRange(from: pageIndex))
                    }
                }
            }
        } else {
            for index in items.count...pageIndex {
                loadPage(at: index) { result in
                    if case .success = result {
                        self.didUpdateIndexes.send(self.rowIndexRange(from: index))
                    }
                }
            }
        }
    }

    private func loadPage(at pageIndex: Int, completion: ((Result<SearchPhotosResultPage, Error>) -> Void)? = nil) {
        guard let term = term else { return }
        guard !pagesBeingLoaded.contains(pageIndex) else {
            completion?(.failure(NSError(domain: ErrorConstants.errorDomain, code: ErrorConstants.redundantUpdateRequestError)))
            return
        }

        let pageItem = PageItem(index: pageIndex)
        items[pageIndex] = pageItem
        pagesBeingLoaded.insert(pageIndex)

        dataLoader.startRequest(searchTerm: term, page: pageIndex) { [weak self] result in
            guard let self = self else { return }
            self.importPageResult(pageItem: pageItem, result: result)
            self.pagesBeingLoaded.remove(pageIndex)
            completion?(result)
        }
    }

    private func importPageResult(pageItem: PageItem, result: Result<SearchPhotosResultPage, Error>) {
        switch result {
        case .success(let page):
            let viewModels = page.results.map { ContentCellViewModel(photo: $0, imageDownloader: self.imageDownloader) }
            pageItem.sourceData = page
            pageItem.rowViewModels = viewModels

            expectedNumberOfRows = page.total
            if page.total > 0 && page.total_pages > 0 {
                pageSize = Int(ceil(Double(page.total) / Double(page.total_pages)))
            }
        case .failure(_):
            break
        }
    }
}
