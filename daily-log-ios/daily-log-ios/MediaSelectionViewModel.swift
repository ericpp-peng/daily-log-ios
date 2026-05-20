//
//  MediaSelectionViewModel.swift
//  daily-log-ios
//

import Observation
import SwiftUI

enum MediaFilter {
    case all, photos, videos
}

@MainActor
@Observable
final class MediaSelectionViewModel {
    var assets: [MediaAsset] = []
    var authorizationStatus: PhotoAuthorizationStatus = .notDetermined
    var isLoading = false
    var filter: MediaFilter = .all

    private let service = PhotoLibraryService.shared
    private var selectedAssetIDs: Set<String> = []

    var filteredAssets: [MediaAsset] {
        switch filter {
        case .all:    return assets
        case .photos: return assets.filter { $0.type == .image || $0.type == .livePhoto }
        case .videos: return assets.filter { $0.type == .video }
        }
    }

    var selectedCount: Int {
        assets.filter { $0.isSelected }.count
    }

    var selectedAssets: [MediaAsset] {
        assets.filter { $0.isSelected }.sorted { $0.sortDate < $1.sortDate }
    }

    func checkPermission() {
        authorizationStatus = service.currentAuthorizationStatus()
    }

    func requestPermission() async {
        authorizationStatus = await service.requestAuthorization()
    }

    func loadAssets(for date: Date) async {
        isLoading = true
        let selectedAssetIDs = selectedAssetIDs
        let fetchedAssets = await Task.detached(priority: .userInitiated) { [self] in
            service.fetchAssets(for: date)
        }.value

        let loadedIDs = Set(fetchedAssets.map(\.id))
        self.selectedAssetIDs.formIntersection(loadedIDs)
        assets = fetchedAssets.map { asset in
            var asset = asset
            asset.isSelected = selectedAssetIDs.contains(asset.id)
            return asset
        }
        isLoading = false
    }

    func toggleSelection(for id: String) {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }
        assets[index].isSelected.toggle()
        if assets[index].isSelected {
            selectedAssetIDs.insert(id)
        } else {
            selectedAssetIDs.remove(id)
        }
    }

    func selectAll() {
        for index in assets.indices {
            assets[index].isSelected = true
            selectedAssetIDs.insert(assets[index].id)
        }
    }

    func clearAll() {
        for index in assets.indices {
            assets[index].isSelected = false
        }
        selectedAssetIDs.removeAll()
    }

    func resetSelection() {
        assets = []
        selectedAssetIDs.removeAll()
    }
}
