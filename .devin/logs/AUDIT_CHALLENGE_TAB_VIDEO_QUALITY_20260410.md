# Challenge Tab Video Quality Audit Report
**Date**: 2026-04-10  
**Scope**: Challenge tab video playback quality, framing, aspect ratio, and user experience  
**Objective**: Identify root causes of video quality degradation, incorrect framing, and aspect ratio issues when displaying videos from TikTok or other sources

---

## Executive Summary

**Severity: HIGH**

The audit identified **5 critical issues** and **3 secondary issues** contributing to video quality degradation, incorrect framing, and aspect ratio problems in the Challenge tab:

1. **CRITICAL**: No explicit vertical video (9:16) handling - default 16/9 aspect ratio fallback causes distortion
2. **CRITICAL**: BoxFit.cover crops vertical video content when displayed in portrait mode
3. **CRITICAL**: Watermark service DISABLED - FFmpegKit commented out, no watermark processing
4. **HIGH**: Adaptive quality service selects suboptimal renditions for vertical videos
5. **HIGH**: No resolution preservation for vertical formats during upload

**Secondary Issues**:
- Aspect ratio derived from controller without validation for vertical formats
- No explicit vertical video transcoding profiles in Supabase
- Fallback playback bypasses transcoding entirely

---

## 1. Video Pipeline Overview

### 1.1 Upload Pipeline

**File**: `lib/features/student/student_challenge_video_editor_screen.dart`

**Process**:
1. Video captured or selected from gallery
2. `_compressAndSetVideo()` called:
   - Uses `VideoCompress.compressVideo()` with:
     - `VideoQuality.Res1920x1080Quality` if `_hdUpload` true
     - `VideoQuality.MediumQuality` otherwise
   - No explicit vertical video handling
3. `WatermarkService.addWatermark()` called:
   - **DISABLED** - FFmpegKit calls commented out (lines 50-106)
   - Returns original video unchanged
4. Upload via `VideoAssetUploadService.ingestVideoFromBytes()`:
   - Creates video_asset record
   - Uploads to Supabase Storage
   - Registers source with metadata

**Issue**: No vertical video detection or preservation. Compression uses generic quality presets that may not preserve 9:16 aspect ratio.

### 1.2 Storage & Transcoding

**Schema**: `.devin/sql_changes/change_20251213_videoasset_schema.sql`

**Tables**:
- `app.video_assets` - stores width, height, rotation, duration_ms
- `app.video_renditions` - stores renditions with width, height, bitrate_kbps, fps, codec
- `app.video_sources` - original upload metadata
- `app.video_processing_jobs` - transcoding jobs

**RPC**: `app_videoasset_get_playback_manifest`
- Prefers HLS over MP4
- Orders renditions by width DESC (not optimized for vertical)
- Returns all ready renditions with metadata

**Issue**: No vertical-specific transcoding profiles. Width-based ordering may select suboptimal rendition for 9:16 videos.

### 1.3 Playback Selection

**File**: `lib/services/adaptive_quality_service.dart`

**Process**:
1. `selectBestUrlFromVideo()` called per video
2. Priority order based on quality:
   - High: `mp4_main`, `1080p`, `720p`, `mp4_480p`, `480p`
   - Medium: `mp4_480p`, `480p`, `mp4_main`, `720p`
   - Low: `mp4_240p`, `240p`, `mp4_360p`
3. Falls back to `video_url` if no renditions

**Issue**: No vertical-aware selection. 1080p on a vertical video could be 1080x1920, but the code assumes landscape dimensions.

### 1.4 Display & Rendering

**File**: `lib/video/academia_playback_view.dart`

**Flutter (web/iOS)**:
```dart
content = FittedBox(
  fit: widget.fit,  // BoxFit.cover by default
  clipBehavior: Clip.hardEdge,
  child: SizedBox(
    width: 1,
    height: 1 / aspectRatio,  // aspectRatio from controller
    child: VideoPlayer(controller),
  ),
);
```

**Android Native**:
```kotlin
playerView.resizeMode = when (resizeMode) {
    "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
    // ...
}
```

**Aspect Ratio Detection**:
```dart
final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN 
    ? (16 / 9)  // DEFAULT FOR INVALID
    : v.aspectRatio;
```

**Issue**: Default 16/9 fallback for invalid aspect ratios. BoxFit.cover crops vertical videos to fill portrait bounds.

---

## 2. Critical Issues

### 2.1 No Vertical Video Handling (CRITICAL)

**Location**: Multiple files

**Evidence**:
- No 9:16, 1080x1920, or 720x1280 detection anywhere in codebase
- Default aspect ratio fallback is 16/9 (`academia_playback_view.dart:487`)
- No vertical-specific compression presets
- No vertical-aware rendition selection

