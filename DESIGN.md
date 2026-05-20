# Daily Log MVP Design

## 1. Product Summary

Daily Log is a camera-roll-first daily vlog app for iPhone.

Users keep shooting with the native Camera and Photos apps. Later, they choose a date, select photos, videos, and Live Photos from that day, add short per-clip notes, make lightweight timeline edits, and export one vertical daily recap video.

The app is intentionally not a full CapCut-level editor. The MVP is a daily log generator with a simple timeline-first trimming experience.

**Core promise:** turn one day of iPhone media into a timestamped daily vlog without changing how the user shoots.

---

## 2. Current MVP Status

The current app supports the full basic flow:

- Choose Today, Yesterday, or a custom date.
- Request Photos permission and fetch assets from the selected day.
- Browse assets in a 3-column picker with All / Photos / Videos filters.
- Select photos, videos, and Live Photos.
- Preserve picker selection when navigating forward and back.
- Long-press picker items for a floating popout preview.
- Auto-sort selected media by capture time.
- Review selected clips in a Timeline list.
- Add a different note for every selected clip.
- Reorder and delete timeline clips through SwiftUI list editing.
- Open a lightweight editor.
- Preview the active clip.
- Play through the multi-clip timeline.
- Select and reorder clips in the editor's mini strip.
- Trim videos and Live Photo video clips with yellow handles.
- Adjust photo display duration with the same trim-style handles.
- Toggle each Live Photo between Live video and Photo mode.
- Default Live Photos to Live video mode.
- Choose a project-wide timestamp font.
- Export one 9:16 video at 1080 x 1920, 30 fps.
- Burn timestamp + per-clip note into the exported video.
- Save the exported video to Photos.
- Preserve original audio from video clips and Live Photo paired videos where available.
- Clean Daily Log temporary export files and old Live Photo paired-video cache files.

---

## 3. Product Goals

### Primary Goal

Make it fast to create a daily vlog from existing camera roll media.

### User Value

- No need to record inside a separate app.
- No need to manually sort media by time.
- No need to learn a full editor.
- Every clip can show when it happened.
- Every clip can add a short note such as "lunch", "receipt", or "trail".
- Live Photos can become motion clips instead of static photos.
- Mixed portrait and landscape media can be exported into one vertical daily video.

### Design Principle

The editor should feel conceptually closer to a simple CapCut-style timeline than a slideshow builder, but it must remain small, direct, and daily-log-focused.

---

## 4. Target Users

**Primary users**

- People casually documenting daily life.
- Students recording school, food, friends, trips, and routines.
- Travelers, hikers, runners, and weekend explorers.
- Users who want clips for Instagram Reels, TikTok, YouTube Shorts, or personal memory keeping.

**Persona**

Eric is an international student in Seattle. He already records daily life with the iPhone Camera. He wants to choose media after the fact, add small notes, and export a clean daily memory video quickly.

---

## 5. Current User Flow

1. Open the app.
2. Choose Today, Yesterday, or a custom date.
3. Grant Photos permission if needed.
4. Browse the selected day in the media grid.
5. Filter by All, Photos, or Videos.
6. Optionally long-press an item to preview it.
7. Select individual assets or Select All.
8. Tap Next.
9. Review selected clips in Timeline.
10. Type optional notes per clip.
11. Reorder or delete clips if needed.
12. Tap Edit.
13. Preview clips in the editor.
14. Trim or adjust duration with the yellow handles.
15. Toggle Live Photos between Live and Photo mode when needed.
16. Choose timestamp font if desired.
17. Tap Export.
18. Confirm the exported video was saved to Photos.

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

- Opening a new date resets previous media selection through `MediaSelectionViewModel.resetSelection()`.
- Photo permission status is checked on appear.

### 6.2 Media Grid

Purpose: select source assets from the chosen day.

Current UI:

- Navigation title reflects the selected date.
- Filter segmented control: All / Photos / Videos.
- Item count.
- Select All / Clear All.
- 3-column thumbnail grid.
- Bottom Next bar when at least one asset is selected.
- Floating quick preview overlay when long-pressing a thumbnail.

Cell metadata:

- Thumbnail shown aspect-fit on a black background.
- Capture time badge.
- Video duration badge.
- Orientation badge for landscape vs portrait.
- Selection checkmark.

Behavior:

