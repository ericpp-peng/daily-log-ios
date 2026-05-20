# Daily Log — MVP Design Document

## 1. Product Summary

Daily Log is a camera-roll-first daily vlog app.

Users keep using the native iPhone Camera and Photos app as usual. Later, they choose a date, select photos, videos, and Live Photos from that day, add short per-clip notes, make light timeline edits, and export a vertical daily recap video.

The MVP is intentionally not a full video editor. It is a simple daily log generator with a timeline-first trimming experience.

**Core promise:** turn one day of iPhone media into a timestamped daily vlog without changing how you shoot.

---

## 2. Current MVP Status

The app is now a working MVP with these end-to-end capabilities:

- Choose Today, Yesterday, or a custom date.
- Request Photos permission and fetch assets for the selected date.
- Show a media grid with All / Photos / Videos filters.
- Select photos, videos, and Live Photos.
- Preserve selection when navigating forward to Timeline and back to the picker.
- Auto-sort selected media by capture time.
- Show a Timeline list with thumbnails, time, duration, and per-clip note input.
- Open a lightweight editor with preview, play/pause, clip selection, Live/Photo mode for Live Photos, and trim handles.
- Export a single 9:16 video.
- Save the exported video to Photos.
- Burn a timestamp overlay into the export.
- Add a different note after the timestamp for every clip.
- Preserve original audio from videos and Live Photo paired videos where available.

---

## 3. Product Goals

### Primary Goal

Make it fast to create a daily vlog from existing camera roll media.

### User Value

- No need to shoot inside a special app.
- No need to manually sort media by time.
- No need to learn a complex editor.
- Each exported clip can show when it happened and what it was.
- Live Photos can become motion clips instead of static photos.

### Design Principle

The app should feel closer to a simple CapCut-style timeline than a slideshow builder, but it must stay lightweight and daily-log-focused.

---

## 4. Target Users

**Primary users**

- People who casually document daily life.
- International students recording school, food, friends, trips, and routines.
- Travelers, hikers, and weekend explorers.
- Users who want content for Instagram Reels, TikTok, YouTube Shorts, or personal memory keeping.

**Persona**

Eric is an international student in Seattle. He already records daily life with the iPhone Camera. He wants to choose media after the fact, add small notes like "lunch", "trail", or "receipt", and export a clean daily memory video quickly.

---

## 5. Current User Flow

1. Open app.
2. Choose Today, Yesterday, or a custom date.
3. Grant Photos permission if needed.
4. Browse the selected day in a 3-column media grid.
5. Filter by All, Photos, or Videos.
6. Select individual assets or Select All.
7. Tap Next.
8. Review selected clips in Timeline.
9. Type optional notes per clip.
10. Tap Edit.
11. Preview clips in the editor.
12. Trim the selected clip using the yellow timeline handles.
13. Toggle Live Photo between Live video and Photo when needed.
14. Choose timestamp font.
15. Export.
16. Save the video to Photos.

---

## 6. Screens

### 6.1 Home

Purpose: choose the day to turn into a log.

Current UI:

- App title and tagline.
- Today card.
- Yesterday card.
- Choose a Date button with graphical DatePicker sheet.

Behavior:

- Opening a new date resets the previous media selection.
- Photo permission status is checked on appear.

### 6.2 Media Grid

Purpose: select source assets from the chosen day.

Current UI:

- Navigation title is the selected date.
- Filter segmented control: All / Photos / Videos.
- Item count.
- Select All / Clear All.
- 3-column thumbnail grid.
- Bottom Next bar when at least one asset is selected.

Cell metadata:

- Thumbnail shown with aspect-fit content on black background.
- Capture time badge.
- Video duration badge.
- Orientation badge for landscape vs portrait.
- Selection checkmark.

Behavior:

- Selection is backed by stable PhotoKit asset ids.
- Returning from Timeline keeps the selected items selected.
- Reloading Photos data reapplies selection state.

### 6.3 Timeline

Purpose: review the selected clips before editing.

Current UI:

- Sorted list of selected clips.
- Thumbnail.
- Capture time.
- Type icon and duration.
- Per-clip note text field on the right.
- Bottom summary with clip count and total duration.
- Edit button.

Behavior:

- Items are sorted by `creationDate`, then `modificationDate`.
- Each clip owns its own timestamp note.
- Notes are passed into the editor and export.
- The Timeline list supports delete and move through SwiftUI list editing.

### 6.4 Editor

Purpose: lightweight timeline-first edit and export.

Current UI:

- Top bar with Cancel, share/export, and confirm/export buttons.
- Large preview surface.
- Play/pause button.
- Time badge for current selected clip.
- Total duration badge.
- Timestamp font menu.
- Live/Photo segmented control for Live Photos.
- Horizontal thumbnail strip for the selected clip.
- Yellow trim handles with fixed blue playhead.
- Mini clip selector strip for switching and reordering clips.

Editor scope:

