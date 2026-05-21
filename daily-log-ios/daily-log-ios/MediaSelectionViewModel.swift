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
    private var draftTimelineItems: [TimelineItem] = []
    private var draftProject: ProjectEditingConfiguration = .init()

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

    func timelineItemsForSelectedAssets() -> [TimelineItem] {
        let selected = selectedAssets
        let selectedByID = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })

        var items = draftTimelineItems.compactMap { item -> TimelineItem? in
            guard let asset = selectedByID[item.id] else { return nil }
            return TimelineItem(
                id: item.id,
                asset: asset,
                orderIndex: item.orderIndex,
                configuration: item.configuration
            )
        }

        let existingIDs = Set(items.map(\.id))
        let newItems = selected
            .filter { !existingIDs.contains($0.id) }
            .map { asset in
                TimelineItem(
                    id: asset.id,
                    asset: asset,
                    orderIndex: items.count,
                    configuration: TimelineViewModel.makeInitialConfiguration(for: asset)
                )
            }

        items.append(contentsOf: newItems)
        items.sort { lhs, rhs in
            lhs.asset.sortDate < rhs.asset.sortDate
        }
        for index in items.indices {
            items[index].orderIndex = index
        }
        return items
    }

    func timelineProjectForSelectedAssets() -> ProjectEditingConfiguration {
        draftProject
    }

    func saveTimelineDraft(items: [TimelineItem], project: ProjectEditingConfiguration) {
        let selectedIDs = Set(selectedAssets.map(\.id))
        draftTimelineItems = items.filter { selectedIDs.contains($0.id) }
        draftProject = project
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
        let service = service
        let fetchedAssets = await Task.detached(priority: .userInitiated) {
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