- Tap toggles selection.
- Long press opens the quick preview without changing selection.
- Preview background tap dismisses the preview.
- Video and Live Photo preview uses `AVPlayer`.
- Preview audio starts enabled for video/Live Photo popouts.
- Selection is backed by stable PhotoKit asset ids.
- Returning from Timeline keeps the selected items selected.
- Reloading Photos data reapplies selection state.

### 6.3 Timeline

Purpose: review selected clips before editing.

Current UI:

- Sorted list of selected clips.
- Thumbnail.
- Capture time.
- Type icon and duration.
- Per-clip note text field on the right.
- Bottom summary with clip count and total duration.
- Edit button.
- Navigation bar Edit button for list editing.

Behavior:

- Items are initially sorted by `creationDate`, then `modificationDate`.
- Each clip owns its own timestamp note.
- Notes are passed into the editor and export.
- The Timeline list supports delete and move.

### 6.4 Editor

Purpose: lightweight timeline-first preview, trim, and export.

Current UI:

- Top bar with Cancel, centered Editor title, and one blue Export button.
- Large preview surface.
- Timestamp preview badge in the upper-left area, matching export placement by proportional coordinate mapping.
- Play/pause button.
- Current clip time badge.
- Total duration badge.
- Timestamp font menu.
- Live/Photo segmented control for Live Photos.
- Horizontal thumbnail strip for the selected clip.
- Yellow trim handles with a fixed blue playhead.
- Mini clip selector strip for switching and reordering clips.

Editor scope:

- Supports basic clip selection.
- Supports per-clip trim/duration via draggable yellow handles.
- Supports Live Photo mode switching.
- Supports timestamp font choice.
- Supports export to Photos.
- Does not include transitions, advanced zooming, multi-track editing, filters, stickers, music selection, or advanced color controls.

---

## 7. Media Types

### Photo

- Defaults to a 2 second display duration.
- Supported duration range is 1 to 8 seconds.
- Timeline handles adjust the photo display duration.
- Export renders the still image into video frames.
- Still images are aspect-fit into the 9:16 output with black background when needed.
- Timestamp and note are drawn directly into still-generated frames.

### Video

- Defaults to up to 5 seconds.
- Minimum trim duration is 1 second.
- Uses the original video track inserted into an `AVMutableComposition`.
- Original audio track is inserted when available.
- Preferred transform is normalized for correct orientation.
- Landscape video is aspect-fit and centered inside the 9:16 canvas.

### Live Photo

- Defaults to Live video mode.
- Uses the paired Live Photo video resource when in Live mode.
- Can be switched to Photo mode in the editor.
- In Live mode, paired-video audio is inserted when available.
- On editor load, the app asynchronously resolves the paired-video duration and updates fallback timing when needed.
- Paired Live Photo video resources are cached temporarily under the app's temp directory and stale cache files are cleaned.

---

## 8. Timestamp and Notes

### Timestamp Source

Each clip uses:

1. `PHAsset.creationDate`
2. `PHAsset.modificationDate`
3. `Unknown time` fallback in Timeline display

### Overlay Content

The exported video burns a timestamp badge into each clip.

Examples:

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
- Timestamp font is project-wide.
- Current font choices: System, Rounded, Serif, Mono.
- Overlay position is upper-left, offset slightly downward from the top edge.
- Overlay style is white text on a translucent black rounded background.

Implementation:

- Mixed video/photo export uses `AVVideoCompositionCoreAnimationTool` for video composition overlays.
- Still-only export draws timestamp and note directly into each rendered frame.
- Editor preview mirrors the active clip's timestamp + note position using proportional export coordinates.

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

Derived behavior:

- `captureTime` resolves from asset creation/modification date.
- `durationString` displays the effective clip duration.
- `usesVideoPlayback` is true for videos and Live Photos in `.video` mode.
- `effectiveDuration` is the trim range for video playback and display duration for photos.

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
- Photos use a current `UIImage` preview and timer-driven playback.
- Playback advances across clips.
- When the timeline ends, playback stops and the active clip returns to its start.
- User can seek inside the selected clip by dragging the selected clip's thumbnail strip.
- The manager removes `NotificationCenter` and periodic time observers in `deinit`.

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
11. Removing Daily Log temporary export files after save.

### Photo Export

- Photos are rendered into video frames.
- Black background is used for letterboxing.
- Timestamp + per-clip note is drawn into frames.
- Still-only export writes one video directly using `AVAssetWriter`.
- Mixed photo/video export creates temporary still-video segments, inserts them into the composition, then deletes those intermediate files.

### Video Export