**Impact**: Vertical videos from TikTok (typically 1080x1920) are treated as landscape, causing:
- Incorrect aspect ratio calculation
- Cropping when displayed
- Potential quality loss from transcoding

**Recommendation**:
1. Add vertical video detection based on width < height
2. Preserve vertical aspect ratio through pipeline
3. Add vertical-specific compression profiles
4. Update rendition selection to prioritize height for vertical videos

### 2.2 BoxFit.cover Crops Vertical Content (CRITICAL)

**Location**: `lib/video/academia_playback_view.dart:398-503`

**Evidence**:
```dart
// Line 57: Default fit
this.fit = BoxFit.cover,

// Line 398-404: Android mapping
final resizeMode = widget.fit == BoxFit.cover
    ? 'cover'  // Maps to RESIZE_MODE_ZOOM
    : ...

// Line 503: Flutter FittedBox
content = FittedBox(
  fit: widget.fit,  // BoxFit.cover
  ...
);
```

**Impact**: BoxFit.cover scales video to fill bounds while maintaining aspect ratio, cropping overflow. For vertical videos in portrait mode:
- If video is 9:16 and display is 9:16: OK
- If video is 16:9 and display is 9:16: Top/bottom cropped
- If video is 9:16 and display is 16:9: Left/right cropped

**Recommendation**:
1. Detect video orientation before setting BoxFit
2. Use BoxFit.contain for vertical videos in portrait mode
3. Add user-selectable scaling modes (fit, fill, cover)

### 2.3 Watermark Service Disabled (CRITICAL)

**Location**: `lib/games/services/watermark_service.dart:50-108`

**Evidence**:
```dart
// Line 50-61: FFprobe DISABLED
// DISABLED for release white-screen test
// final session = await FFprobeKit.getMediaInformation(videoPath);
// ...

// Line 89-107: FFmpeg DISABLED
// DISABLED for release white-screen test
// final session = await FFmpegKit.executeWithArguments(args);
// ...

// Line 107: Returns null
debugPrint('[Watermark] DISABLED — FFmpegKit not available');
return null;
```

**Impact**: 
- No watermark is burned into videos
- No video processing (transcoding, re-encoding) occurs
- Original video uploaded unchanged (may not be optimized for mobile)

**Recommendation**:
1. Re-enable FFmpegKit after debugging white-screen issue
2. Add proper error handling instead of disabling
3. Test watermark on vertical videos specifically

### 2.4 Suboptimal Rendition Selection (HIGH)

**Location**: `lib/services/adaptive_quality_service.dart:57-90`

**Evidence**:
```dart
case VideoQuality.high:
  keys = ['mp4_main', '1080p', '720p', 'mp4_480p', '480p', 'legacy_primary'];
```

**Issue**: Assumes landscape naming (1080p = 1920x1080). For vertical videos:
- 1080p could be 1080x1920 (portrait)
- 720p could be 720x1280 (portrait)
- Code doesn't distinguish

**Impact**: May select wrong rendition for vertical videos, serving suboptimal quality or dimensions.

**Recommendation**:
1. Detect video orientation before selecting rendition
2. For vertical videos, prioritize height over width
3. Add vertical-specific rendition keys (e.g., `1080x1920`, `720x1280`)

### 2.5 No Vertical Resolution Preservation (HIGH)

**Location**: `lib/features/student/student_challenge_video_editor_screen.dart:507-512`

**Evidence**:
```dart
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: _hdUpload ? VideoQuality.Res1920x1080Quality : VideoQuality.MediumQuality,
  deleteOrigin: false,
  includeAudio: true,
);
```

**Issue**: `VideoQuality.Res1920x1080Quality` and `MediumQuality` are landscape presets. No vertical equivalent (e.g., `Res1080x1920Quality`).

**Impact**: Vertical videos may be resized to landscape dimensions during compression, losing aspect ratio.

**Recommendation**:
1. Detect source video orientation
2. Use appropriate quality preset based on orientation
3. Preserve original resolution for vertical videos

---

## 3. Secondary Issues

### 3.1 Aspect Ratio Validation

**Location**: `lib/video/academia_playback_view.dart:487`

**Evidence**:
```dart
final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN 
    ? (16 / 9)  // Default fallback
    : v.aspectRatio;
```

**Issue**: Default 16/9 fallback is inappropriate for vertical videos. Should detect orientation first.

**Recommendation**: Default to 9/16 if width < height, else 16/9.

### 3.2 No Vertical Transcoding Profiles

**Location**: Supabase schema (no evidence of vertical profiles)

