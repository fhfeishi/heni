# Queue Locate And Audio Export Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the current track immediately locatable in the playback-queue dialog and completely remove the player audio-export feature.

**Architecture:** Keep the existing queue dialog in `player_screen.dart`, adding a small testable query-resolution helper plus a row anchor and `Scrollable.ensureVisible` for real scrolling. Remove audio export from the Flutter player, application controller, media-editor services, and extraction-specific tests while retaining FFmpeg inspection and generic job-running code.

**Tech Stack:** Flutter 3.41, Dart 3.11, Riverpod 3, Windows runner, `media_kit`, Flutter widget/unit tests.

## Global Constraints

- Do not interrupt or reopen the current media while locating its queue row.
- Opening the queue should center the current track once when no search is active.
- The locate action must remain visible whenever the queue dialog is open.
- Remove FLAC/Opus export entry points, dialogs, progress UI, controller, and unused extraction services.
- Keep FLAC and Opus as supported playback input formats.
- Keep FFprobe media inspection and generic FFmpeg job-running support.
- Preserve all unrelated user changes in the dirty worktree.

---

### Task 1: Testable Current-Track Query Resolution

**Files:**
- Create: `lib/features/player/presentation/playback_queue_location.dart`
- Create: `test/features/player/presentation/playback_queue_location_test.dart`

**Interfaces:**
- Consumes: `List<MediaItem>`, current queue index, and the dialog search query.
- Produces: `String queryForLocatingCurrentTrack({required List<MediaItem> items, required int currentIndex, required String query})`, returning the query that should remain before scrolling.

- [ ] **Step 1: Write the failing unit tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/domain/media/media_item.dart';
import 'package:heni/domain/media/media_kind.dart';
import 'package:heni/features/player/presentation/playback_queue_location.dart';

void main() {
  const items = [
    MediaItem(path: r'D:\music\alpha.mp3', title: 'Alpha', kind: MediaKind.audio),
    MediaItem(path: r'D:\music\beta.flac', title: 'Beta', kind: MediaKind.audio),
  ];

  test('clears a query that hides the current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: 1,
        query: 'alpha',
      ),
      isEmpty,
    );
  });

  test('keeps a query that already includes the current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: 1,
        query: 'beta',
      ),
      'beta',
    );
  });

  test('keeps the query when there is no valid current track', () {
    expect(
      queryForLocatingCurrentTrack(
        items: items,
        currentIndex: -1,
        query: 'alpha',
      ),
      'alpha',
    );
  });
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
flutter test test/features/player/presentation/playback_queue_location_test.dart
```

Expected: FAIL because `playback_queue_location.dart` and
`queryForLocatingCurrentTrack` do not exist.

- [ ] **Step 3: Implement the minimal helper**

```dart
import '../../../domain/media/media_item.dart';