- Uses source video tracks through composition insertion.
- Preserves source audio tracks where available.
- Uses source preferred transforms to normalize orientation and center-fit media.
- Re-encodes because timestamps and composition transforms require rendering.

### Color Strategy

Daily Log currently exports to SDR Rec.709 for consistency across mixed sources.

Implementation details:

- `AVMutableVideoComposition` sets Rec.709 color primaries, transfer function, and YCbCr matrix.
- Still-video `AVAssetWriter` settings include Rec.709 video color properties.
- Still frame rendering uses an ITU-R 709 color space when creating pixel buffers.
- `UIGraphicsImageRendererFormat` uses standard dynamic range.

Rationale:

- Daily logs often mix iPhone videos, Live Photos, regular photos, screen recordings, and downloaded videos.
- One exported video needs a single reliable target color space.
- SDR Rec.709 is the safest MVP target for Photos, social apps, and typical playback.

Known constraint:

- HDR brightness is not preserved as HDR.
- Some third-party or downloaded files with unusual metadata can still differ slightly after AVFoundation re-encode.

---

## 11. Temporary File Management

Daily Log creates temporary files for:

- Exported MP4/MOV outputs before saving to Photos.
- Still-image video segments during mixed photo/video export.
- Live Photo paired-video resources copied from PhotoKit.

Cleanup behavior:

- The exported temp file is removed after it is saved to Photos.
- Intermediate still-video files are removed after composition export.
- On app launch, `VideoExportService.cleanupStaleTemporaryFiles()` removes old `daily-log-*.mov/mp4` temp files.
- On app launch, `PhotoLibraryService.cleanupStaleLivePhotoVideoCache()` removes stale Live Photo paired-video cache files.
- Cleanup is scoped to Daily Log-owned filenames/directories, not arbitrary temp files.

---

## 12. Permissions and Privacy

### Permissions

- Read/write Photos authorization is requested for browsing and selecting media.
- Add-only Photos authorization is requested before saving exported video.

### Privacy Principles

- No login.
- No cloud upload.
- No server-side processing.
- No analytics on library content.
- User chooses the assets used in the timeline.
- Exported videos are saved only when the user taps Export.
- The app creates new Photos assets for exports; it does not delete original Photos assets.

---

## 13. Current Data Models

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

- `timestamp.note`
- `watermark`
- `audio`
- `transcript`
- `presentation`

---

## 14. Technical Architecture

### Platform

- iOS app
- Swift
- SwiftUI
- Observation framework
- PhotoKit
- AVFoundation
- UIKit/CoreGraphics for still-frame rendering
- `AVPlayerLayer` bridge for video preview

### Key Modules

| Module | Responsibility |
| --- | --- |
| `daily_log_iosApp` | App entry point and startup temp cleanup |
| `ContentView` | Navigation root |
| `HomeView` | Date entry point |
| `MediaGridView` | Grid browsing, filtering, selection, long-press popout preview |
| `MediaSelectionViewModel` | Photos permission state, loaded assets, stable selected ids |
| `TimelineView` | Sorted clip list, list editing, per-clip note input |
| `TimelineViewModel` | Timeline item creation, ordering, total duration |
| `EditorView` | Preview, trim controls, Live/Photo toggle, timestamp font, export action |
| `VideoPlayerManager` | Multi-clip playback and seek state |
| `VideoPlayerLayerView` | `AVPlayerLayer` bridge |
| `ClipThumbnailStrip` | Thumbnail strip for selected clip |
| `DualHandleRangeSlider` | Two-handle trim and duration UI |
| `PhotoLibraryService` | PhotoKit auth, asset fetch, thumbnails, previews, AVAsset loading, Live Photo video cache |
| `VideoExportService` | AVFoundation composition, color-managed export, save, temp cleanup |

### Legacy / Reserved Components

- `EditorViewModel` and `EditorToolTray` still exist but are not central to the current simplified editor surface.
- `ClipTrimView` exists as an alternate trim view but the active editor uses the inline playback timeline/slider.

---

## 15. Non-Goals for MVP

The MVP intentionally does not include:

- Built-in camera.
- Accounts or login.
- Cloud sync.
- AI selection.
- Music library.
- Transitions.
- Multi-track editing.
- Advanced zoom timeline.
- Advanced color grading controls.
- Stickers, effects, or templates.
- Social posting integration.
- Background export.

---

## 16. Usability Decisions

### Keep Editing Lightweight

The editor only exposes controls needed for a daily vlog:

