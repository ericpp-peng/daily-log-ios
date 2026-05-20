# Daily Log — App Design Document

## 1. Product Overview

**Concept:** A camera roll-based daily log generator.

Users keep shooting with the native iPhone camera as usual. At the end of the day, they open the app, select photos and videos from a chosen date, and the app auto-sorts them by capture time to generate a daily recap video.

> **Core idea:** Rebuild your day from the photos and videos you already captured.

---

## 2. Problem Statement

Apps like Setlog offer a great daily vlog experience but have two key limitations:

1. **Original media stays outside the app.** Users who want to keep full-quality originals have to shoot twice — once in Setlog, once with the native camera. This interrupts the moment.

2. **No post-capture insertion.** If the app only accepts real-time captures, users can't insert photos received from friends or rediscover shots taken earlier in the day. The timeline is incomplete.

---

## 3. Goals

### Main Goal
Let users pick a date, select photos and videos from their camera roll, auto-sort by timestamp, and export a timeline-based daily log video with minimal effort.

### User Value
The app's job is not to help users shoot — it's to help them organize what they already shot.

- Keep using the native iPhone camera as normal
- No need to re-capture for any app
- Freely choose media after the fact
- Auto-sort by real capture time
- Export a shareable daily recap in minutes

---

## 4. Target Users

**Primary:** People who like documenting their lives but don't want to spend time editing video.

- International students recording daily life abroad
- Travelers, hikers, people active on weekends
- Casual shooters who are not video editors
- People who want to share daily content on Instagram Reels, TikTok, YouTube Shorts

**Persona — Eric, international student in Seattle**
Eric shoots campus life, friend hangouts, hiking, food, and travel with his iPhone. He wants a daily record but doesn't want to open a special app every time he shoots. At the end of the day he wants to quickly pick from his camera roll, let the app sort it, and get a clean daily vlog.

---

## 5. Scope

### MVP Includes
1. Date selection (Today, Yesterday, calendar picker)
2. Read photos and videos from iPhone Photos for that date
3. Display media grid with thumbnails
4. Select/deselect assets
5. Auto-sort by capture timestamp
6. Timeline preview (photos + videos in order)
7. Export as a single video
8. Save exported video back to iPhone Photos

### MVP Excludes
- Built-in camera
- Social / sharing features
- Friend collaboration / split-screen
- Cloud sync
- AI auto-selection
- Complex video editor
- Filters, captions, music library
- Login or accounts
- Paid subscription

---

## 6. Core User Flow

### Full Flow
1. Open app
2. See Today / Yesterday / Choose Date
3. Select a date
4. App fetches and sorts that day's media
5. User selects assets to include
6. App builds timeline preview
7. User adjusts order, removes items, sets photo duration
8. Tap Export
9. App generates and saves video to Photos
10. User can share

### MVP Simplified Flow
1. Choose Date
2. Select Photos and Videos
3. Preview Timeline
4. Export Video

---

## 7. Functional Requirements

### 7.1 Photo Library Permission
- Support limited photo access (iOS)
- Show only authorized assets if limited access is granted
- Show a settings redirect screen if permission is denied

**Permission copy:**
> This app uses your photo library only to help you organize your daily log. Your photos and videos stay on your device unless you choose to export or share them.

### 7.2 Date Selection
- Quick access: Today, Yesterday
- Calendar date picker for any past date
- Show photo/video count for selected date

### 7.3 Media Fetching
**Supported types:** Image, Video, Live Photo (treated as image in MVP)

**Sort order:**
1. `creationDate`
2. `modificationDate` (fallback)
3. Place at end of timeline with "Unknown time" label if neither exists

### 7.4 Media Selection
- Grid view with thumbnails
- Each cell shows: capture time, video duration badge (if video), selection checkmark
- Tap to select/deselect
- Show selected count
- Select All / Clear All

### 7.5 Timeline Generation
- Sort selected assets by timestamp
- Photos: default display duration 2 seconds
- Videos: default up to 5 seconds (configurable max)
- User can remove or reorder items

### 7.6 Timeline Preview
- Play photos and videos in timestamp order
- Show capture time overlay (e.g., 10:32 AM)
- Support play / pause / seek

### 7.7 Video Export
- Use AVFoundation to compose the video
- Convert photos to video frame sequences
- Concatenate video clips
- Output format: MP4 or MOV
- Default aspect ratio: 9:16 (vertical)
- Save to iPhone Photos on completion
- Show share sheet after export