- Supports basic clip selection.
- Supports per-clip trim/duration via draggable yellow handles.
- Supports Live Photo mode switch.
- Supports timestamp font choice.
- Does not include advanced trimming, zooming, transitions, multi-track editing, filters, or music controls.

---

## 7. Media Types

### Photo

- Defaults to a 2 second display duration.
- Timeline trim handles adjust the photo display window/duration.
- Export renders the still image into video frames.
- Still-image export preserves orientation by drawing through UIKit before writing to a pixel buffer.
- Images are aspect-fit into the 9:16 output with black background when needed.

### Video

- Defaults to up to 5 seconds.
- Uses original video track with trim range.
- Original audio is inserted when available.
- Preferred transform is normalized for correct orientation and centered fit.
- Landscape videos are letterboxed/fit so the full frame is visible.

### Live Photo

- Defaults to Live video mode in the editor.
- Uses the paired Live Photo video resource when in Live mode.
- Can be switched to Photo mode.
- In Live mode, original paired-video audio is inserted when available.
- On editor load, the app asynchronously resolves the paired video duration and updates the trim range when it is still using fallback timing.

---

## 8. Timestamp and Notes

### Timestamp Source

Each clip uses:

1. `PHAsset.creationDate`
2. `PHAsset.modificationDate`
3. `Unknown time` fallback in timeline display

### Export Overlay

The exported video burns a timestamp badge into each clip.

Format:

```text
11:46 AM
11:46 AM  receipt
3:20 PM  trail
```

Rules:

- Every clip shows its own capture time.
- Every clip can have its own note.
- Empty notes are ignored.
- Notes appear after the timestamp.
- Timestamp font can be selected in the editor.
- Current font choices: System, Rounded, Serif, Mono.
- Overlay position is bottom-left.
- Overlay style is white text on a translucent black rounded background.

Implementation:

- Mixed video/photo export uses `AVVideoCompositionCoreAnimationTool`.
- Still-only export draws timestamp and note directly into each rendered frame.
- Editor preview mirrors the active clip's timestamp + note.

---

## 9. Timeline and Playback

### Timeline Item Model

Each selected asset becomes a `TimelineItem`.

```swift
struct TimelineItem: Identifiable {
    let id: String
    let asset: MediaAsset
    var orderIndex: Int
    var configuration: ClipEditingConfiguration
}
```

### Per-Clip Configuration

```swift
struct ClipEditingConfiguration: Codable, Equatable {
    var trim: Trim
    var displayDuration: TimeInterval
    var playback: Playback
    var crop: Crop
    var adjusts: Adjusts
    var livePhotoMode: LivePhotoMode
    var timestampNote: String
}
```

Currently active fields:

- `trim`
- `displayDuration`
- `livePhotoMode`
- `timestampNote`

Reserved fields for future editing:

- `playback`
- `crop`
- `adjusts`

### Playback Behavior

- `VideoPlayerManager` owns one `AVPlayer` for video clips.
- Photos use a current `UIImage` preview and timer-driven duration.
- Playback advances across clips.
- Photo playback returns to the start when completed.
- Live/video playback also returns to the start when the full timeline completes.
- User can seek within the selected clip by dragging on the thumbnail strip.

---

## 10. Export Design

### Output

- 9:16 vertical video.
- Render size: `1080 x 1920`.
- Frame rate: 30 fps.
- Preferred output: MP4.
- MOV fallback where needed.
- Saved to Photos.

### Composition

`VideoExportService` is responsible for:

1. Building an `AVMutableComposition`.
2. Adding one video composition track.
3. Adding one audio composition track.
4. Inserting trimmed video/Live Photo segments.
5. Rendering still images into temporary video segments.
6. Creating video composition instructions.
7. Applying transform normalization and aspect-fit placement.
8. Adding timestamp overlay layers.
9. Exporting through `AVAssetExportSession`.
10. Saving via `PHPhotoLibrary`.

### Photo Export

- Photos are rendered into video frames.
- Image orientation is corrected before pixel-buffer writing.
- Black background is used for letterboxing.
- Timestamp + per-clip note is drawn into frames.

### Video Export

- Uses original video samples where possible through composition insertion.
- Preserves source audio tracks where available.
- Applies source video color metadata to the output composition when detected.
- Uses HEVC highest quality preset for HDR-like sources when detected.
- Uses highest-quality export otherwise.

### Known Export Constraints

- Some third-party downloaded videos can have incomplete or unusual color metadata.
- Export may still differ slightly from the original if AVFoundation has to re-encode.
- Current MVP does not expose manual color correction controls.

---

## 11. Permissions and Privacy

### Permissions

- Read access to Photos for browsing and selecting media.
- Add-only Photos access for saving exported video.

### Privacy Principles

- No login.
- No cloud upload.
- No server-side processing.
- No analytics on library content.
- User chooses exactly which assets are used.
- Exported videos are saved only when the user taps export.

---

## 12. Current Data Models