String queryForLocatingCurrentTrack({
  required List<MediaItem> items,
  required int currentIndex,
  required String query,
}) {
  if (currentIndex < 0 || currentIndex >= items.length) {
    return query;
  }
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  final current = items[currentIndex];
  final matches =
      current.title.toLowerCase().contains(normalized) ||
      current.path.toLowerCase().contains(normalized);
  return matches ? query : '';
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
flutter test test/features/player/presentation/playback_queue_location_test.dart
```

Expected: PASS. If the host Flutter tester still cannot connect to its
`localhost` control port, record that environmental failure and validate the
helper with a temporary `dart run` assertion script before deleting the script.

- [ ] **Step 5: Commit the helper and test**

```powershell
git add lib/features/player/presentation/playback_queue_location.dart test/features/player/presentation/playback_queue_location_test.dart
git commit -m "test: define playback queue locate behavior"
```

### Task 2: Add Queue Auto-Locate And Visible Locate Action

**Files:**
- Modify: `lib/features/player/presentation/player_screen.dart:1-24`
- Modify: `lib/features/player/presentation/player_screen.dart:7885-8010`

**Interfaces:**
- Consumes: `queryForLocatingCurrentTrack`, `PlaybackQueueState.currentIndex`,
  and the current row `BuildContext`.
- Produces: `_locateCurrentTrack({bool clearBlockingQuery = true})` and a
  toolbar locate button.

- [ ] **Step 1: Import the helper**

```dart
import 'playback_queue_location.dart';
```

- [ ] **Step 2: Add dialog state used for scrolling**

Add to `_PlaybackQueueDialogState`:

```dart
final _searchController = TextEditingController();
final _listController = ScrollController();
final _currentRowKey = GlobalKey();
var _query = '';
var _scheduledInitialLocate = false;
```

Dispose `_listController` together with `_searchController`.

- [ ] **Step 3: Add the locate method**

```dart
void _locateCurrentTrack(
  PlaybackQueueState queue, {
  bool clearBlockingQuery = true,
}) {
  if (queue.currentIndex < 0 ||
      queue.currentIndex >= queue.playbackQueue.items.length) {
    return;
  }

  final nextQuery = queryForLocatingCurrentTrack(
    items: queue.playbackQueue.items,
    currentIndex: queue.currentIndex,
    query: _query,
  );
  if (clearBlockingQuery && nextQuery != _query) {
    setState(() {
      _query = nextQuery;
      _searchController.text = nextQuery;
    });
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final rowContext = _currentRowKey.currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  });
}
```

- [ ] **Step 4: Schedule one initial locate**

Inside `build`, after reading `queue`, schedule only once:

```dart
if (!_scheduledInitialLocate && queue.currentItem != null && _query.isEmpty) {
  _scheduledInitialLocate = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _locateCurrentTrack(queue, clearBlockingQuery: false);
  });
}
```

- [ ] **Step 5: Add the always-visible toolbar button**

Place beside the search field:

```dart
IconButton(
  tooltip: '定位当前歌曲',
  onPressed:
      queue.currentItem == null ? null : () => _locateCurrentTrack(queue),
  icon: const Icon(Icons.my_location_rounded),
),
```

Keep the search field in `Expanded` so the button never pushes the dialog wider.

- [ ] **Step 6: Anchor and control the list**

Pass `controller: _listController` to `ListView.separated`. Wrap the current row
with:

```dart
KeyedSubtree(
  key: isCurrent ? _currentRowKey : ValueKey(item.path),
  child: _PlaybackQueueRow(
    item: item,
    index: index,
    isCurrent: isCurrent,
    onPlay: () {
      Navigator.of(context).pop();
      unawaited(
        ref
            .read(playbackQueueControllerProvider.notifier)
            .playQueueIndex(actualIndex),
      );
    },
    onRemove: () {
      unawaited(
        ref
            .read(playbackQueueControllerProvider.notifier)
            .removePlaybackQueueItemAt(actualIndex),
      );
    },
  ),
)
```

- [ ] **Step 7: Run analysis**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Commit queue location**

```powershell
git add lib/features/player/presentation/player_screen.dart
git commit -m "feat: locate the current queue track"
```

### Task 3: Remove Player Audio Export

**Files:**
- Delete: `lib/features/player/application/audio_export_controller.dart`
- Delete: `lib/services/ffmpeg/media_editor.dart`
- Delete: `lib/services/ffmpeg/media_editor_provider.dart`
- Delete: `test/services/ffmpeg/media_editor_test.dart`
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `lib/services/ffmpeg/ffmpeg_command_builder.dart`
- Modify: `test/services/ffmpeg/ffmpeg_command_builder_test.dart`
- Modify: `test/services/ffmpeg/ffmpeg_job_runner_test.dart`

**Interfaces:**
- Consumes: existing playback, queue, media-probe, and volume interfaces.
- Produces: a bottom utility group containing queue, playback mode, and volume
  only.

- [ ] **Step 1: Remove extraction-specific command tests**

Delete the Opus extraction test from
`test/services/ffmpeg/ffmpeg_command_builder_test.dart` and the extraction
builder assertion from `test/services/ffmpeg/ffmpeg_job_runner_test.dart`.
Retain trim-command and process-runner coverage.

- [ ] **Step 2: Remove extraction command types and builder**

Delete from `ffmpeg_command_builder.dart`:

```dart
FfmpegAudioExtractRequest
AudioOutputCodec
FfmpegCommandBuilder.extractAudio
```

Retain `StreamMode`, `FfmpegTrimRequest`, `FfmpegCommandBuilder.trim`, timestamp
formatting, and range-duration logic.

- [ ] **Step 3: Delete player export application/services**

Delete the four files listed above. Confirm no remaining `lib/` import references
`AudioExportController`, `FfmpegMediaEditor`, or `mediaEditorProvider`.

- [ ] **Step 4: Remove export wiring from `PlayerScreen`**

Remove:

- the `audio_export_controller.dart` import;
- `ref.watch(audioExportControllerProvider)`;
- `_extractAudio`;
- `audioExport`, `onExtractAudio`, and `onCancelAudioExport` constructor
  arguments and fields;
- `_ExportActions`;
- all `AudioExportState` and `AudioExportStatus` references.

The final `_UtilityControls` row must be:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _CurrentQueueButton(
      count: queue.playbackQueue.items.length,
      hasCurrent: queue.currentItem != null,
      onPressed: onShowPlaybackQueue,
    ),
    const SizedBox(width: 4),
    _PlaybackModeIconButton(
      mode: mode,
      onPressed: onCyclePlaybackMode,
    ),
    const SizedBox(width: 4),
    _VolumeMenuButton(
      engine: engine,
      palette: palette,
      onVolumeChanged: onPersistVolume,
    ),
  ],
)
```

