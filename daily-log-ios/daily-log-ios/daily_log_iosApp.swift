//
//  daily_log_iosApp.swift
//  daily-log-ios
//
//  Created by eric on 5/10/26.
//

import SwiftUI

@main
struct daily_log_iosApp: App {
    init() {
        VideoExportService.shared.cleanupStaleTemporaryFiles()
        PhotoLibraryService.shared.cleanupStaleLivePhotoVideoCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