### 7.8 Save to Photos
- Requires Photo Library add permission
- Show error if save permission is denied
- Show success confirmation after saving

---

## 8. Non-functional Requirements

### Performance
- Do not block main thread when loading large libraries
- Lazy-load thumbnails
- Show export progress
- Run video export on a background queue

### Privacy
- No photo or video uploads
- All processing on-device
- No login required
- No analytics on library content
- Cloud features (if added later) require a new privacy policy

### Reliability
- Handle deleted or missing assets gracefully
- Handle iCloud media not yet downloaded to device
- Handle unsupported video formats
- Provide retry on export failure

### Usability
- No video editing knowledge required
- Main flow in 3–5 steps
- Good defaults — minimal parameter tuning
- Tone: simple, warm, everyday feel

---

## 9. UX Screens

### Home Screen
- App name + tagline: *Turn your day into a short memory log.*
- Today card
- Yesterday card
- Choose a Date button
- (Future) Recent logs section

### Media Grid Screen
- Date title
- Total item count
- Grid view with thumbnails
- Filter: All / Photos / Videos
- Select All button
- Next button (enabled when ≥1 item selected)
- Each cell: thumbnail, time, video duration badge, selection checkmark

### Timeline Screen
- Preview player
- Horizontal timeline strip
- Capture time per item
- Remove button per item
- Drag to reorder
- Export button

### Export Settings Screen (MVP can skip detailed settings)
- Aspect ratio: 9:16
- Photo duration: 2 seconds
- Max video clip duration: 5 seconds (optional)
- Include timestamps: on/off
- Export button

### Completion Screen
- "Video saved to Photos" confirmation
- Share button
- View in Photos
- Create another log

---

## 10. Data Models

```swift
enum MediaType {
    case image
    case video
    case livePhoto
    case unknown
}

struct MediaAsset: Identifiable {
    let id: String
    let type: MediaType
    let creationDate: Date?
    let modificationDate: Date?
    let duration: TimeInterval?
    let localIdentifier: String
    var isSelected: Bool
    let phAsset: PHAsset

    var sortDate: Date {
        creationDate ?? modificationDate ?? Date.distantFuture
    }
}

struct TimelineItem: Identifiable {
    let id: String
    let asset: MediaAsset
    var orderIndex: Int
    var configuration: ClipEditingConfiguration   // per-clip edit state

    var effectiveDuration: TimeInterval { /* trim/rate for video, displayDuration for photo */ }
}

// Per-clip resumable edit state — mirrors VideoEditorKit's
// `VideoEditingConfiguration`, scoped to one timeline clip.
struct ClipEditingConfiguration: Codable, Equatable {
    var trim: Trim                  // lowerBound / upperBound in source seconds (video)
    var displayDuration: TimeInterval   // used for photos
    var playback: Playback          // rate
    var crop: Crop                  // rotation / mirror / freeformRect
    var adjusts: Adjusts            // brightness / contrast / saturation
}

// Project-wide resumable edit state — output settings shared across clips.
struct ProjectEditingConfiguration: Codable, Equatable {
    var canvas: Canvas              // aspect-ratio preset
    var watermark: Watermark?       // export-only image overlay
    var audio: Audio                // single recorded overdub + track selection
    var transcript: Transcript      // caption generation feature state
    var presentation: Presentation  // active tool, social destination, guides
}

struct DailyLogProject {
    let id: UUID
    let date: Date
    var items: [TimelineItem]
    var project: ProjectEditingConfiguration
    var createdAt: Date
    var updatedAt: Date
}
```

---

## 11. Technical Design

**Platform:** iOS 18.5+
**Stack:** Swift, SwiftUI, Observation framework (`@Observable`), PhotoKit, AVFoundation, JSON for drafts (Core Data files remain unused)

**Architecture:** MVVM. Editor follows VideoEditorKit's pattern: shell view → loaded view → tool tray, with `@Observable @MainActor` view models, separate player manager, and resumable `ClipEditingConfiguration` / `ProjectEditingConfiguration` snapshots.