- [ ] **Step 5: Confirm supported playback formats remain**

Run:

```powershell
rg -n "'flac'|'opus'" lib/domain/media/media_path.dart
```

Expected: FLAC and Opus remain in `audioExtensions`; removing export must not
remove playback support.

- [ ] **Step 6: Confirm no export UI/code remains**

Run:

```powershell
rg -n "AudioExport|audioExport|extractAudio|导出 FLAC|导出音频|取消导出|mediaEditorProvider" lib
```

Expected: no matches.

- [ ] **Step 7: Run static analysis**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Commit audio-export removal**

```powershell
git add lib test
git commit -m "refactor: remove player audio export"
```

### Task 4: Build And Visual Verification

**Files:**
- Modify: `logs/request-log.md`
- Modify: `logs/windows.md`

**Interfaces:**
- Consumes: completed queue and export changes.
- Produces: validated Windows Debug executable and implementation log.

- [ ] **Step 1: Run available tests**

Run:

```powershell
flutter test
```

Expected: all tests pass. If the known host `localhost` test-runner connection
failure recurs before any test loads, record it accurately and do not report
tests as passing.

- [ ] **Step 2: Run final static verification**

Run:

```powershell
dart format lib/features/player/presentation/player_screen.dart lib/features/player/presentation/playback_queue_location.dart test/features/player/presentation/playback_queue_location_test.dart
flutter analyze
git diff --check
```

Expected: formatter completes, analysis reports no issues, and `git diff
--check` produces no output.

- [ ] **Step 3: Build Windows Debug**

Run:

```powershell
flutter build windows --debug
```

Expected: `Built build\windows\x64\runner\Debug\heni.exe`.

- [ ] **Step 4: Verify the real window**

Launch only the Debug executable. Open the current-playlist dialog and verify:

- it initially centers the current track;
- pressing `定位当前歌曲` re-centers it;
- a search hiding the current item is cleared by locate;
- the bottom-right FLAC export button is absent;
- queue, playback mode, and volume remain aligned;
- no overflow appears at wide and compact DPI-aware sizes.

Do not terminate user-owned Release processes.

- [ ] **Step 5: Update engineering logs**

Record the delivered behavior and exact verification results in:

- `logs/request-log.md`;
- `logs/windows.md`.

- [ ] **Step 6: Commit verification logs**

```powershell
git add logs/request-log.md logs/windows.md
git commit -m "docs: record queue locate delivery"
```
