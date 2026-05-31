//
//  SequentialViewModel.swift
//  ConcurrencyImageGallery
//
//  Created by Youngmin Cho on 5/24/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SequentialViewModel {
    private(set) var images: [LoadedImage] = []
    private(set) var isLoading = false
    private(set) var progress = "0 / 0"
    private(set) var elapsedSeconds: Double = 0
    private(set) var errorMessage: String?

    private let service = ImageService()
    private let limit = 10

    func loadImages() async {
        guard !isLoading else { return }
        isLoading = true
        images = []
        errorMessage = nil
        progress = "0 / \(limit)"
        elapsedSeconds = 0

        let start = Date()
        defer {
            elapsedSeconds = Date().timeIntervalSince(start)
            isLoading = false
        }

        do {
            let list = try await service.fetchImageList(page: 1, limit: limit)
            for (index, item) in list.enumerated() {
                let data = try await service.fetchImageData(from: item.downloadURL)
                images.append(LoadedImage(image: item, data: data))
                progress = "\(index + 1) / \(limit)"
                elapsedSeconds = Date().timeIntervalSince(start)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