### MediaAsset

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
```

### ProjectEditingConfiguration

```swift
struct ProjectEditingConfiguration: Codable, Equatable {
    var canvas: Canvas
    var timestamp: Timestamp
    var watermark: Watermark?
    var audio: Audio
    var transcript: Transcript
    var presentation: Presentation
}
```

Currently active fields:

- `canvas.preset`
- `timestamp.enabled`
- `timestamp.font`

Reserved fields:

- `watermark`
- `audio`
- `transcript`
- `presentation`

---

## 13. Technical Architecture

### Platform

- iOS app
- Swift
- SwiftUI
- Observation framework
- PhotoKit
- AVFoundation
- UIKit bridges where practical

### Key Modules

| Module | Responsibility |
| --- | --- |
| `HomeView` | Date entry point |
| `MediaGridView` | Grid browsing, filtering, selection |
| `MediaSelectionViewModel` | Photo permission, loaded assets, stable selection ids |
| `TimelineView` | Sorted clip list and per-clip notes |
| `TimelineViewModel` | Timeline item creation, ordering, total duration |
| `EditorView` | Preview, timeline controls, Live/Photo toggle, timestamp font, export actions |
| `VideoPlayerManager` | Multi-clip playback and seek state |
| `VideoPlayerLayerView` | `AVPlayerLayer` bridge |
| `ClipThumbnailStrip` | Thumbnail strip for selected clip |
| `DualHandleRangeSlider` | Two-handle trim UI |
| `PhotoLibraryService` | PhotoKit auth, asset fetch, thumbnails, previews, AVAsset loading |
| `VideoExportService` | AVFoundation composition/export/save |

---

## 14. Non-Goals for MVP

The MVP intentionally does not include:

- Built-in camera.
- Accounts or login.
- Cloud sync.
- AI selection.
- Music library.
- Transitions.
- Multi-track editing.
- Advanced zoom timeline.
- Advanced color grading.
- Stickers, effects, or templates.
- Social posting integration.

---

## 15. Usability Decisions

### Keep Editing Lightweight

The editor should feel conceptually like a timeline editor, but only expose the controls needed for a daily vlog:

- Select clip.
- Play.
- Trim.
- Toggle Live/Photo.
- See total duration.
- Export.

### Put Notes Before Editor

Per-clip notes live in Timeline, not the editor, because users are thinking about the story of the day while reviewing the list. The editor stays focused on preview and trim.

### Live Photos Default to Motion

Live Photos default to Live video mode because the product is a video log generator. Users can still choose Photo mode for any Live Photo.

### Preserve Selection When Going Back

Selection persistence is required for a natural Next/Back flow. The app stores selected asset ids separately from loaded asset structs so a grid reload does not clear selection.

---

## 16. Error Handling

| Scenario | Current / Intended Behavior |
| --- | --- |
| Permission denied | Show permission denied view |
| No media for date | Show empty state |
| iCloud media not local | Allow PhotoKit network access |
| Missing AVAsset | Skip unavailable clip during export |
| Export failed | Show export alert with localized error |
| Save failed | Show save error in export alert |

---

## 17. MVP Quality Bar

The MVP is considered usable when:

- A user can create a video from a chosen date without instructions.
- Selection survives a Next/Back navigation loop.
- Live Photos default to motion.
- Per-clip notes appear in the exported timestamp badge.
- Mixed portrait/landscape media remains visible and correctly oriented.
- Original audio is preserved for video clips where available.
- Export saves successfully to Photos.

---

## 18. Known Gaps

- No export progress percentage yet.
- No draft persistence across app launches.
- No manual timestamp position controls.
- No per-clip timestamp font controls; font is project-wide.
- No ability to manually edit capture time.
- No background music.
- No mute/volume controls.
- No share sheet after save.
- No automated UI tests yet.
- Some third-party or downloaded videos may still have color differences after AVFoundation export.

---

## 19. Next Recommended Milestones

### Milestone A — Stabilize MVP

- Add export progress.
- Add better export error recovery.
- Add draft persistence for selected clips and notes.
- Add basic UI tests for selection persistence and Timeline notes.

### Milestone B — Timestamp Polish

- Choose timestamp position.
- Choose timestamp date/time format.
- Adjust text size.
- Support no-background text style.

### Milestone C — Audio Controls

- Mute original audio per clip.
- Global original-audio volume.
- Optional simple background audio import.

### Milestone D — Export Confidence

- More robust color handling.
- More orientation regression tests.
- Device testing with iPhone-shot media, Live Photos, screen recordings, and downloaded videos.

---

## 20. Differentiation

| Product | Focus | Daily Log Difference |
| --- | --- | --- |
| Setlog | In-app capture and social daily vlog workflow | Daily Log uses existing camera roll media and does not require re-shooting |
| iPhone Photos Memories | Automatic memories with limited control | Daily Log lets users choose the date, clips, order, trim, and notes |
| CapCut / iMovie | Full editing suite | Daily Log keeps only the timeline controls needed for a daily recap |

---

## 21. One-Sentence Pitch

Daily Log turns one day of iPhone photos, videos, and Live Photos into a timestamped daily vlog with per-clip notes.