**Issue**: `video_renditions` table has width/height columns but no vertical-specific transcoding logic in processing jobs.

**Recommendation**: Add vertical transcoding profiles (e.g., 1080x1920, 720x1280) to video processing pipeline.

### 3.3 Fallback Bypasses Transcoding

**Location**: `lib/providers/student_challenges_provider.dart:842-856`

**Evidence**:
```dart
Map<String, dynamic> _buildFallbackPlayback(String directUrl) {
  return {
    'video_asset_id': null,
    'playback': {
      'best_url': directUrl,
      'renditions': [
        {'label': 'original', 'url': directUrl},
      ],
    },
  };
}
```

**Issue**: If RPCs fail, fallback uses direct URL with single 'original' rendition, bypassing all transcoding and optimization.

**Recommendation**: Add client-side transcoding fallback or better error handling to avoid bypass.

---

## 4. Feed Performance Analysis

### 4.1 Preloading & Caching

**Location**: `lib/features/student/tabs/student_challenges_tab.dart:1189-1203`

**Implementation**:
- PageView with `viewportFraction: 0.9999` forces pre-build of adjacent pages
- `_preloadAdjacentVideos()` preloads N+1, N+2, N+3 URLs
- `VideoCacheService` caches manifests and URLs (in-memory LRU)
- ExoPlayer disk cache: 200MB (Android)

**Assessment**: GOOD - Preloading strategy is sound. No issues with feed performance contributing to quality problems.

### 4.2 Memory Management

**Location**: `lib/features/student/tabs/student_challenges_tab.dart:1172-1183`

**Implementation**:
- Keeps controllers for N-3 to N+3 range
- Disposes controllers outside range
- Lifecycle-aware pausing on background

**Assessment**: GOOD - Memory management is appropriate. No memory leaks contributing to quality issues.

---

## 5. Files Involved

### Flutter Code
1. `lib/features/student/tabs/student_challenges_tab.dart` - Feed UI and video item rendering
2. `lib/video/academia_playback_view.dart` - Core video playback widget
3. `lib/video/academia_playback_engine.dart` - Playback wrapper
4. `lib/providers/student_challenges_provider.dart` - Video metadata and upload
5. `lib/features/student/student_challenge_video_editor_screen.dart` - Video upload and compression
6. `lib/services/adaptive_quality_service.dart` - Quality selection logic
7. `lib/services/video_cache_service.dart` - URL caching
8. `lib/services/video_analytics_service.dart` - Analytics (not quality-related)
9. `lib/games/services/watermark_service.dart` - Watermark (DISABLED)

### Android Native
10. `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt` - ExoPlayer integration

### Supabase Schema
11. `.devin/sql_changes/change_20251213_videoasset_schema.sql` - Video asset schema
12. `supabase/migrations/20260223150001_add_videoasset_get_playback_manifest.sql` - Playback manifest RPC

---

## 6. Recommendations Summary

### Immediate (Critical)
1. **Re-enable watermark service** after debugging FFmpegKit white-screen issue
2. **Add vertical video detection** in upload pipeline
3. **Change BoxFit to contain** for vertical videos in portrait mode
4. **Fix aspect ratio default** to 9/16 for vertical videos

### Short-term (High Priority)
5. Add vertical-specific compression presets
6. Update rendition selection to be orientation-aware
7. Add vertical transcoding profiles in Supabase
8. Improve fallback to avoid bypassing transcoding

### Long-term (Medium Priority)
9. Add user-selectable scaling modes (fit/cover/fill)
10. Implement vertical video validation during upload
11. Add vertical video analytics to track issues
12. Consider separate vertical video storage bucket

---

## 7. Testing Recommendations

To validate fixes, test with:
1. TikTok-exported videos (1080x1920, 720x1280)
2. Camera-captured vertical videos
3. Horizontal videos displayed in portrait mode
4. Various network conditions (WiFi, 4G, 3G)
5. Different device screen sizes and aspect ratios

Measure:
- Displayed aspect ratio vs source aspect ratio
- Visible cropping (if any)
- Perceived quality vs source quality
- Load times and buffering

---

## 8. Conclusion

The root causes of video quality and framing issues in the Challenge tab are:

1. **Primary**: Lack of vertical video (9:16) handling throughout the pipeline
2. **Primary**: BoxFit.cover cropping vertical content
3. **Primary**: Disabled watermark/transcoding service
4. **Secondary**: Suboptimal rendition selection for vertical formats
5. **Secondary**: No vertical resolution preservation during upload

The feed performance and memory management are sound and not contributing to quality issues. The problems are isolated to video processing, transcoding, and display logic.

**Estimated effort to fix**: 2-3 days for critical issues, 1 week for complete resolution including testing.