- Select clip.
- Play.
- Trim.
- Toggle Live/Photo.
- Choose timestamp font.
- See total duration.
- Export.

### Put Notes Before Editor

Per-clip notes live in Timeline, not deep inside the editor. This matches the moment where users are reviewing the story of the day.

### Live Photos Default to Motion

Live Photos default to Live video mode because the product is a video log generator. Users can still choose Photo mode per Live Photo.

### Preserve Selection When Going Back

Selection persistence is required for a natural Next/Back flow. The app stores selected asset ids separately from loaded asset structs so a grid reload does not clear selection.

### Use Popout Preview in Picker

Long-press preview helps users inspect media before selecting it, especially when thumbnails do not make orientation or content clear.

### Use SDR Rec.709 Export

Mixed media sources cannot reliably preserve each source's full color pipeline in one simple MVP export. The app targets SDR Rec.709 for predictable daily-log output.

---

## 17. Error Handling

| Scenario | Current / Intended Behavior |
| --- | --- |
| Permission denied | Show permission denied view |
| No media for date | Show empty state |
| iCloud media not local | Allow PhotoKit network access |
| Missing video AVAsset | Skip unavailable clip during export |
| Missing Live Photo paired video | Fall back to unavailable video behavior or Photo mode if user chooses it |
| Export failed | Show export alert with localized error |
| Save failed | Show save error in export alert |
| Temp cleanup failure | Ignore cleanup error and continue app flow |

---

## 18. MVP Quality Bar

The MVP is considered usable when:

- A user can create a video from a chosen date without instructions.
- Selection survives a Next/Back navigation loop.
- Long-press picker preview works for photos, videos, and Live Photos.
- Live Photos default to motion.
- Per-clip notes appear in the exported timestamp badge.
- Timestamp preview position matches exported position closely.
- Mixed portrait/landscape media remains visible and correctly oriented.
- Original audio is preserved for video clips where available.
- Export saves successfully to Photos.
- Daily Log temp files do not accumulate indefinitely.

---

## 19. Known Gaps

- No export progress percentage yet.
- No draft persistence across app launches.
- No manual timestamp position controls.
- No manual timestamp size controls.
- No per-clip timestamp font controls; font is project-wide.
- No ability to manually edit capture time.
- No background music.
- No mute/volume controls in editor.
- No share sheet after save.
- No automated UI tests yet.
- Some third-party or downloaded videos may still have color differences after AVFoundation re-encode.
- Quick preview animation approximates native iOS popout behavior but is not a private/system-level Photos clone.

---

## 20. Next Recommended Milestones

### Milestone A — Stabilize MVP

- Add export progress.
- Add better export error recovery.
- Add draft persistence for selected clips and notes.
- Add UI tests for selection persistence and Timeline notes.
- Add device regression checks for Live Photo audio and picker popout audio.

### Milestone B — Timestamp Polish

- Choose timestamp position.
- Choose timestamp date/time format.
- Adjust text size.
- Support no-background text style.
- Add safe-area-aware timestamp positioning presets.

### Milestone C — Audio Controls

- Mute original audio per clip.
- Global original-audio volume.
- Optional simple background audio import.
- Decide how picker popout audio should interact with editor audio session.

### Milestone D — Export Confidence

- Broaden color handling tests.
- Add orientation regression tests.
- Test with iPhone-shot media, Live Photos, screen recordings, Setlog/downloaded videos, HDR clips, and iCloud-only assets.

---

## 21. Distribution Notes

Current project settings include:

- Bundle identifier: `com.ericpeng.daily-log-ios`
- Development team: `ZS44GFNXQU`
- iOS deployment target: `18.5`
- App icon configured through `DailyLogAppIcon.png`
- Development export options plist for local development export

For broad testing, use TestFlight. For public installation, use App Store distribution. Ad Hoc `.ipa` distribution only works for registered devices.

---

## 22. Differentiation

| Product | Focus | Daily Log Difference |
| --- | --- | --- |
| Setlog | In-app capture and social daily vlog workflow | Daily Log uses existing camera roll media and does not require re-shooting |
| iPhone Photos Memories | Automatic memories with limited control | Daily Log lets users choose date, clips, order, trim, and notes |
| CapCut / iMovie | Full editing suite | Daily Log keeps only the timeline controls needed for a daily recap |

---

## 23. One-Sentence Pitch

Daily Log turns one day of iPhone photos, videos, and Live Photos into a timestamped daily vlog with per-clip notes.