> **Note (Phase 0, 2026-05-19):** Daily Log is in the middle of porting VideoEditorKit's editor architecture in-tree. The MVP "we are not an editor" framing in §20 is being relaxed to support trim, speed, crop, adjusts, audio overdub, transcripts, and watermarks as project goals. The DESIGN doc will be updated phase by phase as the port lands.

### Modules
| Module | Responsibility |
|--------|---------------|
| `PhotoLibraryService` | Auth, asset fetching, thumbnails, iCloud download |
| `MediaSelectionViewModel` | Selection state, filtering (`@Observable`) |
| `TimelineViewModel` | Timeline ordering, duration assignment, project configuration (`@Observable`) |
| `ClipEditingConfiguration` | Per-clip resumable edit state — trim/speed/crop/adjusts |
| `ProjectEditingConfiguration` | Project-wide edit state — canvas/watermark/audio/transcript |
| `VideoPlayerManager` | Multi-clip preview playback. Owns one `AVPlayer` for video clips, holds current `UIImage` for photo clips; advances clip-to-clip; exposes play/pause/seek/scrub state (`@Observable`) |
| `VideoPlayerLayerView` | `UIViewRepresentable` host for `AVPlayerLayer`. Daily Log is an app target (unlike VideoEditorKit's portable package) so a tiny UIKit bridge is the pragmatic way to render frames without AVKit's native controls |
| `EditorViewModel` | Ephemeral editor presentation state — selected tool, save confirmation visibility (`@Observable`). Persisted presentation lives in `ProjectEditingConfiguration.Presentation` |
| `EditorToolTray` | Horizontal tool selector (cut / speed / canvas / adjust / audio / captions) plus selected-tool panel. Cut panel ships in Phase 3a; other panels are placeholders |
| `DualHandleRangeSlider` | Generic two-handle range slider, modeled on VideoEditorKit's `RangedSliderView`. Each handle tracks its own drag-start value for stable multi-touch; minimum-distance enforced symmetrically |
| `ClipThumbnailStrip` | N-thumbnail strip for one asset. Videos: extracts evenly-spaced frames via `AVAssetImageGenerator`. Photos: stretches preview image |
| `ClipTrimView` | Cut/trim tool panel. Videos: thumbnail strip + dual-handle range slider bound to `ClipEditingConfiguration.trim`. Photos: single thumbnail + duration slider bound to `ClipEditingConfiguration.displayDuration` |
| `VideoExportService` | AVFoundation composition, export, save to Photos |
| `ProjectStorageService` | Draft persistence (Phase 6) |

### PhotoLibraryService Interface
```swift
protocol PhotoLibraryServiceProtocol {
    func requestAuthorization() async -> PhotoAuthorizationStatus
    func fetchAssets(for date: Date) async -> [MediaAsset]
    func requestThumbnail(for asset: MediaAsset, targetSize: CGSize) async -> UIImage?
    func requestVideoURL(for asset: MediaAsset) async throws -> URL
    func requestImage(for asset: MediaAsset) async throws -> UIImage
}
```

### Timeline Sort Logic
```swift
func sortAssetsByTime(_ assets: [MediaAsset]) -> [MediaAsset] {
    assets.sorted {
        ($0.creationDate ?? $0.modificationDate ?? .distantFuture) <
        ($1.creationDate ?? $1.modificationDate ?? .distantFuture)
    }
}
```

### VideoExportService Responsibilities
1. Create `AVMutableComposition`
2. Render each photo into a video segment
3. Insert and trim video clips
4. Apply 9:16 aspect ratio layout (aspect fill for portrait, letterbox/blur for landscape)
5. Export asynchronously with progress reporting
6. Save result to Photos

---

## 12. Timestamp Handling

### Date Range Query
```swift
let startOfDay = calendar.startOfDay(for: selectedDate)
let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
// predicate: creationDate >= startOfDay AND creationDate < endOfDay
```

### Timezone
MVP uses `PHAsset.creationDate` as-is (matches what users see in the Photos app). Location-aware grouping is a future feature.

### Missing Timestamp
- Place asset at end of timeline
- Label as "Unknown time"
- Allow manual reordering

---

## 13. Video Composition Rules

### Default Output
- 9:16 vertical
- Black or blurred background for non-vertical media
- Photos: 2 seconds each
- Videos: up to 5 seconds (trimmed if longer)
- Simple cuts (no transitions in MVP)
- Optional timestamp overlay

### Photo Handling
- Render `UIImage` into video frames for `photoDuration`
- Apply aspect fill or fit
- Preserve image quality

### Video Handling
- Load `AVAsset`
- Trim to `maxVideoDuration` if needed
- Insert into composition preserving original audio
- Handle rotation transform
- Scale/crop to output size

### Audio
- Keep original video audio
- No background music in MVP
- Future: add music track, volume mixing, mute option

---

## 14. Permissions and Privacy

### Required
- `NSPhotoLibraryUsageDescription` — read access
- `NSPhotoLibraryAddUsageDescription` — save exported video

### Privacy Principles
- No account required
- No cloud upload in MVP
- On-device processing only
- User controls what is exported

---

## 15. Error Handling

| Scenario | Message | Action |
|----------|---------|--------|
| No permission | "Photo access is required to create your daily log." | Open Settings |
| No media on date | "No photos or videos found for this date." | Choose another date |
| iCloud not downloaded | "Some media needs to be downloaded from iCloud." | Attempt download, allow skip |
| Export failed | "Export failed. Please try again or remove unsupported media." | Retry |

---

## 16. MVP Milestones

| Milestone | Goals | Deliverable |
|-----------|-------|-------------|
| **1** | Photo permission, fetch by date, thumbnail grid | Date picker + media grid screen |
| **2** | Select/deselect assets, sort by timestamp, timeline list | Sorted timeline preview |
| **3** | Preview player (photos + videos), timestamp overlay, play/pause | Working daily log preview |
| **4** | AVFoundation export, 9:16 output, save to Photos | Complete exportable MVP |
| **5** | UI polish, export progress, error handling, draft saving | TestFlight-ready build |

---

## 17. Future Features

- **Smart Selection** — on-device suggestions based on favorites, motion, faces, location diversity
- **Templates** — minimal timeline, travel vlog, campus day, food diary, hiking recap
- **Music** — background track, beat-sync transitions
- **Social Export** — direct share to Instagram Reels, TikTok, Stories
- **Friend Collaboration** — merge timelines from multiple people by timestamp
- **Map View** — show day route using location metadata, group by place

---

## 18. Success Metrics

**MVP**
- Time from app open to first exported video
- Export completion rate
- Average selected assets per log
- Export success rate

**UX**
- User feels time is saved vs. manual editing
- User does not feel forced to change shooting habits
- User completes flow without instructions

**Retention**
- Users create more than one log
- Users return after trips or events
- Repeat exports over multiple weeks

---

## 19. Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Video composition complexity (mixed formats, orientations) | Start with simple 9:16 + fixed durations + cuts only |
| Photo permission friction | Support limited access, clear privacy copy, on-device only |
| Too many assets in one day | Filters, time-based grouping, future smart suggestions |
| Feels like a generic slideshow app | Emphasize timestamp-based daily structure, time overlays, day narrative feel |

---

## 20. Differentiation

| Competitor | Their focus | Our difference |
|------------|-------------|----------------|
| **Setlog** | Real-time capture + social | We work with existing camera roll, no re-shooting required |
| **iPhone Photos Memories** | Automatic, low control | We give full control over date, assets, and order |
| **CapCut / iMovie** | Full video editing | We are not an editor — we are a daily log generator with minimum effort |

---

## 21. Open Questions

1. Should videos play full length or be trimmed to a max duration?
2. Should photos default to 1.5s, 2s, or 3s?
3. Should the first version show timestamp overlays on the video?
4. Should draft projects be saved locally between sessions?
5. Should users be able to manually insert media from a different date?
6. Should users be able to edit the displayed timestamp?
7. Should the output feel like a slideshow, a timeline, or a vlog?
8. Should Live Photos play as short videos in a future version?
9. Should the first version support only 9:16 or also 1:1 and 16:9?
10. Should background music be included in the first public release?

---

## 22. MVP Decision Summary

The first version should be extremely focused:

| Excluded | Included |
|----------|----------|
| Camera | Date selection |
| Social features | Media selection from camera roll |
| Login / accounts | Auto-sort by timestamp |
| Cloud sync | Timeline preview |
| AI features | Export 9:16 vertical video |

**The one question MVP must answer:**
> Can a user turn one day of iPhone photos and videos into a clean daily log video in less than three minutes?

---

## 23. One-sentence Pitch

A simple iPhone app that turns your camera roll into a timestamp-based daily vlog.
