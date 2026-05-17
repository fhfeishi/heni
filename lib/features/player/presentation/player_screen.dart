import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../../design/app_theme.dart';
import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_kind.dart';
import '../../../domain/media/media_path.dart';
import '../../../domain/media/media_probe.dart';
import '../../../domain/playback/heni_playlist.dart';
import '../../../domain/playback/playback_mode.dart';
import '../../../services/media/playback_engine.dart';
import '../../../services/media/playback_providers.dart';
import '../../scenery/presentation/scenery_stage.dart';
import '../application/audio_export_controller.dart';
import '../application/playback_queue_controller.dart';
import '../application/player_state.dart';

const _hoverDuration = Duration(milliseconds: 220);
const _hoverCurve = Curves.easeOutCubic;
const _contentSwitchDuration = Duration(milliseconds: 320);
const _denseIconButtonSize = 40.0;
const _regularIconButtonSize = 42.0;
const _compactIconSize = 18.0;
const _libraryLeadColumnWidth = 64.0;
const _libraryDurationColumnWidth = 64.0;
const _libraryActionColumnWidth = 92.0;

Color _shellGlassFill(HeniPalette palette, {double emphasis = 1}) {
  return Color.alphaBlend(
    palette.surfaceAlt.withValues(alpha: 0.58 + 0.05 * emphasis),
    palette.surface,
  );
}

Color _shellGlassBorder(HeniPalette palette, {double emphasis = 1}) {
  return palette.seed.withValues(alpha: 0.13 + 0.02 * emphasis);
}

Color _primaryGlassText({double emphasis = 1}) {
  return Colors.white.withValues(
    alpha: 0.9 + 0.04 * (emphasis - 1).clamp(0, 1),
  );
}

Color _secondaryGlassText({double emphasis = 1}) {
  return Colors.white.withValues(alpha: 0.58 + 0.08 * emphasis.clamp(0, 1.4));
}

Color _tertiaryGlassText() {
  return Colors.white.withValues(alpha: 0.42);
}

final librarySearchQueryProvider = NotifierProvider<LibrarySearchQuery, String>(
  LibrarySearchQuery.new,
);

class LibrarySearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value.trim();
  }

  void clear() {
    state = '';
  }
}

final focusModeProvider = NotifierProvider<FocusMode, bool>(FocusMode.new);

class FocusMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

enum _SongsSortMode {
  queue('队列顺序'),
  title('按标题'),
  kind('按类型'),
  source('按来源');

  const _SongsSortMode(this.label);

  final String label;
}

class _ShellLayout {
  const _ShellLayout({required this.compact, required this.quiet});

  factory _ShellLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final compact = width < 1480 || height < 920;
    final quiet = width < 1260 || height < 820;
    return _ShellLayout(compact: compact, quiet: quiet);
  }

  final bool compact;
  final bool quiet;

  double get topHeight =>
      quiet
          ? 58
          : compact
          ? 62
          : 66;
  double get bottomHeight =>
      quiet
          ? 96
          : compact
          ? 104
          : 112;
  double get sidebarWidth =>
      quiet
          ? 196
          : compact
          ? 212
          : 228;
  double get sidebarPadding => quiet ? 12 : 14;
  double get topHorizontalMargin => quiet ? 12 : 16;
  double get contentGap => quiet ? 8 : 12;
  bool get showSidebarStatus => !quiet;
  bool get useDenseHeader => compact;
  bool get showSceneryOrb => !quiet;
  bool get showNowPlayingDetails => !quiet;
  bool get showNowPlayingMeta => !quiet;
  bool get preferCompactUtility => compact;
}

IconData _playbackModeIcon(HeniPlaybackMode mode) {
  return switch (mode) {
    HeniPlaybackMode.sequence => Icons.format_list_numbered,
    HeniPlaybackMode.listLoop => Icons.repeat,
    HeniPlaybackMode.singleLoop => Icons.repeat_one,
    HeniPlaybackMode.random => Icons.shuffle,
  };
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding,
    this.radius = 24,
    this.fillColor,
    this.borderColor,
    this.auroraPalette,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? fillColor;
  final Color? borderColor;
  final HeniPalette? auroraPalette;

  @override
  Widget build(BuildContext context) {
    final resolvedFill =
        fillColor ??
        Color.alphaBlend(Colors.white.withValues(alpha: 0.06), Colors.black);
    final resolvedBorder =
        borderColor ?? Colors.white.withValues(alpha: 0.07);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: resolvedFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: resolvedBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (auroraPalette != null)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 0,
                  height: 1,
                  child: IgnorePointer(
                    child: _AuroraBar(palette: auroraPalette!),
                  ),
                ),
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuroraBar extends StatefulWidget {
  const _AuroraBar({required this.palette});

  final HeniPalette palette;

  @override
  State<_AuroraBar> createState() => _AuroraBarState();
}

class _AuroraBarState extends State<_AuroraBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (!w.isFinite || w <= 0) {
            return const SizedBox.shrink();
          }
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        p.seed.withValues(alpha: 0.18),
                        p.accent.withValues(alpha: 0.22),
                        p.seed.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = _ctrl.value;
                  final highlightW = w * 0.32;
                  final left = -highlightW + (w + highlightW * 2) * t;
                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: highlightW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            p.accent.withValues(alpha: 0.65),
                            p.seed.withValues(alpha: 0.80),
                            p.accent.withValues(alpha: 0.65),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShellBand extends StatelessWidget {
  const _ShellBand({
    required this.child,
    required this.palette,
    required this.padding,
    this.margin = EdgeInsets.zero,
    this.height,
    this.emphasis = 1,
  });

  final Widget child;
  final HeniPalette palette;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? height;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.992, end: 1),
        duration: const Duration(milliseconds: 760),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 14 * emphasis),
            child: AnimatedContainer(
              duration: _contentSwitchDuration,
              curve: _hoverCurve,
              height: height,
              child: _GlassPanel(
                radius: 26,
                fillColor: _shellGlassFill(palette, emphasis: emphasis),
                borderColor: _shellGlassBorder(palette, emphasis: emphasis),
                auroraPalette: palette,
                padding: padding,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeniDialog extends ConsumerWidget {
  const _HeniDialog({
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.78),
                ),
                border: Border.all(
                  color: palette.seed.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: palette.seed.withValues(alpha: 0.18),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 0,
                    height: 1,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              palette.seed.withValues(alpha: 0.6),
                              palette.accent.withValues(alpha: 0.7),
                              palette.seed.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                          child: title,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                          child: content,
                        ),
                      ),
                      if (actions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                actions[i],
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientBackdrop extends ConsumerStatefulWidget {
  const _AmbientBackdrop({required this.palette});

  final HeniPalette palette;

  @override
  ConsumerState<_AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends ConsumerState<_AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _playing = false;
  StreamSubscription<bool>? _sub;
  StreamSubscription<Duration>? _posSub;
  Duration _lastPos = Duration.zero;
  double _pulse = 0;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    final engine = ref.read(playbackEngineProvider);
    _sub = engine.playing.listen((v) {
      if (!mounted) return;
      setState(() {
        _playing = v;
        _ctrl.duration = Duration(seconds: v ? 14 : 24);
        _ctrl.repeat();
      });
    });
    _posSub = engine.position.listen((p) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMilliseconds;
      _lastTick = now;
      if (_playing && dt > 0 && dt < 800) {
        final delta = (p - _lastPos).inMilliseconds.abs();
        if (delta > 0 && delta < 800) {
          setState(() {
            _pulse = (_pulse * 0.78 + (delta / 250).clamp(0, 1)) * 0.95;
            if (_pulse > 1) _pulse = 1;
          });
        }
      }
      _lastPos = p;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    unawaited(_sub?.cancel());
    unawaited(_posSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final intensity = _playing ? (0.7 + _pulse * 0.3) : 0.55;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: palette.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                palette.seed.withValues(alpha: 0.10 * intensity),
                palette.surface,
              ),
              palette.surface,
              Color.alphaBlend(
                palette.accent.withValues(alpha: 0.06 * intensity),
                palette.surface,
              ),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value * 2 * math.pi;
            final amp = _playing ? 1.0 : 0.6;
            final dx1 = math.sin(t) * 60 * amp;
            final dy1 = math.cos(t * 0.7) * 40 * amp;
            final dx2 = math.sin(t * 0.6 + 1.3) * 80 * amp;
            final dy2 = math.cos(t * 0.9 + 0.4) * 50 * amp;
            final dx3 = math.sin(t * 1.2 + 2.1) * 70 * amp;
            final dy3 = math.cos(t * 1.0 + 0.8) * 45 * amp;
            final scale1 = 1.0 + math.sin(t * 0.5) * 0.08 + _pulse * 0.05;
            final scale2 = 1.0 + math.cos(t * 0.4) * 0.06 + _pulse * 0.04;
            final scale3 = 1.0 + math.sin(t * 0.8) * 0.10;

            return Stack(
              children: [
                Positioned(
                  top: -140 + dy1,
                  left: -110 + dx1,
                  child: Transform.scale(
                    scale: scale1,
                    child: _GlowOrb(
                      size: 420,
                      color: palette.seed.withValues(
                        alpha: 0.18 * intensity,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -200 + dy2,
                  right: -120 + dx2,
                  child: Transform.scale(
                    scale: scale2,
                    child: _GlowOrb(
                      size: 460,
                      color: palette.accent.withValues(
                        alpha: 0.10 * intensity,
                      ),
                    ),
                  ),
                ),
                if (_playing)
                  Positioned(
                    top: 240 + dy3,
                    right: 120 + dx3,
                    child: Transform.scale(
                      scale: scale3,
                      child: _GlowOrb(
                        size: 280,
                        color: Color.lerp(
                          palette.seed,
                          palette.accent,
                          0.5,
                        )!.withValues(alpha: 0.08 + _pulse * 0.06),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CornerGlow extends ConsumerStatefulWidget {
  const _CornerGlow({required this.palette});

  final HeniPalette palette;

  @override
  ConsumerState<_CornerGlow> createState() => _CornerGlowState();
}

class _CornerGlowState extends ConsumerState<_CornerGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _playing = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _sub = ref.read(playbackEngineProvider).playing.listen((v) {
      if (!mounted) return;
      setState(() {
        _playing = v;
        _ctrl.duration = Duration(milliseconds: v ? 1800 : 3200);
        _ctrl.repeat(reverse: true);
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final breathe = _ctrl.value;
        final amp = _playing ? 1.0 : 0.4;
        final scale = 1.0 + 0.05 * breathe * amp;
        final alphaBoost = _playing ? 0.4 * breathe : 0.15 * breathe;

        return Stack(
          children: [
            Positioned(
              left: -120,
              top: -120,
              child: Transform.scale(
                scale: scale,
                child: _CornerOrb(
                  size: 320,
                  color: palette.seed.withValues(
                    alpha: 0.18 + alphaBoost * 0.08,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -130,
              top: -100,
              child: Transform.scale(
                scale: 1.0 + 0.04 * (1 - breathe) * amp,
                child: _CornerOrb(
                  size: 260,
                  color: palette.accent.withValues(
                    alpha: 0.10 + alphaBoost * 0.06,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -100,
              bottom: -120,
              child: Transform.scale(
                scale: 1.0 + 0.045 * breathe * amp,
                child: _CornerOrb(
                  size: 300,
                  color:
                      Color.lerp(
                        palette.seed,
                        palette.accent,
                        0.6,
                      )!.withValues(alpha: 0.12 + alphaBoost * 0.08),
                ),
              ),
            ),
            Positioned(
              right: -90,
              bottom: -100,
              child: Transform.scale(
                scale: 1.0 + 0.035 * (1 - breathe) * amp,
                child: _CornerOrb(
                  size: 220,
                  color: palette.accent.withValues(
                    alpha: 0.08 + alphaBoost * 0.05,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerOrb extends StatelessWidget {
  const _CornerOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final uiStyle = ref.watch(activeUiStyleProvider);
    final sceneryImages = ref.watch(sceneryImagePathsProvider);
    final queue = ref.watch(playbackQueueControllerProvider);
    final currentMedia = queue.currentItem ?? ref.watch(currentMediaProvider);
    final mediaProbe = ref.watch(currentMediaProbeProvider);
    final lyrics = ref.watch(currentLyricsProvider);
    final audioExport = ref.watch(audioExportControllerProvider);
    final engine = ref.watch(playbackEngineProvider);
    final videoController = ref.watch(videoControllerProvider);
    final focusMode = ref.watch(focusModeProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _AmbientBackdrop(palette: palette)),
          Positioned.fill(
            child: IgnorePointer(child: _CornerGlow(palette: palette)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(
                top: BorderSide(
                  color:
                      Color.lerp(palette.seed, palette.accent, 0.18) ??
                      palette.seed,
                  width: 4,
                ),
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = _ShellLayout.fromConstraints(constraints);

                  return Column(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        child:
                            focusMode
                                ? _FocusRecallStrip(
                                  palette: palette,
                                  onRestore:
                                      () =>
                                          ref
                                              .read(focusModeProvider.notifier)
                                              .toggle(),
                                )
                                : _TopNavigation(
                                  palette: palette,
                                  queue: queue,
                                  layout: layout,
                                ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 360),
                              curve: Curves.easeOutCubic,
                              child:
                                  focusMode
                                      ? _FocusSideRecall(
                                        palette: palette,
                                        onRestore:
                                            () =>
                                                ref
                                                    .read(
                                                      focusModeProvider
                                                          .notifier,
                                                    )
                                                    .toggle(),
                                      )
                                      : _Sidebar(
                              palette: palette,
                              queue: queue,
                              layout: layout,
                              onCreatePlaylist:
                                  () => _createPlaylist(context, ref),
                              onSelectPlaylist: (playlistId) {
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .selectPlaylist(playlistId);
                              },
                              onAddFromLibrary: (playlistId) {
                                _addFromLibrary(context, ref, playlistId);
                              },
                              onRenamePlaylist: (playlist) {
                                _renamePlaylist(context, ref, playlist);
                              },
                              onEditDescription: (playlist) {
                                _editPlaylistDescription(
                                  context,
                                  ref,
                                  playlist,
                                );
                              },
                              onDeletePlaylist: (playlist) {
                                _confirmDeletePlaylist(context, ref, playlist);
                              },
                            ),
                            ),
                            Expanded(
                              child: _ContentArea(
                                palette: palette,
                                uiStyle: uiStyle,
                                sceneryImages: sceneryImages,
                                queue: queue,
                                currentMedia: currentMedia,
                                mediaProbe: mediaProbe,
                                lyrics: lyrics,
                                engine: engine,
                                videoController: videoController,
                                layout: layout,
                                onPickScenery: () => _pickScenery(ref),
                                onPickMedia: () => _pickMedia(ref),
                                onPickFolder: () => _pickFolder(ref),
                                onRefreshLibrary: () {
                                  unawaited(
                                    ref
                                        .read(
                                          playbackQueueControllerProvider
                                              .notifier,
                                        )
                                        .refreshLibrary(),
                                  );
                                },
                                onPlayIndex: (index) {
                                  unawaited(
                                    ref
                                        .read(
                                          playbackQueueControllerProvider
                                              .notifier,
                                        )
                                        .playIndex(index),
                                  );
                                },
                                onAddToPlaylist: (playlistId, item) {
                                  ref
                                      .read(
                                        playbackQueueControllerProvider
                                            .notifier,
                                      )
                                      .addItemToPlaylist(playlistId, item);
                                },
                                onAddFromLibrary: (playlistId) {
                                  _addFromLibrary(context, ref, playlistId);
                                },
                                onManagePlaylist: (playlist) {
                                  _managePlaylistItems(context, ref, playlist);
                                },
                                onRemoveFromPlaylist: (playlistId, item) {
                                  ref
                                      .read(
                                        playbackQueueControllerProvider
                                            .notifier,
                                      )
                                      .removeItemsFromPlaylist(playlistId, [
                                        item,
                                      ]);
                                },
                                onRemoveFromPlaybackQueue: (index) {
                                  unawaited(
                                    ref
                                        .read(
                                          playbackQueueControllerProvider
                                              .notifier,
                                        )
                                        .removePlaybackQueueItemAt(index),
                                  );
                                },
                                onSelectUiStyle: (style) {
                                  ref
                                      .read(activeUiStyleProvider.notifier)
                                      .select(style);
                                  unawaited(
                                    ref
                                        .read(
                                          playbackQueueControllerProvider
                                              .notifier,
                                        )
                                        .persistShellPreferences(
                                          uiStyle: style,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      _BottomPlayerBar(
                        palette: palette,
                        currentMedia: currentMedia,
                        mediaProbe: mediaProbe,
                        audioExport: audioExport,
                        queue: queue,
                        engine: engine,
                        layout: layout,
                        onPreviousTrack: () {
                          unawaited(
                            ref
                                .read(playbackQueueControllerProvider.notifier)
                                .playPrevious(),
                          );
                        },
                        onNextTrack: () {
                          unawaited(
                            ref
                                .read(playbackQueueControllerProvider.notifier)
                                .playNext(),
                          );
                        },
                        onCyclePlaybackMode: () {
                          ref
                              .read(playbackQueueControllerProvider.notifier)
                              .cyclePlaybackMode();
                        },
                        onShowPlaybackQueue: () {
                          _showPlaybackQueue(context, ref);
                        },
                        onExtractAudio:
                            currentMedia == null
                                ? null
                                : () => _extractAudio(ref, currentMedia),
                        onCancelAudioExport: () {
                          unawaited(
                            ref
                                .read(audioExportControllerProvider.notifier)
                                .cancel(),
                          );
                        },
                        onPersistVolume: (volume) {
                          unawaited(
                            ref
                                .read(playbackQueueControllerProvider.notifier)
                                .persistVolume(volume),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [...audioExtensions, ...videoExtensions],
      dialogTitle: '添加音视频文件',
    );
    final paths =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .where(isSupportedMediaPath)
            .toList();
    if (paths == null || paths.isEmpty) {
      return;
    }

    await ref.read(playbackQueueControllerProvider.notifier).addItems([
      for (final path in paths)
        MediaItem.fromPath(path, kind: mediaKindFromPath(path)),
    ], playFirst: true);
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: '打开本地媒体文件夹',
      lockParentWindow: true,
    );
    if (path == null) {
      return;
    }

    await ref
        .read(playbackQueueControllerProvider.notifier)
        .loadDirectory(path);
  }

  Future<void> _pickScenery(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['bmp', 'jpeg', 'jpg', 'png', 'webp'],
      dialogTitle: '选择播放背景图片',
    );
    final paths =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => File(path).existsSync())
            .toList();

    if (paths == null || paths.isEmpty) {
      return;
    }

    ref.read(sceneryImagePathsProvider.notifier).replaceAll(paths);
    unawaited(
      ref
          .read(playbackQueueControllerProvider.notifier)
          .persistShellPreferences(sceneryImagePaths: paths),
    );
  }

  Future<void> _extractAudio(WidgetRef ref, MediaItem item) async {
    final outputPath = await FilePicker.saveFile(
      dialogTitle: '导出音频',
      fileName: '${item.title}.flac',
      initialDirectory: p.dirname(item.path),
      type: FileType.custom,
      allowedExtensions: const ['flac'],
      lockParentWindow: true,
    );
    if (outputPath == null) {
      return;
    }

    unawaited(
      ref
          .read(audioExportControllerProvider.notifier)
          .extractAudio(inputPath: item.path, outputPath: outputPath),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreatePlaylistResult>(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(playbackQueueControllerProvider.notifier)
        .createPlaylist(result.name);
  }

  Future<void> _addFromLibrary(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
    final queue = ref.read(playbackQueueControllerProvider);
    final items = await showDialog<List<MediaItem>>(
      context: context,
      builder: (context) => _AddFromLibraryDialog(queue: queue),
    );
    if (items == null || items.isEmpty) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .addItemsToPlaylist(playlistId, items);
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => _TextEditDialog(
            title: '重命名歌单',
            initialValue: playlist.name,
            hintText: '歌单名称',
            actionText: '保存',
          ),
    );
    if (name == null) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .renamePlaylist(playlist.id, name);
  }

  Future<void> _editPlaylistDescription(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final description = await showDialog<String>(
      context: context,
      builder:
          (context) => _TextEditDialog(
            title: '歌单说明',
            initialValue: playlist.description,
            hintText: '写一点关于这个歌单的说明',
            actionText: '保存',
            maxLines: 4,
          ),
    );
    if (description == null) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .updatePlaylistDescription(playlist.id, description);
  }

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => _HeniDialog(
            title: const Text('删除歌单'),
            content: Text('确定删除“${playlist.name}”吗？不会删除本地音频文件。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .deletePlaylist(playlist.id);
  }

  Future<void> _managePlaylistItems(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    final items = await showDialog<List<MediaItem>>(
      context: context,
      builder: (context) => _ManagePlaylistDialog(playlist: playlist),
    );
    if (items == null || items.isEmpty) {
      return;
    }

    ref
        .read(playbackQueueControllerProvider.notifier)
        .removeItemsFromPlaylist(playlist.id, items);
  }

  Future<void> _showPlaybackQueue(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _PlaybackQueueDialog(),
    );
  }
}

class _TopNavigation extends ConsumerWidget {
  const _TopNavigation({
    required this.palette,
    required this.queue,
    required this.layout,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ShellBand(
      palette: palette,
      margin: EdgeInsets.fromLTRB(
        layout.topHorizontalMargin,
        12,
        layout.topHorizontalMargin,
        6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: layout.quiet ? 12 : 16,
        vertical: layout.quiet ? 8 : 10,
      ),
      height: layout.topHeight,
      emphasis: 1.05,
      child: Row(
        children: [
          _TopBrand(palette: palette, layout: layout),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.quiet ? 10 : 16),
              child: _TopSearchField(layout: layout),
            ),
          ),
          _CompactPaletteButton(active: palette),
          SizedBox(width: layout.quiet ? 6 : 8),
          _SettingsMenu(queue: queue),
        ],
      ),
    );
  }
}

class _TopSearchField extends ConsumerStatefulWidget {
  const _TopSearchField({required this.layout});

  final _ShellLayout layout;

  @override
  ConsumerState<_TopSearchField> createState() => _TopSearchFieldState();
}

class _TopSearchFieldState extends ConsumerState<_TopSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focused != _focusNode.hasFocus) {
          setState(() => _focused = _focusNode.hasFocus);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(librarySearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final palette = ref.watch(activePaletteProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: widget.layout.quiet ? 34 : 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _focused ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              _focused
                  ? palette.seed.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
          width: _focused ? 1.4 : 1,
        ),
        boxShadow:
            _focused
                ? [
                  BoxShadow(
                    color: palette.seed.withValues(alpha: 0.32),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.18),
                    blurRadius: 22,
                  ),
                ]
                : const [],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (value) {
          ref.read(librarySearchQueryProvider.notifier).setQuery(value);
        },
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _primaryGlassText(),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '搜索当前列表里的歌曲、路径',
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _tertiaryGlassText()),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color:
                _focused
                    ? palette.seed
                    : _secondaryGlassText(emphasis: 0.96),
          ),
          suffixIcon:
              _controller.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _controller.clear();
                      ref.read(librarySearchQueryProvider.notifier).clear();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _TopBrand extends StatelessWidget {
  const _TopBrand({required this.palette, required this.layout});

  final HeniPalette palette;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: layout.quiet ? 116 : 134,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.985, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(palette.accent, palette.seed, 0.3)!,
                    palette.seed,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.seed.withValues(alpha: 0.32),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'H',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: heniReadableForegroundOn(palette.seed),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Heni',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 0.4,
                color: _primaryGlassText(emphasis: 1.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.palette,
    required this.queue,
    required this.layout,
    required this.onCreatePlaylist,
    required this.onSelectPlaylist,
    required this.onAddFromLibrary,
    required this.onRenamePlaylist,
    required this.onEditDescription,
    required this.onDeletePlaylist,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<String> onSelectPlaylist;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onRenamePlaylist;
  final ValueChanged<HeniPlaylist> onEditDescription;
  final ValueChanged<HeniPlaylist> onDeletePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackQueuePlaylist = HeniPlaylist(
      id: heniPlaybackQueueId,
      name: '当前播放列表',
      description:
          queue.currentItem == null
              ? '还没有加入正在播放的内容'
              : '当前播放 ${queue.currentItem!.title}',
      items: queue.playbackQueue.items,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.sidebarPadding,
        0,
        layout.quiet ? 10 : 12,
        layout.sidebarPadding,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -8,
            top: 44,
            bottom: 44,
            child: Container(
              width: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.seed.withValues(alpha: 0.12),
                    palette.seed.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          _GlassPanel(
            radius: 26,
            fillColor: _shellGlassFill(palette, emphasis: 0.96),
            borderColor: _shellGlassBorder(palette, emphasis: 0.96),
            auroraPalette: palette,
            padding: EdgeInsets.fromLTRB(
              layout.quiet ? 10 : 12,
              layout.quiet ? 10 : 12,
              layout.quiet ? 8 : 10,
              layout.quiet ? 10 : 12,
            ),
            child: AnimatedContainer(
              duration: _contentSwitchDuration,
              curve: _hoverCurve,
              width: layout.sidebarWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SidebarSectionHeader(title: '浏览'),
                  const SizedBox(height: 4),
                  _PlaylistTile(
                    palette: palette,
                    playlist: queue.library,
                    selected: queue.activePlaylistId == queue.library.id,
                    isPlayingHere: queue.currentItem != null,
                    onTap: () => onSelectPlaylist(queue.library.id),
                  ),
                  const SizedBox(height: 2),
                  _PlaylistTile(
                    palette: palette,
                    playlist: playbackQueuePlaylist,
                    selected: queue.activePlaylistId == heniPlaybackQueueId,
                    isPlayingHere: queue.currentItem != null,
                    onTap: () => onSelectPlaylist(heniPlaybackQueueId),
                  ),
                  SizedBox(height: layout.quiet ? 14 : 18),
                  _SidebarSectionHeader(
                    title: '我的歌单',
                    action: IconButton(
                      tooltip: '新建歌单',
                      onPressed: onCreatePlaylist,
                      icon: const Icon(Icons.add, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    flex: 2,
                    child:
                        queue.playlists.isEmpty
                            ? _SidebarEmptyState(
                              palette: palette,
                              message: '从曲库挑歌加入歌单，慢慢搭起自己的收藏。',
                            )
                            : ListView(
                              children: [
                                for (final playlist in queue.playlists)
                                  _PlaylistTile(
                                    palette: palette,
                                    playlist: playlist,
                                    selected:
                                        playlist.id == queue.activePlaylistId,
                                    isPlayingHere:
                                        queue.currentItem != null &&
                                        playlist.items.any(
                                          (it) =>
                                              it.path ==
                                              queue.currentItem!.path,
                                        ),
                                    onTap: () => onSelectPlaylist(playlist.id),
                                    onAddFromLibrary:
                                        () => onAddFromLibrary(playlist.id),
                                    onRename: () => onRenamePlaylist(playlist),
                                    onEditDescription:
                                        () => onEditDescription(playlist),
                                    onDelete: () => onDeletePlaylist(playlist),
                                  ),
                              ],
                            ),
                  ),
                  const Spacer(),
                  if (layout.showSidebarStatus &&
                      (queue.statusMessage != null || queue.lastError != null))
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前状态',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _tertiaryGlassText(),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (queue.statusMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              queue.statusMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _secondaryGlassText(emphasis: 0.96),
                                height: 1.38,
                              ),
                            ),
                          ],
                          if (queue.lastError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              queue.lastError!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.3,
                color: _secondaryGlassText(emphasis: 0.95),
              ),
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerStatefulWidget {
  const _PlaylistTile({
    required this.palette,
    required this.playlist,
    required this.selected,
    required this.onTap,
    this.isPlayingHere = false,
    this.onAddFromLibrary,
    this.onRename,
    this.onEditDescription,
    this.onDelete,
  });

  final HeniPalette palette;
  final HeniPlaylist playlist;
  final bool selected;
  final bool isPlayingHere;
  final VoidCallback onTap;
  final VoidCallback? onAddFromLibrary;
  final VoidCallback? onRename;
  final VoidCallback? onEditDescription;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends ConsumerState<_PlaylistTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.palette.seed;
    final active = widget.selected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale:
            widget.selected
                ? 1.0
                : _hovered
                ? 1.012
                : 1.0,
        child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(
              alpha:
                  widget.selected
                      ? 0.18
                      : _hovered
                      ? 0.08
                      : 0.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: AnimatedContainer(
                      duration: _hoverDuration,
                      curve: _hoverCurve,
                      width: widget.selected ? 3 : (_hovered ? 1.5 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color:
                            widget.selected
                                ? tint
                                : Colors.white.withValues(alpha: 0.28),
                        boxShadow: [
                          if (widget.selected)
                            BoxShadow(
                              color: tint.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: _hoverDuration,
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tint.withValues(
                              alpha: active ? 0.24 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.onDelete == null
                                ? Icons.library_music_outlined
                                : Icons.queue_music_rounded,
                            size: 14,
                            color: _primaryGlassText(
                              emphasis: active ? 1.06 : 0.92,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  widget.selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                              color: _primaryGlassText(
                                emphasis: widget.selected ? 1.04 : 0.94,
                              ),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (widget.isPlayingHere)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: StreamBuilder<bool>(
                              stream: ref.read(playbackEngineProvider).playing,
                              initialData: false,
                              builder: (context, snap) {
                                return _NowPlayingWave(
                                  color: widget.palette.seed,
                                  active: snap.data ?? false,
                                );
                              },
                            ),
                          ),
                        _CountBadge(count: widget.playlist.items.length),
                        if (widget.onDelete != null)
                          AnimatedOpacity(
                            duration: _hoverDuration,
                            opacity: _hovered ? 1 : 0,
                            child: SizedBox(
                              width: _hovered ? 24 : 0,
                              height: 24,
                              child: PopupMenuButton<_PlaylistAction>(
                                tooltip: '歌单选项',
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz, size: 16),
                                iconSize: 16,
                                onSelected: (action) {
                                  switch (action) {
                                    case _PlaylistAction.addFromLibrary:
                                      widget.onAddFromLibrary?.call();
                                    case _PlaylistAction.rename:
                                      widget.onRename?.call();
                                    case _PlaylistAction.description:
                                      widget.onEditDescription?.call();
                                    case _PlaylistAction.delete:
                                      widget.onDelete?.call();
                                  }
                                },
                                itemBuilder:
                                    (context) => const [
                                      PopupMenuItem<_PlaylistAction>(
                                        value: _PlaylistAction.addFromLibrary,
                                        child: Text('添加歌曲'),
                                      ),
                                      PopupMenuItem<_PlaylistAction>(
                                        value: _PlaylistAction.rename,
                                        child: Text('重命名'),
                                      ),
                                      PopupMenuItem<_PlaylistAction>(
                                        value: _PlaylistAction.description,
                                        child: Text('编辑说明'),
                                      ),
                                      PopupMenuDivider(),
                                      PopupMenuItem<_PlaylistAction>(
                                        value: _PlaylistAction.delete,
                                        child: Text('删除'),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _secondaryGlassText(emphasis: 1)),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _secondaryGlassText(),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshStatusBadge extends StatelessWidget {
  const _RefreshStatusBadge({
    required this.icon,
    required this.label,
    this.accent = false,
    this.spinning = false,
  });

  final IconData icon;
  final String label;
  final bool accent;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor =
        accent
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              accent
                  ? theme.colorScheme.primary.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            )
          else
            Icon(icon, size: 14, color: _secondaryGlassText(emphasis: 1.1)),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color:
                  accent
                      ? _primaryGlassText()
                      : _secondaryGlassText(emphasis: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          color: _secondaryGlassText(),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState({required this.palette, required this.message});

  final HeniPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.seed.withValues(alpha: 0.08),
          palette.surfaceAlt,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有歌单',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _primaryGlassText(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _secondaryGlassText(emphasis: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongsEmptyState extends StatelessWidget {
  const _SongsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.library_music_outlined),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: _primaryGlassText(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _secondaryGlassText(emphasis: 0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PlaylistAction { addFromLibrary, rename, description, delete }

class _ContentArea extends ConsumerWidget {
  const _ContentArea({
    required this.palette,
    required this.uiStyle,
    required this.sceneryImages,
    required this.queue,
    required this.currentMedia,
    required this.mediaProbe,
    required this.lyrics,
    required this.engine,
    required this.videoController,
    required this.layout,
    required this.onPickScenery,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
    required this.onAddFromLibrary,
    required this.onManagePlaylist,
    required this.onRemoveFromPlaylist,
    required this.onRemoveFromPlaybackQueue,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final HeniUiStyle uiStyle;
  final List<String> sceneryImages;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AsyncValue<LyricsDocument> lyrics;
  final PlaybackEngine engine;
  final VideoController videoController;
  final _ShellLayout layout;
  final VoidCallback onPickScenery;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onManagePlaylist;
  final void Function(String playlistId, MediaItem item) onRemoveFromPlaylist;
  final ValueChanged<int> onRemoveFromPlaybackQueue;
  final ValueChanged<HeniUiStyle> onSelectUiStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusMode = ref.watch(focusModeProvider);
    final fullBleed = focusMode && uiStyle == HeniUiStyle.scenery;

    return Padding(
      padding:
          fullBleed
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(
                layout.quiet ? 4 : 8,
                0,
                layout.topHorizontalMargin,
                layout.sidebarPadding,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uiStyle == HeniUiStyle.scenery && !fullBleed)
            _GlassPanel(
              radius: 22,
              fillColor: _shellGlassFill(palette, emphasis: 0.9),
              borderColor: _shellGlassBorder(palette, emphasis: 0.9),
              auroraPalette: palette,
              padding: EdgeInsets.fromLTRB(
                layout.quiet ? 12 : 16,
                layout.quiet ? 8 : 10,
                layout.quiet ? 12 : 16,
                layout.quiet ? 8 : 10,
              ),
              child: _ContentHeader(
                palette: palette,
                uiStyle: uiStyle,
                queue: queue,
                currentMedia: currentMedia,
                layout: layout,
                onPickScenery: onPickScenery,
                onPickMedia: onPickMedia,
                onPickFolder: onPickFolder,
                onRefreshLibrary: onRefreshLibrary,
                onAddFromLibrary: onAddFromLibrary,
                onManagePlaylist: onManagePlaylist,
                onSelectUiStyle: onSelectUiStyle,
              ),
            ),
          if (uiStyle == HeniUiStyle.scenery && !fullBleed)
            SizedBox(height: layout.contentGap),
          Expanded(
            child: switch (uiStyle) {
              HeniUiStyle.library => _LibraryContent(
                palette: palette,
                queue: queue,
                layout: layout,
                onPlayIndex: onPlayIndex,
                onAddToPlaylist: onAddToPlaylist,
                onRemoveFromPlaylist: onRemoveFromPlaylist,
                onRemoveFromPlaybackQueue: onRemoveFromPlaybackQueue,
                onPickFolder: onPickFolder,
                onPickMedia: onPickMedia,
                onRefreshLibrary: onRefreshLibrary,
                onAddFromLibrary: onAddFromLibrary,
                onManagePlaylist: onManagePlaylist,
                onSelectUiStyle: onSelectUiStyle,
              ),
              _ => _SceneryContent(
                palette: palette,
                imagePaths: sceneryImages,
                currentMedia: currentMedia,
                mediaProbe: mediaProbe,
                lyrics: lyrics,
                engine: engine,
                videoController: videoController,
                layout: layout,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    required this.palette,
    required this.uiStyle,
    required this.queue,
    required this.currentMedia,
    required this.layout,
    required this.onPickScenery,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onAddFromLibrary,
    required this.onManagePlaylist,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final HeniUiStyle uiStyle;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final _ShellLayout layout;
  final VoidCallback onPickScenery;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onManagePlaylist;
  final ValueChanged<HeniUiStyle> onSelectUiStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songsView = uiStyle == HeniUiStyle.library;
    final playlist = queue.activePlaylist;
    final browsingLibrary = playlist.id == heniLibraryPlaylistId;
    final browsingPlaybackQueue = playlist.id == heniPlaybackQueueId;
    final refreshStatus = songsView ? _buildRefreshFeedback(queue) : null;
    final headingLabel = switch (uiStyle) {
      HeniUiStyle.scenery => '播放舞台',
      HeniUiStyle.library when browsingPlaybackQueue => '当前播放列表',
      HeniUiStyle.library when browsingLibrary => '本地曲库',
      HeniUiStyle.library => '我的歌单',
    };

    final actionButtons =
        uiStyle == HeniUiStyle.scenery
            ? <Widget>[
              OutlinedButton(
                onPressed: onPickScenery,
                child: const Text('更换背景'),
              ),
            ]
            : browsingLibrary
            ? <Widget>[
              OutlinedButton(
                onPressed: queue.isScanning ? null : onRefreshLibrary,
                child: Text(queue.isScanning ? '刷新中' : '刷新曲库'),
              ),
              OutlinedButton(
                onPressed: onPickFolder,
                child: const Text('导入目录'),
              ),
              FilledButton(onPressed: onPickMedia, child: const Text('添加文件')),
            ]
            : browsingPlaybackQueue
            ? <Widget>[
              FilledButton.tonalIcon(
                onPressed:
                    currentMedia == null
                        ? null
                        : () => onSelectUiStyle(HeniUiStyle.scenery),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('回到播放中'),
              ),
            ]
            : <Widget>[
              OutlinedButton(
                onPressed: () => onManagePlaylist(playlist),
                child: const Text('管理歌曲'),
              ),
              FilledButton(
                onPressed: () => onAddFromLibrary(playlist.id),
                child: const Text('添加歌曲'),
              ),
            ];

    if (uiStyle == HeniUiStyle.scenery) {
      return Row(
        children: [
          _HeadingChip(label: headingLabel, palette: palette),
          const SizedBox(width: 10),
          if (refreshStatus != null) refreshStatus,
          const Spacer(),
          ...actionButtons,
          const SizedBox(width: 12),
          _UiStyleSwitch(
            palette: palette,
            active: uiStyle,
            onSelect: onSelectUiStyle,
          ),
        ],
      );
    }

    final infoPills =
        browsingLibrary
            ? [
              _InfoPill(
                icon: Icons.music_note_outlined,
                label: '${queue.library.items.length} 首内容',
              ),
              _InfoPill(
                icon: Icons.folder_outlined,
                label: '${queue.libraryDirectories.length} 个目录',
              ),
              if (refreshStatus != null) refreshStatus,
            ]
            : [
              _InfoPill(
                icon: Icons.queue_music,
                label: '${playlist.items.length} 首内容',
              ),
              if (browsingPlaybackQueue)
                _InfoPill(
                  icon: Icons.swap_horiz_rounded,
                  label: queue.playbackMode.label,
                ),
              if (refreshStatus != null) refreshStatus,
            ];

    final headerRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeadingChip(label: headingLabel, palette: palette),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _UiStyleSwitch(
          palette: palette,
          active: uiStyle,
          onSelect: onSelectUiStyle,
        ),
      ],
    );

    final actionsAndPills = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: infoPills,
          ),
        ),
        const SizedBox(width: 10),
        Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        headerRow,
        const SizedBox(height: 10),
        actionsAndPills,
      ],
    );
  }

  Widget? _buildRefreshFeedback(PlaybackQueueState queue) {
    if (queue.isScanning) {
      return const _RefreshStatusBadge(
        icon: Icons.sync_rounded,
        label: '曲库整理中',
        accent: true,
        spinning: true,
      );
    }
    if (queue.statusMessage case final String message
        when message.contains('刷新') || message.contains('恢复')) {
      return _RefreshStatusBadge(
        icon: Icons.check_circle_outline,
        label: message,
      );
    }
    return null;
  }
}

String _formatTotalDuration(Duration total) {
  if (total == Duration.zero) return '--';
  final h = total.inHours;
  final m = total.inMinutes.remainder(60);
  if (h > 0) return '$h 小时 $m 分钟';
  if (m > 0) return '$m 分钟';
  return '${total.inSeconds} 秒';
}

class _LibraryHeroBanner extends StatelessWidget {
  const _LibraryHeroBanner({
    required this.palette,
    required this.activePlaylist,
    required this.uiStyle,
    required this.browsingLibrary,
    required this.browsingPlaybackQueue,
    required this.itemCount,
    required this.totalDurationLabel,
    required this.actions,
    required this.onSelectUiStyle,
    required this.libraryDirCount,
    required this.isScanning,
  });

  final HeniPalette palette;
  final HeniPlaylist activePlaylist;
  final HeniUiStyle uiStyle;
  final bool browsingLibrary;
  final bool browsingPlaybackQueue;
  final int itemCount;
  final String totalDurationLabel;
  final List<Widget> actions;
  final ValueChanged<HeniUiStyle> onSelectUiStyle;
  final int libraryDirCount;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingLabel = switch (true) {
      _ when browsingPlaybackQueue => '当前播放列表',
      _ when browsingLibrary => '本地曲库',
      _ => '我的歌单',
    };
    final IconData heroIcon =
        browsingPlaybackQueue
            ? Icons.queue_music_rounded
            : browsingLibrary
            ? Icons.library_music_outlined
            : Icons.album_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.seed.withValues(alpha: 0.32),
                Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.42),
                ),
                Colors.black.withValues(alpha: 0.5),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: palette.seed.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.seed.withValues(alpha: 0.18),
                blurRadius: 24,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                right: 18,
                top: 0,
                height: 1,
                child: IgnorePointer(child: _AuroraBar(palette: palette)),
              ),
              Positioned(
                right: -40,
                top: -30,
                child: Transform.rotate(
                  angle: 0.18,
                  child: Icon(
                    heroIcon,
                    size: 220,
                    color: palette.accent.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            palette.seed,
                            Color.lerp(palette.seed, palette.accent, 0.6)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: palette.seed.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        heroIcon,
                        size: 26,
                        color: heniReadableForegroundOn(palette.seed),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  headingLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white.withValues(alpha: 0.86),
                                  ),
                                ),
                              ),
                              if (isScanning) ...[
                                const SizedBox(width: 8),
                                _RefreshStatusBadge(
                                  icon: Icons.sync_rounded,
                                  label: '整理中',
                                  accent: true,
                                  spinning: true,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activePlaylist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.05,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _heroMetric(
                                icon: Icons.music_note_rounded,
                                label: '$itemCount 首',
                              ),
                              if (totalDurationLabel != '--') ...[
                                const SizedBox(width: 12),
                                _heroDot(),
                                const SizedBox(width: 12),
                                _heroMetric(
                                  icon: Icons.schedule_rounded,
                                  label: totalDurationLabel,
                                ),
                              ],
                              if (browsingLibrary) ...[
                                const SizedBox(width: 12),
                                _heroDot(),
                                const SizedBox(width: 12),
                                _heroMetric(
                                  icon: Icons.folder_outlined,
                                  label: '$libraryDirCount 个目录',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...actions,
                        const SizedBox(width: 4),
                        _UiStyleSwitch(
                          palette: palette,
                          active: uiStyle,
                          onSelect: onSelectUiStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroMetric({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.66)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
      ],
    );
  }

  Widget _heroDot() {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.32),
      ),
    );
  }
}

class _NowPlayingWave extends StatefulWidget {
  const _NowPlayingWave({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_NowPlayingWave> createState() => _NowPlayingWaveState();
}

class _NowPlayingWaveState extends State<_NowPlayingWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value * 2 * math.pi;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final phase = t + i * 1.4;
              final h = widget.active ? (4 + (math.sin(phase) + 1) * 4) : 4;
              return Container(
                width: 2.6,
                height: h.toDouble(),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _HeadingChip extends StatelessWidget {
  const _HeadingChip({required this.label, required this.palette});

  final String label;
  final HeniPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.seed.withValues(alpha: 0.32),
            Color.lerp(palette.seed, palette.accent, 0.55)!.withValues(
              alpha: 0.22,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.seed.withValues(alpha: 0.36),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _SceneryContent extends ConsumerWidget {
  const _SceneryContent({
    required this.palette,
    required this.imagePaths,
    required this.currentMedia,
    required this.mediaProbe,
    required this.lyrics,
    required this.engine,
    required this.videoController,
    required this.layout,
  });

  final HeniPalette palette;
  final List<String> imagePaths;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AsyncValue<LyricsDocument> lyrics;
  final PlaybackEngine engine;
  final VideoController videoController;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = currentMedia?.kind == MediaKind.video;
    final hasLyrics = lyrics.maybeWhen(
      data: (document) => document.lines.isNotEmpty,
      orElse: () => false,
    );
    final focusMode = ref.watch(focusModeProvider);

    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: false,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return ClipRRect(
          borderRadius: BorderRadius.circular(focusMode ? 0 : 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SceneryStage(
                imagePaths: imagePaths,
                palette: palette,
                isPlaying: isPlaying,
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: isPlaying ? 1 : 0.72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.14),
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (isVideo)
                Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.72,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _VideoStage(
                        videoController: videoController,
                        isPlaying: isPlaying,
                      ),
                    ),
                  ),
                )
              else
                _AudioHero(
                  palette: palette,
                  currentMedia: currentMedia,
                  mediaProbe: mediaProbe,
                  layout: layout,
                ),
              if (currentMedia != null && isVideo)
                Positioned(
                  left: 24,
                  bottom: hasLyrics ? 28 : 24,
                  child: _SceneryInfoBlock(
                    palette: palette,
                    currentMedia: currentMedia,
                    mediaProbe: mediaProbe,
                    compact: hasLyrics,
                  ),
                ),
              if (currentMedia != null && hasLyrics)
                Positioned(
                  right: 24,
                  bottom: isVideo ? 28 : 24,
                  child: _LyricsPanel(lyrics: lyrics, engine: engine),
                ),
              Positioned(
                top: 18,
                right: 18,
                child: _FocusToggleButton(
                  focused: focusMode,
                  onPressed:
                      () => ref.read(focusModeProvider.notifier).toggle(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusRecallStrip extends StatefulWidget {
  const _FocusRecallStrip({required this.palette, required this.onRestore});

  final HeniPalette palette;
  final VoidCallback onRestore;

  @override
  State<_FocusRecallStrip> createState() => _FocusRecallStripState();
}

class _FocusRecallStripState extends State<_FocusRecallStrip>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onRestore,
        child: Tooltip(
          message: '退出专注 · 召回顶栏',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.fromLTRB(80, 0, 80, 0),
            height: _hovered ? 12 : 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.black.withValues(alpha: 0.18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = _ctrl.value;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                p.seed.withValues(alpha: 0.55),
                                p.accent.withValues(alpha: 0.65),
                                p.seed.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                              begin: Alignment(-1.0 + 2.0 * t, 0),
                              end: Alignment(1.0 + 2.0 * t, 0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusSideRecall extends StatefulWidget {
  const _FocusSideRecall({required this.palette, required this.onRestore});

  final HeniPalette palette;
  final VoidCallback onRestore;

  @override
  State<_FocusSideRecall> createState() => _FocusSideRecallState();
}

class _FocusSideRecallState extends State<_FocusSideRecall> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onRestore,
        child: Tooltip(
          message: '退出专注 · 召回侧栏',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.fromLTRB(0, 32, 0, 32),
            width: _hovered ? 8 : 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  p.seed.withValues(alpha: _hovered ? 0.55 : 0.32),
                  p.accent.withValues(alpha: _hovered ? 0.55 : 0.32),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusToggleButton extends StatefulWidget {
  const _FocusToggleButton({required this.focused, required this.onPressed});

  final bool focused;
  final VoidCallback onPressed;

  @override
  State<_FocusToggleButton> createState() => _FocusToggleButtonState();
}

class _FocusToggleButtonState extends State<_FocusToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.focused ? '退出专注' : '专注模式',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(
                alpha: widget.focused ? 0.42 : (_hovered ? 0.32 : 0.2),
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: _hovered || widget.focused ? 0.32 : 0.16,
                ),
                width: 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder:
                  (child, animation) =>
                      RotationTransition(turns: animation, child: child),
              child: Icon(
                widget.focused
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                key: ValueKey(widget.focused),
                size: 20,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.lyrics, required this.engine});

  final AsyncValue<LyricsDocument> lyrics;
  final PlaybackEngine engine;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: _GlassPanel(
        radius: 22,
        fillColor: Colors.black.withValues(alpha: 0.24),
        borderColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Padding(
          padding: EdgeInsets.zero,
          child: lyrics.when(
            data: (document) {
              final lines = document.lines;
              if (lines.isEmpty) {
                return const SizedBox.shrink();
              }
              return StreamBuilder<Duration>(
                stream: engine.position,
                initialData: Duration.zero,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final currentIndex = _currentLyricIndex(lines, position);
                  final visible = _visibleLyrics(lines, currentIndex);

                  final headerText = [
                    if (document.header.title case final String title) title,
                    if (document.header.artist case final String artist) artist,
                  ];

                  return SizedBox(
                    width: 380,
                    height: 166,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          headerText.isEmpty ? '歌词' : headerText.join(' · '),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInOutCubic,
                            child: Column(
                              key: ValueKey('$currentIndex-${visible.length}'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final entry in visible)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          entry.key == currentIndex
                                              ? Colors.white.withValues(
                                                alpha: 0.06,
                                              )
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      entry.value.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        fontSize:
                                            entry.key == currentIndex ? 17 : 14,
                                        color:
                                            entry.key == currentIndex
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Colors.white.withValues(
                                                  alpha:
                                                      entry.key < currentIndex
                                                          ? 0.46
                                                          : 0.6,
                                                ),
                                        fontWeight:
                                            entry.key == currentIndex
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  int _currentLyricIndex(List<LyricLine> lines, Duration position) {
    if (lines.every((line) => line.time == null)) {
      return 0;
    }

    var index = 0;
    for (var i = 0; i < lines.length; i += 1) {
      final time = lines[i].time;
      if (time != null && time <= position) {
        index = i;
      }
    }
    return index;
  }

  List<MapEntry<int, LyricLine>> _visibleLyrics(
    List<LyricLine> lines,
    int currentIndex,
  ) {
    final start = (currentIndex - 2).clamp(0, lines.length - 1);
    final end = (currentIndex + 3).clamp(0, lines.length);
    return [for (var i = start; i < end; i += 1) MapEntry(i, lines[i])];
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.videoController, required this.isPlaying});

  final VideoController videoController;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPlaying ? 0.28 : 0.18),
            blurRadius: isPlaying ? 34 : 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Video(
            controller: videoController,
            fit: BoxFit.contain,
            fill: Colors.black,
            controls: null,
          ),
        ),
      ),
    );
  }
}

class _AudioHero extends StatelessWidget {
  const _AudioHero({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
    required this.layout,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 32),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: _SceneryInfoBlock(
          palette: palette,
          currentMedia: currentMedia,
          mediaProbe: mediaProbe,
        ),
      ),
    );
  }
}

class _SceneryInfoBlock extends StatelessWidget {
  const _SceneryInfoBlock({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
    this.compact = false,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 420 : 560),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          compact ? 13 : 14,
          18,
          compact ? 13 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentMedia != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  '正在播放',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: heniAccentOnGlass(palette.accent, alpha: 0.96),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (currentMedia != null) const SizedBox(height: 12),
            Text(
              currentMedia?.title ?? '还没有播放内容',
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 32 : 42,
                height: 1.05,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            if (currentMedia != null) const SizedBox(height: 7),
            if (currentMedia != null)
              Text(
                currentMedia!.kind == MediaKind.video ? '本地视频' : '本地音频',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            _MediaProbeDetails(probe: mediaProbe),
          ],
        ),
      ),
    );
  }
}

class _LibraryContent extends ConsumerStatefulWidget {
  const _LibraryContent({
    required this.palette,
    required this.queue,
    required this.layout,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onRemoveFromPlaybackQueue,
    required this.onPickFolder,
    required this.onPickMedia,
    required this.onRefreshLibrary,
    required this.onAddFromLibrary,
    required this.onManagePlaylist,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;
  final void Function(String playlistId, MediaItem item) onRemoveFromPlaylist;
  final ValueChanged<int> onRemoveFromPlaybackQueue;
  final VoidCallback onPickFolder;
  final VoidCallback onPickMedia;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onManagePlaylist;
  final ValueChanged<HeniUiStyle> onSelectUiStyle;

  @override
  ConsumerState<_LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends ConsumerState<_LibraryContent> {
  final Set<String> _selectedPaths = <String>{};
  var _selectionMode = false;
  var _sortMode = _SongsSortMode.queue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePlaylist = widget.queue.activePlaylist;
    final items = activePlaylist.items;
    final query = ref.watch(librarySearchQueryProvider);
    final browsingLibrary = activePlaylist.id == widget.queue.library.id;
    final browsingPlaybackQueue = activePlaylist.id == heniPlaybackQueueId;
    final canMultiSelect = !browsingLibrary && !browsingPlaybackQueue;
    var filteredEntries = [
      for (var i = 0; i < items.length; i += 1)
        if (_matchesQuery(items[i], query)) MapEntry(i, items[i]),
    ];
    if (_sortMode != _SongsSortMode.queue && !browsingPlaybackQueue) {
      filteredEntries.sort((a, b) => _compareEntries(a, b, _sortMode));
    }
    final selectedCount =
        filteredEntries
            .where((entry) => _selectedPaths.contains(entry.value.path))
            .length;

    if (_selectionMode) {
      _selectedPaths.removeWhere(
        (path) => !items.any((item) => item.path == path),
      );
    }

    final actionButtons =
        browsingLibrary
            ? <Widget>[
              OutlinedButton.icon(
                onPressed: widget.queue.isScanning ? null : widget.onRefreshLibrary,
                icon: Icon(
                  widget.queue.isScanning
                      ? Icons.sync_rounded
                      : Icons.refresh_rounded,
                  size: 16,
                ),
                label: Text(widget.queue.isScanning ? '刷新中' : '刷新'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onPickFolder,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('导入目录'),
              ),
              FilledButton.icon(
                onPressed: widget.onPickMedia,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加文件'),
              ),
            ]
            : browsingPlaybackQueue
            ? <Widget>[
              FilledButton.tonalIcon(
                onPressed:
                    widget.queue.currentItem == null
                        ? null
                        : () => widget.onSelectUiStyle(HeniUiStyle.scenery),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('回到播放中'),
              ),
            ]
            : <Widget>[
              OutlinedButton.icon(
                onPressed: () => widget.onManagePlaylist(activePlaylist),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('管理'),
              ),
              FilledButton.icon(
                onPressed: () => widget.onAddFromLibrary(activePlaylist.id),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加歌曲'),
              ),
            ];

    final totalDuration = items.fold<Duration>(
      Duration.zero,
      (acc, it) => acc + (it.duration ?? Duration.zero),
    );
    final totalLabel = _formatTotalDuration(totalDuration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryHeroBanner(
          palette: widget.palette,
          activePlaylist: activePlaylist,
          uiStyle: HeniUiStyle.library,
          browsingLibrary: browsingLibrary,
          browsingPlaybackQueue: browsingPlaybackQueue,
          itemCount: items.length,
          totalDurationLabel: totalLabel,
          actions: actionButtons,
          onSelectUiStyle: widget.onSelectUiStyle,
          libraryDirCount: widget.queue.libraryDirectories.length,
          isScanning: widget.queue.isScanning,
        ),
        SizedBox(height: widget.layout.contentGap),
        Expanded(
    child: _GlassPanel(
      radius: 22,
      fillColor: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.06),
        Colors.black.withValues(alpha: 0.26),
      ),
      borderColor: Colors.white.withValues(alpha: 0.09),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
            child: Row(
              children: [
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _InfoPill(
                      icon: Icons.search_rounded,
                      label: '筛出 ${filteredEntries.length} 首',
                    ),
                  ),
                if (_selectionMode)
                  _RefreshStatusBadge(
                    icon: Icons.done_all_rounded,
                    label: '已选 $selectedCount 首',
                    accent: true,
                  ),
                const Spacer(),
                if (_selectionMode) ...[
                  TextButton(
                    onPressed: items.isEmpty ? null : _selectAll,
                    child: const Text('全选'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: selectedCount == 0 ? null : _removeSelected,
                    child: Text('移除 $selectedCount 首'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _exitSelectionMode,
                    child: const Text('取消'),
                  ),
                ] else ...[
                  PopupMenuButton<_SongsSortMode>(
                    tooltip: '排序方式',
                    onSelected: (mode) {
                      setState(() {
                        _sortMode = mode;
                      });
                    },
                    itemBuilder:
                        (context) => [
                          for (final mode in _SongsSortMode.values)
                            PopupMenuItem<_SongsSortMode>(
                              value: mode,
                              child: Text(mode.label),
                            ),
                        ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 13,
                            color: _secondaryGlassText(emphasis: 0.96),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _sortMode.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontSize: 11.5,
                              color: _secondaryGlassText(emphasis: 0.96),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canMultiSelect) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _enterSelectionMode,
                      child: const Text('多选'),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Container(
            height: 32,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: _libraryLeadColumnWidth,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '曲目',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.46),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _libraryDurationColumnWidth,
                  child: Text(
                    '时长',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(width: _libraryActionColumnWidth),
              ],
            ),
          ),
          Expanded(
            child:
                filteredEntries.isEmpty
                    ? Center(
                      child: _SongsEmptyState(
                        title:
                            items.isEmpty
                                ? (browsingLibrary
                                    ? '曲库还是空的'
                                    : browsingPlaybackQueue
                                    ? '当前还没有播放队列'
                                    : '这个歌单还没有歌曲')
                                : '没有找到匹配的歌曲',
                        message:
                            items.isEmpty
                                ? (browsingLibrary
                                    ? '添加文件或导入文件夹，把本地音频视频整理进来。'
                                    : browsingPlaybackQueue
                                    ? '开始播放后，这里会显示当前这轮待播内容。'
                                    : '回到曲库挑几首喜欢的内容，慢慢把它养成自己的歌单。')
                                : '换个关键词试试，或者清空搜索继续浏览。',
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final itemIndex = entry.key;
                        final item = entry.value;
                        final selected = widget.queue.isCurrentItem(item);
                        return _LibraryRow(
                          item: item,
                          index: itemIndex,
                          selected: selected,
                          browsingLibrary: browsingLibrary,
                          browsingPlaybackQueue: browsingPlaybackQueue,
                          playlists: widget.queue.playlists,
                          selectionMode: _selectionMode,
                          checked: _selectedPaths.contains(item.path),
                          onPlay:
                              () =>
                                  _selectionMode
                                      ? _toggleItem(item)
                                      : widget.onPlayIndex(itemIndex),
                          onAddToPlaylist:
                              (playlistId) =>
                                  widget.onAddToPlaylist(playlistId, item),
                          onRemoveFromPlaylist:
                              () =>
                                  browsingPlaybackQueue
                                      ? widget.onRemoveFromPlaybackQueue(
                                        itemIndex,
                                      )
                                      : widget.onRemoveFromPlaylist(
                                        activePlaylist.id,
                                        item,
                                      ),
                          onToggleSelect: () => _toggleItem(item),
                        );
                      },
                    ),
          ),
        ],
      ),
    ),
        ),
      ],
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedPaths.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleItem(MediaItem item) {
    setState(() {
      if (!_selectedPaths.remove(item.path)) {
        _selectedPaths.add(item.path);
      }
    });
  }

  void _selectAll() {
    final items = widget.queue.activePlaylist.items;
    setState(() {
      _selectedPaths
        ..clear()
        ..addAll(items.map((item) => item.path));
    });
  }

  void _removeSelected() {
    final playlistId = widget.queue.activePlaylist.id;
    final selected = [
      for (final item in widget.queue.activePlaylist.items)
        if (_selectedPaths.contains(item.path)) item,
    ];
    if (selected.isEmpty) {
      return;
    }
    for (final item in selected) {
      widget.onRemoveFromPlaylist(playlistId, item);
    }
    _exitSelectionMode();
  }

  int _compareEntries(
    MapEntry<int, MediaItem> a,
    MapEntry<int, MediaItem> b,
    _SongsSortMode mode,
  ) {
    return switch (mode) {
      _SongsSortMode.queue => a.key.compareTo(b.key),
      _SongsSortMode.title => a.value.title.toLowerCase().compareTo(
        b.value.title.toLowerCase(),
      ),
      _SongsSortMode.kind => a.value.kind.name.compareTo(b.value.kind.name),
      _SongsSortMode.source => p
          .dirname(a.value.path)
          .toLowerCase()
          .compareTo(p.dirname(b.value.path).toLowerCase()),
    };
  }

  bool _matchesQuery(MediaItem item, String query) {
    if (query.isEmpty) {
      return true;
    }

    final normalized = query.toLowerCase();
    return item.title.toLowerCase().contains(normalized) ||
        item.path.toLowerCase().contains(normalized) ||
        p.dirname(item.path).toLowerCase().contains(normalized);
  }
}

class _LibraryRow extends ConsumerStatefulWidget {
  const _LibraryRow({
    required this.item,
    required this.index,
    required this.selected,
    required this.browsingLibrary,
    required this.browsingPlaybackQueue,
    required this.playlists,
    required this.selectionMode,
    required this.checked,
    required this.onPlay,
    required this.onAddToPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onToggleSelect,
  });

  final MediaItem item;
  final int index;
  final bool selected;
  final bool browsingLibrary;
  final bool browsingPlaybackQueue;
  final List<HeniPlaylist> playlists;
  final bool selectionMode;
  final bool checked;
  final VoidCallback onPlay;
  final ValueChanged<String> onAddToPlaylist;
  final VoidCallback onRemoveFromPlaylist;
  final VoidCallback onToggleSelect;

  @override
  ConsumerState<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends ConsumerState<_LibraryRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = widget.selected;
    final checked = widget.checked;
    final hoverOrSelected = playing || _hovered || checked;
    final evenRow = widget.index.isEven;
    final rowColor =
        playing
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : checked
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.075)
            : _hovered
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: evenRow ? 0.03 : 0.018);
    final borderColor =
        playing
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
            : checked
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
            : _hovered
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04);
    final leadingColor =
        playing
            ? heniAccentOnGlass(Theme.of(context).colorScheme.primary)
            : checked
            ? Colors.white.withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: playing ? 1.0 : (_hovered ? 1.006 : 1.0),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              if (playing || checked)
                Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: playing ? 0.1 : 0.06)
              else
                Colors.white.withValues(alpha: evenRow ? 0.012 : 0.0),
              rowColor,
              rowColor,
            ],
            stops: const [0.0, 0.08, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (hoverOrSelected)
              BoxShadow(
                color: Colors.black.withValues(
                  alpha:
                      playing
                          ? 0.14
                          : checked
                          ? 0.10
                          : 0.07,
                ),
                blurRadius: playing ? 14 : 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: playing ? 6 : 10,
              bottom: playing ? 6 : 10,
              child: AnimatedContainer(
                duration: _hoverDuration,
                width:
                    playing
                        ? 4
                        : checked
                            ? 3
                            : _hovered
                                ? 2
                                : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color:
                      playing || checked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.22),
                  boxShadow: [
                    if (playing)
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 0,
              child: AnimatedOpacity(
                duration: _hoverDuration,
                opacity: hoverOrSelected ? 0.14 : 0.08,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onPlay,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _libraryLeadColumnWidth,
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: _hoverDuration,
                              child:
                                  widget.selectionMode
                                      ? Checkbox(
                                        key: ValueKey(
                                          'check-${widget.index}-${widget.checked}',
                                        ),
                                        value: widget.checked,
                                        onChanged:
                                            (_) => widget.onToggleSelect(),
                                      )
                                      : hoverOrSelected
                                      ? widget.selected
                                          ? SizedBox(
                                            key: ValueKey(
                                              'wave-${widget.index}',
                                            ),
                                            width: 18,
                                            height: 18,
                                            child: Center(
                                              child: StreamBuilder<bool>(
                                                stream:
                                                    ref
                                                        .read(
                                                          playbackEngineProvider,
                                                        )
                                                        .playing,
                                                initialData: false,
                                                builder: (context, snap) {
                                                  return _NowPlayingWave(
                                                    color: leadingColor,
                                                    active: snap.data ?? false,
                                                  );
                                                },
                                              ),
                                            ),
                                          )
                                          : Icon(
                                            Icons.play_arrow_rounded,
                                            key: ValueKey(
                                              'icon-${widget.index}-$hoverOrSelected',
                                            ),
                                            size: 18,
                                            color: leadingColor,
                                          )
                                      : SizedBox(
                                        key: ValueKey('index-${widget.index}'),
                                        width: 26,
                                        child: Text(
                                          '${widget.index + 1}',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.38,
                                                ),
                                              ),
                                        ),
                                      ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: _hoverDuration,
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    playing
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.14)
                                        : checked
                                        ? Colors.white.withValues(alpha: 0.14)
                                        : Colors.white.withValues(
                                          alpha: hoverOrSelected ? 0.16 : 0.07,
                                        ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.item.kind == MediaKind.video
                                    ? Icons.movie_outlined
                                    : Icons.music_note_outlined,
                                size: 14,
                                color:
                                    playing
                                        ? heniAccentOnGlass(
                                          Theme.of(context).colorScheme.primary,
                                        )
                                        : Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14.5,
                                fontWeight:
                                    playing ? FontWeight.w800 : FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.dirname(widget.item.path),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                color:
                                    checked
                                        ? Colors.white.withValues(alpha: 0.58)
                                        : Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _libraryDurationColumnWidth,
                        child: Text(
                          _formatDuration(widget.item.duration),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontFeatures: const [
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: _libraryActionColumnWidth,
                        child:
                            widget.selectionMode
                                ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedContainer(
                                    duration: _hoverDuration,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          widget.checked
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.14)
                                              : Colors.white.withValues(
                                                alpha: 0.04,
                                              ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color:
                                            widget.checked
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.22)
                                                : Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.checked ? '已选择' : '选择',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color:
                                                widget.checked
                                                    ? heniAccentOnGlass(
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    )
                                                    : Colors.white.withValues(
                                                      alpha: 0.42,
                                                    ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                )
                                : widget.browsingLibrary
                                ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedOpacity(
                                    duration: _hoverDuration,
                                    opacity: hoverOrSelected ? 1 : 0.82,
                                    child: _AddToPlaylistMenu(
                                      playlists: widget.playlists,
                                      onSelected: widget.onAddToPlaylist,
                                    ),
                                  ),
                                )
                                : Align(
                                  alignment: Alignment.centerLeft,
                                  child: Tooltip(
                                    message:
                                        widget.browsingPlaybackQueue
                                            ? '从当前播放列表移除'
                                            : '从当前歌单移除',
                                    child: _InlineActionButton(
                                      icon: Icons.remove_circle_outline,
                                      active: hoverOrSelected,
                                      danger: true,
                                      onPressed: widget.onRemoveFromPlaylist,
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

String _formatDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }

  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _AddToPlaylistMenu extends StatelessWidget {
  const _AddToPlaylistMenu({required this.playlists, required this.onSelected});

  final List<HeniPlaylist> playlists;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Tooltip(
        message: '先新建歌单',
        child: OutlinedButton(onPressed: null, child: const Text('加入歌单')),
      );
    }

    return PopupMenuButton<String>(
      tooltip: '加入歌单',
      onSelected: onSelected,
      itemBuilder:
          (context) => [
            for (final playlist in playlists)
              PopupMenuItem<String>(
                value: playlist.id,
                child: Text(playlist.name),
              ),
          ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.26),
          ),
        ),
        child: Text(
          '加入歌单',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: heniAccentOnGlass(Theme.of(context).colorScheme.primary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InlineActionButton extends StatefulWidget {
  const _InlineActionButton({
    required this.icon,
    required this.active,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_InlineActionButton> createState() => _InlineActionButtonState();
}

class _InlineActionButtonState extends State<_InlineActionButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;
    final foreground =
        widget.danger
            ? const Color(0xFFFF8C8C)
            : Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _hoverDuration,
        decoration: BoxDecoration(
          color:
              highlighted
                  ? foreground.withValues(alpha: widget.danger ? 0.14 : 0.16)
                  : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                highlighted
                    ? foreground.withValues(alpha: widget.danger ? 0.24 : 0.22)
                    : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: IconButton(
          onPressed: widget.onPressed,
          style: IconButton.styleFrom(
            foregroundColor:
                highlighted ? foreground : Colors.white.withValues(alpha: 0.62),
            fixedSize: const Size.square(_denseIconButtonSize),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(widget.icon, size: _compactIconSize),
        ),
      ),
    );
  }
}

class _AddFromLibraryDialog extends StatefulWidget {
  const _AddFromLibraryDialog({required this.queue});

  final PlaybackQueueState queue;

  @override
  State<_AddFromLibraryDialog> createState() => _AddFromLibraryDialogState();
}

class _AddFromLibraryDialogState extends State<_AddFromLibraryDialog> {
  final _queryController = TextEditingController();
  final _selectedPaths = <String>{};
  var _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.queue.activePlaylist;
    final existingPaths =
        target.items.map((item) => item.path.toLowerCase()).toSet();
    final query = _query.trim().toLowerCase();
    final candidates =
        widget.queue.library.items.where((item) {
          if (existingPaths.contains(item.path.toLowerCase())) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return item.title.toLowerCase().contains(query) ||
              item.path.toLowerCase().contains(query);
        }).toList();

    return _HeniDialog(
      title: Text('从曲库添加到“${target.name}”'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                hintText: '搜索曲库',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  candidates.isEmpty
                      ? const Center(child: Text('没有可添加的歌曲'))
                      : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final item = candidates[index];
                          final selected = _selectedPaths.contains(item.path);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    selected
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.26)
                                        : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: selected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedPaths.add(item.path);
                                  } else {
                                    _selectedPaths.remove(item.path);
                                  }
                                });
                              },
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                item.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondary: _InfoPill(
                                icon:
                                    item.kind == MediaKind.video
                                        ? Icons.movie_outlined
                                        : Icons.graphic_eq,
                                label:
                                    item.kind == MediaKind.video ? '视频' : '音频',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              candidates.isEmpty
                  ? null
                  : () {
                    setState(() {
                      _selectedPaths
                        ..clear()
                        ..addAll(candidates.map((item) => item.path));
                    });
                  },
          child: const Text('全选当前列表'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              _selectedPaths.isEmpty
                  ? null
                  : () {
                    final selectedItems = [
                      for (final item in widget.queue.library.items)
                        if (_selectedPaths.contains(item.path)) item,
                    ];
                    Navigator.of(context).pop(selectedItems);
                  },
          child: Text('添加 ${_selectedPaths.length} 首'),
        ),
      ],
    );
  }
}

class _BottomPlayerBar extends ConsumerWidget {
  const _BottomPlayerBar({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
    required this.audioExport,
    required this.queue,
    required this.engine,
    required this.layout,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onCyclePlaybackMode,
    required this.onShowPlaybackQueue,
    required this.onExtractAudio,
    required this.onCancelAudioExport,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final AudioExportState audioExport;
  final PlaybackQueueState queue;
  final PlaybackEngine engine;
  final _ShellLayout layout;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback onShowPlaybackQueue;
  final VoidCallback? onExtractAudio;
  final VoidCallback onCancelAudioExport;
  final ValueChanged<double> onPersistVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusMode = ref.watch(focusModeProvider);
    final compactBottom = focusMode;

    return _ShellBand(
      palette: palette,
      margin: EdgeInsets.fromLTRB(
        layout.topHorizontalMargin,
        0,
        layout.topHorizontalMargin,
        compactBottom ? 6 : layout.sidebarPadding,
      ),
      padding: EdgeInsets.fromLTRB(
        layout.quiet ? 14 : 18,
        compactBottom ? 6 : (layout.quiet ? 8 : 10),
        layout.quiet ? 14 : 18,
        compactBottom ? 6 : (layout.quiet ? 8 : 10),
      ),
      height:
          compactBottom
              ? (layout.quiet ? 64 : 72)
              : layout.bottomHeight,
      emphasis: 0.9,
      child:
          compactBottom
              ? _CompactBottomBar(
                palette: palette,
                currentMedia: currentMedia,
                engine: engine,
                queue: queue,
                onPreviousTrack: onPreviousTrack,
                onNextTrack: onNextTrack,
                onCyclePlaybackMode: onCyclePlaybackMode,
                onShowPlaybackQueue: onShowPlaybackQueue,
                onPersistVolume: onPersistVolume,
              )
              : Row(
                children: [
                  _NowPlayingSummary(
                    palette: palette,
                    currentMedia: currentMedia,
                    mediaProbe: mediaProbe,
                    engine: engine,
                    layout: layout,
                  ),
                  SizedBox(width: layout.quiet ? 10 : 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TransportControls(
                          engine: engine,
                          onPreviousTrack: onPreviousTrack,
                          onNextTrack: onNextTrack,
                        ),
                        const SizedBox(height: 4),
                        _ProgressWithTime(engine: engine, palette: palette),
                      ],
                    ),
                  ),
                  SizedBox(width: layout.quiet ? 10 : 16),
                  _UtilityControls(
                    palette: palette,
                    mode: queue.playbackMode,
                    engine: engine,
                    state: audioExport,
                    queue: queue,
                    layout: layout,
                    sourceDuration: mediaProbe.when(
                      data: (probe) => probe?.duration,
                      error: (error, stackTrace) => null,
                      loading: () => null,
                    ),
                    onShowPlaybackQueue: onShowPlaybackQueue,
                    onCyclePlaybackMode: onCyclePlaybackMode,
                    onExtract: onExtractAudio,
                    onCancel: onCancelAudioExport,
                    onPersistVolume: onPersistVolume,
                  ),
                ],
              ),
    );
  }
}

class _CompactBottomBar extends StatelessWidget {
  const _CompactBottomBar({
    required this.palette,
    required this.currentMedia,
    required this.engine,
    required this.queue,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onCyclePlaybackMode,
    required this.onShowPlaybackQueue,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final PlaybackEngine engine;
  final PlaybackQueueState queue;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback onShowPlaybackQueue;
  final ValueChanged<double> onPersistVolume;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: false,
      builder: (context, snap) {
        final isPlaying = snap.data ?? false;
        return Row(
          children: [
            _NowPlayingArtwork(
              size: 40,
              isVideo: currentMedia?.kind == MediaKind.video,
              isPlaying: isPlaying,
              hasMedia: currentMedia != null,
              palette: palette,
              engine: engine,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentMedia?.title ?? '未播放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ProgressWithTime(engine: engine, palette: palette),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: '上一首',
              onPressed: onPreviousTrack,
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 22,
            ),
            IconButton.filled(
              tooltip: isPlaying ? '暂停' : '播放',
              onPressed: () {
                if (isPlaying) {
                  unawaited(engine.pause());
                } else {
                  unawaited(engine.play());
                }
              },
              icon: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 22,
              ),
            ),
            IconButton(
              tooltip: '下一首',
              onPressed: onNextTrack,
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 22,
            ),
            const SizedBox(width: 6),
            _VolumeMenuButton(
              engine: engine,
              palette: palette,
              onVolumeChanged: onPersistVolume,
            ),
            IconButton(
              tooltip: '播放队列',
              onPressed: onShowPlaybackQueue,
              icon: const Icon(Icons.queue_music_rounded),
              iconSize: 20,
            ),
          ],
        );
      },
    );
  }
}

class _NowPlayingSummary extends StatelessWidget {
  const _NowPlayingSummary({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
    required this.engine,
    required this.layout,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final PlaybackEngine engine;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaKey = currentMedia?.path ?? 'empty';

    return SizedBox(
      width:
          layout.quiet
              ? 236
              : layout.compact
              ? 268
              : 300,
      child: StreamBuilder<bool>(
        stream: engine.playing,
        initialData: false,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? false;

          final discSize = layout.quiet ? 54.0 : 62.0;
          final isVideo = currentMedia?.kind == MediaKind.video;

          return Row(
            children: [
              _NowPlayingArtwork(
                size: discSize,
                isVideo: isVideo,
                isPlaying: isPlaying,
                hasMedia: currentMedia != null,
                palette: palette,
                engine: engine,
              ),
              SizedBox(width: layout.quiet ? 10 : 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _contentSwitchDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.16),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey(mediaKey),
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: _hoverDuration,
                        style:
                            theme.textTheme.labelMedium?.copyWith(
                              color: heniAccentOnGlass(
                                palette.accent,
                                alpha: isPlaying ? 0.95 : 0.78,
                              ),
                              fontWeight: FontWeight.w800,
                            ) ??
                            const TextStyle(),
                        child: Text(
                          currentMedia == null ? '等待播放' : '正在播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currentMedia?.title ?? '未播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (layout.showNowPlayingDetails) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentMedia == null
                              ? '选择一首本地音频或视频，开始播放'
                              : currentMedia!.kind == MediaKind.video
                              ? '本地视频'
                              : '本地音频',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NowPlayingArtwork extends StatefulWidget {
  const _NowPlayingArtwork({
    required this.size,
    required this.isVideo,
    required this.isPlaying,
    required this.hasMedia,
    required this.palette,
    required this.engine,
  });

  final double size;
  final bool isVideo;
  final bool isPlaying;
  final bool hasMedia;
  final HeniPalette palette;
  final PlaybackEngine engine;

  @override
  State<_NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<_NowPlayingArtwork>
    with SingleTickerProviderStateMixin {
  late AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isPlaying) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingArtwork old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!widget.isPlaying && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ringSize = widget.size + 12;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final pulse = widget.isPlaying ? _breath.value : 0.0;
              return Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.seed.withValues(
                        alpha:
                            widget.isPlaying ? 0.22 + 0.18 * pulse : 0.10,
                      ),
                      blurRadius: 18 + 8 * pulse,
                      spreadRadius: widget.isPlaying ? 1 : 0,
                    ),
                  ],
                ),
              );
            },
          ),
          StreamBuilder<Duration>(
            stream: widget.engine.position,
            initialData: Duration.zero,
            builder: (context, posSnap) {
              return StreamBuilder<Duration>(
                stream: widget.engine.duration,
                initialData: Duration.zero,
                builder: (context, durSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final dur = durSnap.data ?? Duration.zero;
                  final fraction =
                      dur.inMilliseconds <= 0
                          ? 0.0
                          : (pos.inMilliseconds / dur.inMilliseconds).clamp(
                            0.0,
                            1.0,
                          );
                  return SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CustomPaint(
                      painter: _ArtworkRingPainter(
                        fraction: fraction,
                        seedColor: p.seed,
                        accentColor: p.accent,
                        active: widget.hasMedia,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          widget.isVideo
              ? Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    p.seed.withValues(
                      alpha: widget.isPlaying ? 0.24 : 0.18,
                    ),
                    p.surfaceAlt,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: p.seed.withValues(
                      alpha: widget.isPlaying ? 0.42 : 0.32,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.movie_outlined,
                  size: widget.size * 0.42,
                ),
              )
              : _VinylDisc(
                size: widget.size,
                spinning: widget.isPlaying,
                palette: p,
              ),
        ],
      ),
    );
  }
}

class _ArtworkRingPainter extends CustomPainter {
  const _ArtworkRingPainter({
    required this.fraction,
    required this.seedColor,
    required this.accentColor,
    required this.active,
  });

  final double fraction;
  final Color seedColor;
  final Color accentColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: active ? 0.12 : 0.07);
    canvas.drawCircle(center, radius, trackPaint);

    if (!active || fraction <= 0) return;

    final sweep = 2 * math.pi * fraction;
    final start = -math.pi / 2;

    final progressPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: [
              seedColor,
              Color.lerp(seedColor, accentColor, 0.55)!,
              accentColor,
              seedColor,
            ],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, progressPaint);

    final glow =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = seedColor.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(rect, start, sweep, false, glow);
  }

  @override
  bool shouldRepaint(covariant _ArtworkRingPainter old) {
    return old.fraction != fraction ||
        old.seedColor != seedColor ||
        old.accentColor != accentColor ||
        old.active != active;
  }
}

class _VinylDisc extends StatefulWidget {
  const _VinylDisc({
    required this.size,
    required this.spinning,
    required this.palette,
  });

  final double size;
  final bool spinning;
  final HeniPalette palette;

  @override
  State<_VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<_VinylDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _VinylDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning != old.spinning) {
      if (widget.spinning) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final p = widget.palette;
    final labelSize = s * 0.42;
    final centerHole = s * 0.07;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF050505)],
                stops: [0.0, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.seed.withValues(alpha: widget.spinning ? 0.32 : 0.18),
                  blurRadius: widget.spinning ? 18 : 10,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _VinylGroovesPainter(),
              child: Center(
                child: Container(
                  width: labelSize,
                  height: labelSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(p.accent, p.seed, 0.3)!,
                        p.seed,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.42),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: centerHole,
                      height: centerHole,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF050505),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final groovePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.white.withValues(alpha: 0.05);

    for (var r = maxRadius * 0.55; r < maxRadius - 1; r += 2) {
      canvas.drawCircle(center, r, groovePaint);
    }

    final highlightPaint =
        Paint()
          ..shader = SweepGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.18, 0.4, 0.62, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.color});

  final Color color;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * 2 * math.pi;
        final heights = [
          0.28 + 0.72 * ((math.sin(t * 1.4 + 0.0) + 1) / 2),
          0.28 + 0.72 * ((math.sin(t * 0.9 + 1.3) + 1) / 2),
          0.28 + 0.72 * ((math.sin(t * 1.7 + 2.5) + 1) / 2),
          0.28 + 0.72 * ((math.sin(t * 1.1 + 0.7) + 1) / 2),
        ];
        const barW = 3.5;
        const maxH = 22.0;
        const gap = 3.0;

        return SizedBox(
          width: barW * 4 + gap * 3,
          height: maxH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Container(
                  width: barW,
                  height: (heights[i] * maxH).clamp(3.5, maxH),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _UtilityControls extends StatelessWidget {
  const _UtilityControls({
    required this.palette,
    required this.mode,
    required this.engine,
    required this.state,
    required this.queue,
    required this.layout,
    required this.sourceDuration,
    required this.onShowPlaybackQueue,
    required this.onCyclePlaybackMode,
    required this.onExtract,
    required this.onCancel,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final HeniPlaybackMode mode;
  final PlaybackEngine engine;
  final AudioExportState state;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final Duration? sourceDuration;
  final VoidCallback onShowPlaybackQueue;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback? onExtract;
  final VoidCallback onCancel;
  final ValueChanged<double> onPersistVolume;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CurrentQueueButton(
          count: queue.playbackQueue.items.length,
          hasCurrent: queue.currentItem != null,
          onPressed: onShowPlaybackQueue,
        ),
        const SizedBox(width: 6),
        _PlaybackModeIconButton(mode: mode, onPressed: onCyclePlaybackMode),
        const SizedBox(width: 6),
        _VolumeMenuButton(
          engine: engine,
          palette: palette,
          onVolumeChanged: onPersistVolume,
        ),
        const SizedBox(width: 6),
        _ExportActions(
          state: state,
          sourceDuration: sourceDuration,
          onExtract: onExtract,
          onCancel: onCancel,
        ),
      ],
    );
  }
}

class _CurrentQueueButton extends StatelessWidget {
  const _CurrentQueueButton({
    required this.count,
    required this.hasCurrent,
    required this.onPressed,
  });

  final int count;
  final bool hasCurrent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: count == 0 ? '当前播放列表为空' : '当前播放列表 $count 首',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              hasCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(999),
        ),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_regularIconButtonSize),
            padding: EdgeInsets.zero,
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.queue_music_rounded, size: 20),
              if (count > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.state,
    required this.sourceDuration,
    required this.onExtract,
    required this.onCancel,
  });

  final AudioExportState state;
  final Duration? sourceDuration;
  final VoidCallback? onExtract;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = state.fraction(sourceDuration);

    if (state.isRunning) {
      return SizedBox(
        width: 92,
        child: Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            IconButton(
              tooltip: '取消导出',
              onPressed: onCancel,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(_regularIconButtonSize),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
            ),
          ],
        ),
      );
    }

    final statusIcon = switch (state.status) {
      AudioExportStatus.completed => Icons.check_circle_outline,
      AudioExportStatus.failed => Icons.error_outline,
      AudioExportStatus.cancelled => Icons.cancel_outlined,
      AudioExportStatus.idle => Icons.audio_file_outlined,
      AudioExportStatus.running => Icons.audio_file_outlined,
    };
    final tooltip = switch (state.status) {
      AudioExportStatus.completed => '音频已导出',
      AudioExportStatus.failed => state.errorMessage ?? '导出失败',
      AudioExportStatus.cancelled => '已取消导出',
      AudioExportStatus.idle => '导出 FLAC',
      AudioExportStatus.running => '导出中',
    };

    return IconButton(
      tooltip: tooltip,
      onPressed: state.status == AudioExportStatus.idle ? onExtract : null,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(_regularIconButtonSize),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(statusIcon, size: 20),
    );
  }
}

class _VolumeMenuButton extends StatelessWidget {
  const _VolumeMenuButton({
    required this.engine,
    required this.palette,
    required this.onVolumeChanged,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size.zero),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      alignmentOffset: const Offset(-200, -56),
      menuChildren: [
        _VolumeBubble(
          engine: engine,
          palette: palette,
          onVolumeChanged: onVolumeChanged,
        ),
      ],
      builder: (context, controller, child) {
        return StreamBuilder<double>(
          stream: engine.volume,
          initialData: engine.currentVolume,
          builder: (context, snapshot) {
            final volume =
                (snapshot.data ?? engine.currentVolume)
                    .clamp(0, 100)
                    .toDouble();
            final icon = switch (volume.round()) {
              <= 0 => Icons.volume_off_rounded,
              < 50 => Icons.volume_down_rounded,
              _ => Icons.volume_up_rounded,
            };

            return IconButton(
              tooltip: '音量 ${volume.round()}',
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: Icon(icon),
            );
          },
        );
      },
    );
  }
}

class _VolumeBubble extends StatefulWidget {
  const _VolumeBubble({
    required this.engine,
    required this.palette,
    required this.onVolumeChanged,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final ValueChanged<double> onVolumeChanged;

  @override
  State<_VolumeBubble> createState() => _VolumeBubbleState();
}

class _VolumeBubbleState extends State<_VolumeBubble> {
  late double _volume;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _volume = widget.engine.currentVolume.clamp(0, 100).toDouble();
    _sub = widget.engine.volume.listen((v) {
      if (!mounted) return;
      setState(() => _volume = v.clamp(0, 100).toDouble());
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _set(double v) {
    final clamped = v.clamp(0.0, 100.0).toDouble();
    setState(() => _volume = clamped);
    unawaited(widget.engine.setVolume(clamped));
    widget.onVolumeChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final blended = Color.lerp(p.seed, p.accent, 0.55)!;

    return Container(
      width: 244,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Colors.white.withValues(alpha: 0.06),
          Colors.black.withValues(alpha: 0.86),
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: p.seed.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: p.seed.withValues(alpha: 0.16),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            switch (_volume.round()) {
              <= 0 => Icons.volume_off_rounded,
              < 50 => Icons.volume_down_rounded,
              _ => Icons.volume_up_rounded,
            },
            size: 18,
            color: Colors.white.withValues(alpha: 0.86),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                void updateFromX(double x) {
                  _set((x / w).clamp(0.0, 1.0) * 100);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) => updateFromX(d.localPosition.dx),
                  onHorizontalDragUpdate:
                      (d) => updateFromX(d.localPosition.dx),
                  child: SizedBox(
                    height: 30,
                    child: CustomPaint(
                      painter: _VolumeBarPainter(
                        fraction: _volume / 100,
                        seedColor: p.seed,
                        accentColor: blended,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              _volume.round().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeBarPainter extends CustomPainter {
  const _VolumeBarPainter({
    required this.fraction,
    required this.seedColor,
    required this.accentColor,
  });

  final double fraction;
  final Color seedColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackH = 4.0;
    final cy = size.height / 2;
    final track = Rect.fromLTWH(0, cy - trackH / 2, size.width, trackH);
    final radius = const Radius.circular(4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final f = fraction.clamp(0.0, 1.0);
    if (f > 0) {
      final fillW = size.width * f;
      final fillRect = Rect.fromLTWH(0, cy - trackH / 2, fillW, trackH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, radius),
        Paint()
          ..shader = LinearGradient(
            colors: [seedColor, accentColor],
          ).createShader(Rect.fromLTWH(0, 0, size.width, trackH)),
      );

      final thumbX = fillW.clamp(0.0, size.width);
      final center = Offset(thumbX, cy);
      canvas.drawCircle(
        center,
        9,
        Paint()
          ..color = seedColor.withValues(alpha: 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(center, 6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeBarPainter old) {
    return old.fraction != fraction ||
        old.seedColor != seedColor ||
        old.accentColor != accentColor;
  }
}

class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.queue});

  final PlaybackQueueState queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '基础设置',
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => _SettingsDialog(queue: queue),
        );
      },
      icon: const Icon(Icons.tune_outlined),
    );
  }
}

class _ManagePlaylistDialog extends StatefulWidget {
  const _ManagePlaylistDialog({required this.playlist});

  final HeniPlaylist playlist;

  @override
  State<_ManagePlaylistDialog> createState() => _ManagePlaylistDialogState();
}

class _ManagePlaylistDialogState extends State<_ManagePlaylistDialog> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      for (final item in widget.playlist.items)
        if (_matchesQuery(item, _query)) item,
    ];

    return _HeniDialog(
      title: Text('管理“${widget.playlist.name}”'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: '搜索歌单里的歌曲',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selected.isEmpty
                    ? '勾选想从这个歌单移除的歌曲'
                    : '已选择 ${_selected.length} 首',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child:
                  items.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            '没有找到匹配的歌曲',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.52),
                            ),
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final key = _itemKey(item);
                          final selected = _selected.contains(key);

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _toggle(item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? theme.colorScheme.primary.withValues(
                                          alpha: 0.16,
                                        )
                                        : Colors.white.withValues(alpha: 0.035),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color:
                                      selected
                                          ? theme.colorScheme.primary
                                              .withValues(alpha: 0.26)
                                          : Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggle(item),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    item.kind == MediaKind.video
                                        ? Icons.movie_outlined
                                        : Icons.music_note_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.path,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.46,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop([
                    for (final item in widget.playlist.items)
                      if (_selected.contains(_itemKey(item))) item,
                  ]),
          child: const Text('移除已选'),
        ),
      ],
    );
  }

  void _toggle(MediaItem item) {
    final key = _itemKey(item);
    setState(() {
      if (!_selected.remove(key)) {
        _selected.add(key);
      }
    });
  }

  bool _matchesQuery(MediaItem item, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return item.title.toLowerCase().contains(normalized) ||
        item.path.toLowerCase().contains(normalized);
  }

  String _itemKey(MediaItem item) => item.path.toLowerCase();
}

class _PlaybackQueueDialog extends ConsumerStatefulWidget {
  const _PlaybackQueueDialog();

  @override
  ConsumerState<_PlaybackQueueDialog> createState() =>
      _PlaybackQueueDialogState();
}

class _PlaybackQueueDialogState extends ConsumerState<_PlaybackQueueDialog> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playbackQueueControllerProvider);
    final theme = Theme.of(context);
    final allItems = queue.playbackQueue.items;
    final items =
        allItems.where((item) {
          if (_query.isEmpty) {
            return true;
          }
          final normalized = _query.toLowerCase();
          return item.title.toLowerCase().contains(normalized) ||
              item.path.toLowerCase().contains(normalized);
        }).toList();
    final current = queue.currentItem;

    return _HeniDialog(
      title: const Text('当前播放列表'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.library_music_outlined,
                        label:
                            '来源 ${queue.playlistById(queue.playbackSourceId).name}',
                      ),
                      _InfoPill(
                        icon: Icons.queue_music_rounded,
                        label: '${allItems.length} 首待播',
                      ),
                    ],
                  ),
                ),
                if (current != null)
                  Flexible(
                    child: _RefreshStatusBadge(
                      icon: Icons.graphic_eq,
                      label: '当前 ${current.title}',
                      accent: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: '搜索当前播放列表',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child:
                  items.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 44),
                          child: Text(
                            '播放列表会在你点击歌曲开始播放后生成',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final actualIndex = allItems.indexOf(item);
                          final isCurrent = actualIndex == queue.currentIndex;

                          return _PlaybackQueueRow(
                            item: item,
                            index: index,
                            isCurrent: isCurrent,
                            onPlay: () {
                              Navigator.of(context).pop();
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .playQueueIndex(actualIndex),
                              );
                            },
                            onRemove: () {
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .removePlaybackQueueItemAt(actualIndex),
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _PlaybackQueueRow extends ConsumerStatefulWidget {
  const _PlaybackQueueRow({
    required this.item,
    required this.index,
    required this.isCurrent,
    required this.onPlay,
    required this.onRemove,
  });

  final MediaItem item;
  final int index;
  final bool isCurrent;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  ConsumerState<_PlaybackQueueRow> createState() => _PlaybackQueueRowState();
}

class _PlaybackQueueRowState extends ConsumerState<_PlaybackQueueRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ref.watch(activePaletteProvider);
    final active = widget.isCurrent;
    final emphasized = active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _hoverDuration,
        decoration: BoxDecoration(
          color:
              active
                  ? palette.seed.withValues(alpha: 0.16)
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                active
                    ? palette.seed.withValues(alpha: 0.32)
                    : _hovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: [
            if (emphasized)
              BoxShadow(
                color:
                    active
                        ? palette.seed.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.1),
                blurRadius: active ? 18 : 14,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onPlay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
          children: [
            SizedBox(
              width: 28,
              child: AnimatedSwitcher(
                duration: _hoverDuration,
                child:
                    active
                        ? SizedBox(
                          key: ValueKey('queue-wave-${widget.index}'),
                          width: 18,
                          height: 18,
                          child: Center(
                            child: StreamBuilder<bool>(
                              stream: ref.read(playbackEngineProvider).playing,
                              initialData: false,
                              builder: (context, snap) {
                                return _NowPlayingWave(
                                  color: palette.seed,
                                  active: snap.data ?? false,
                                );
                              },
                            ),
                          ),
                        )
                        : emphasized
                        ? Icon(
                          Icons.play_arrow_rounded,
                          key: ValueKey(
                            'queue-icon-${widget.index}-$emphasized',
                          ),
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.72),
                        )
                        : Text(
                          '${widget.index + 1}',
                          key: ValueKey('queue-index-${widget.index}'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.46),
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: _hoverDuration,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    active
                        ? palette.seed.withValues(alpha: 0.18)
                        : Colors.white.withValues(
                          alpha: emphasized ? 0.14 : 0.08,
                        ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.item.kind == MediaKind.video
                    ? Icons.movie_outlined
                    : Icons.music_note_outlined,
                size: 16,
                color:
                    active
                        ? palette.seed
                        : Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                      color:
                          active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.dirname(widget.item.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.46),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: '从当前播放列表移除',
              child: _InlineActionButton(
                icon: Icons.remove_circle_outline,
                active: emphasized,
                danger: true,
                onPressed: widget.onRemove,
              ),
            ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog({required this.queue});

  final PlaybackQueueState queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackQueueControllerProvider.notifier);
    final theme = Theme.of(context);

    return _HeniDialog(
      title: const Text('基础设置'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SettingsTile(
              title: '递归扫描文件夹',
              subtitle: '导入目录时自动向下读取子目录中的媒体文件。',
              value: queue.recursiveScan,
              onChanged: (value) => controller.setRecursiveScan(value),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              title: '包含视频文件',
              subtitle: '在曲库与歌单里一起管理本地视频内容。',
              value: queue.includeVideo,
              onChanged: (value) => controller.setIncludeVideo(value),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              title: '加载后自动播放',
              subtitle: '导入完成后，自动开始播放当前队列中的内容。',
              value: queue.autoplayOnLoad,
              onChanged: (value) => controller.setAutoplayOnLoad(value),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    queue.isScanning
                        ? null
                        : () {
                          Navigator.of(context).pop();
                          unawaited(controller.refreshLibrary());
                        },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(queue.isScanning ? '刷新中' : '立即刷新曲库'),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前曲库目录 ${queue.libraryDirectories.length} 个，曲库内容 ${queue.library.items.length} 首。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CreatePlaylistResult {
  const _CreatePlaylistResult({required this.name});

  final String name;
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HeniDialog(
      title: const Text('新建歌单'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '歌单名称',
            helperText: '创建后可从曲库加入歌曲，不复制源文件',
          ),
          onSubmitted: _submit,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(_CreatePlaylistResult(name: name));
  }
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.actionText,
    this.maxLines = 1,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final String actionText;
  final int maxLines;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HeniDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 390,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          decoration: InputDecoration(hintText: widget.hintText),
          onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionText)),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }
}

class _MediaProbeDetails extends StatelessWidget {
  const _MediaProbeDetails({required this.probe});

  final AsyncValue<MediaProbe?> probe;

  @override
  Widget build(BuildContext context) {
    return probe.when(
      data: (data) {
        if (data == null) {
          return _MetadataLine(icon: Icons.info_outline, text: '等待读取媒体信息');
        }

        final primaryVideo = data.primaryVideoStream;
        final primaryAudio = data.primaryAudioStream;
        final pieces = <String>[
          if (data.formatName != null) data.formatName!,
          if (primaryVideo?.codecName case final String codec) '视频 $codec',
          if (primaryVideo?.displaySize case final String size) size,
          if (primaryAudio?.codecName case final String codec) '音频 $codec',
          if (primaryAudio?.sampleRate case final int sampleRate)
            '${sampleRate ~/ 1000} kHz',
          if (primaryAudio?.channels case final int channels)
            channels == 1 ? '单声道' : '$channels 声道',
          if (data.duration case final Duration duration)
            _formatDurationLong(duration),
        ];

        return _MetadataLine(
          icon: data.hasVideo ? Icons.movie_filter_outlined : Icons.graphic_eq,
          text: pieces.isEmpty ? '没有读取到流信息' : pieces.join(' / '),
        );
      },
      loading:
          () => _MetadataLine(
            icon: Icons.manage_search_outlined,
            text: '正在解析容器和编码信息...',
          ),
      error:
          (error, stackTrace) => _MetadataLine(
            icon: Icons.warning_amber_outlined,
            text: '媒体信息读取失败',
            tooltip: error.toString(),
          ),
    );
  }

  String _formatDurationLong(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.icon, required this.text, this.tooltip});

  final IconData icon;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.62)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ),
      ],
    );

    if (tooltip == null) {
      return content;
    }

    return Tooltip(message: tooltip!, child: content);
  }
}

class _ProgressWithTime extends StatelessWidget {
  const _ProgressWithTime({required this.engine, required this.palette});

  final PlaybackEngine engine;
  final HeniPalette palette;

  @override
  Widget build(BuildContext context) {
    final timeStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: Colors.white.withValues(alpha: 0.62),
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StreamBuilder<Duration>(
          stream: engine.position,
          initialData: Duration.zero,
          builder: (context, snap) {
            return SizedBox(
              width: 38,
              child: Text(
                _formatProgressTime(snap.data ?? Duration.zero),
                textAlign: TextAlign.right,
                style: timeStyle.copyWith(color: Colors.white.withValues(alpha: 0.82)),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(child: _ProgressBar(engine: engine, palette: palette)),
        const SizedBox(width: 8),
        StreamBuilder<Duration>(
          stream: engine.duration,
          initialData: Duration.zero,
          builder: (context, snap) {
            return SizedBox(
              width: 38,
              child: Text(
                _formatProgressTime(snap.data ?? Duration.zero),
                textAlign: TextAlign.left,
                style: timeStyle,
              ),
            );
          },
        ),
      ],
    );
  }
}

String _formatProgressTime(Duration d) {
  if (d == Duration.zero) return '--:--';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.engine, required this.palette});

  final PlaybackEngine engine;
  final HeniPalette palette;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _hovering = false;
  bool _dragging = false;
  double? _hoverFraction;
  double? _dragFraction;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.engine.duration,
      initialData: Duration.zero,
      builder: (context, durationSnap) {
        final total = durationSnap.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: widget.engine.position,
          initialData: Duration.zero,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final totalMs =
                total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
            final posMs =
                position.inMilliseconds.clamp(0, totalMs.toInt()).toDouble();
            final playFraction = posMs / totalMs;
            final displayFraction =
                _dragging ? (_dragFraction ?? playFraction) : playFraction;

            final displayPosition =
                _dragging && _dragFraction != null
                    ? Duration(
                      milliseconds: (_dragFraction! * totalMs).round(),
                    )
                    : position;

            return Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    _fmt(displayPosition),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barW = constraints.maxWidth;

                      void seekToFraction(double f) {
                        final ms = (f.clamp(0.0, 1.0) * totalMs).round();
                        widget.engine.seek(Duration(milliseconds: ms));
                      }

                      void updateDrag(double localX) {
                        setState(() {
                          _dragFraction =
                              (localX / barW).clamp(0.0, 1.0);
                        });
                      }

                      final hoverDuration =
                          _hoverFraction != null
                              ? Duration(
                                milliseconds:
                                    (_hoverFraction! * totalMs).round(),
                              )
                              : null;

                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter:
                                (_) => setState(() => _hovering = true),
                            onExit: (_) => setState(() {
                              _hovering = false;
                              _hoverFraction = null;
                            }),
                            onHover: (event) {
                              setState(() {
                                _hoverFraction =
                                    (event.localPosition.dx / barW)
                                        .clamp(0.0, 1.0);
                              });
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => seekToFraction(
                                d.localPosition.dx / barW,
                              ),
                              onHorizontalDragStart: (d) {
                                setState(() => _dragging = true);
                                updateDrag(d.localPosition.dx);
                              },
                              onHorizontalDragUpdate: (d) =>
                                  updateDrag(d.localPosition.dx),
                              onHorizontalDragEnd: (_) {
                                if (_dragFraction != null) {
                                  seekToFraction(_dragFraction!);
                                }
                                setState(() {
                                  _dragging = false;
                                  _dragFraction = null;
                                });
                              },
                              child: SizedBox(
                                height: 26,
                                width: barW,
                                child: CustomPaint(
                                  painter: _ProgressBarPainter(
                                    fraction: displayFraction,
                                    hovering: _hovering || _dragging,
                                    seedColor: widget.palette.seed,
                                    accentColor: widget.palette.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if ((_hovering || _dragging) &&
                              hoverDuration != null)
                            Positioned(
                              top: -34,
                              left: ((_hoverFraction ?? displayFraction) *
                                          barW)
                                      .clamp(24.0, barW - 24.0) -
                                  24,
                              child: _TimeTooltip(
                                duration: hoverDuration,
                                seedColor: widget.palette.seed,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    _fmt(total),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimeTooltip extends StatelessWidget {
  const _TimeTooltip({required this.duration, required this.seedColor});

  final Duration duration;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    final text = '$m:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: seedColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: heniReadableForegroundOn(seedColor),
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  const _ProgressBarPainter({
    required this.fraction,
    required this.hovering,
    required this.seedColor,
    required this.accentColor,
  });

  final double fraction;
  final bool hovering;
  final Color seedColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackH = 3.5;
    const hoverTrackH = 5.5;
    final h = hovering ? hoverTrackH : trackH;
    final cy = size.height / 2;
    const radius = Radius.circular(6);

    final trackRect = Rect.fromLTWH(0, cy - h / 2, size.width, h);
    final trackRRect = RRect.fromRectAndRadius(trackRect, radius);

    canvas.drawRRect(
      trackRRect,
      Paint()..color = Colors.white.withValues(alpha: 0.13),
    );

    final f = fraction.clamp(0.0, 1.0);
    if (f > 0) {
      final fillW = size.width * f;
      final fillRect = Rect.fromLTWH(0, cy - h / 2, fillW, h);
      final fillRRect = RRect.fromRectAndRadius(fillRect, radius);
      final blended = Color.lerp(seedColor, accentColor, 0.6)!;
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..shader = LinearGradient(
            colors: [seedColor, blended],
          ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
      );
    }

    if (hovering) {
      final thumbX = (size.width * f).clamp(0.0, size.width);
      final center = Offset(thumbX, cy);
      canvas.drawCircle(
        center,
        9,
        Paint()
          ..color = seedColor.withValues(alpha: 0.26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(center, 5.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter old) {
    return old.fraction != fraction ||
        old.hovering != hovering ||
        old.seedColor != seedColor ||
        old.accentColor != accentColor;
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({
    required this.color,
    required this.active,
    required this.child,
  });

  final Color color;
  final bool active;
  final Widget child;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseRing old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      if (widget.active) {
        _ctrl.repeat();
      } else {
        _ctrl.animateTo(0, duration: const Duration(milliseconds: 400));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final scale = 1.0 + t * 0.56;
            final opacity =
                (1.0 - t) * (widget.active ? 0.42 : 0.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: opacity),
                    width: 1.8,
                  ),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.engine,
    required this.onPreviousTrack,
    required this.onNextTrack,
  });

  final PlaybackEngine engine;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: false,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TransportButton(
              tooltip: '上一首',
              onPressed: onPreviousTrack,
              icon: Icons.skip_previous_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _PulseRing(
                color: Theme.of(context).colorScheme.primary,
                active: playing,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: playing ? 1 : 0.96,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(
                            alpha: playing ? 0.32 : 0.18,
                          ),
                          blurRadius: playing ? 24 : 14,
                          spreadRadius: playing ? 3 : 0,
                        ),
                      ],
                    ),
                    child: IconButton.filled(
                      tooltip: playing ? '暂停' : '播放',
                      onPressed: () {
                        if (playing) {
                          engine.pause();
                        } else {
                          engine.play();
                        }
                      },
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(48),
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      iconSize: 24,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder:
                            (child, animation) => ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(playing),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _TransportButton(
              tooltip: '下一首',
              onPressed: onNextTrack,
              icon: Icons.skip_next_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_regularIconButtonSize),
            padding: EdgeInsets.zero,
            foregroundColor: _primaryGlassText(),
          ),
          icon: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

class _PlaybackModeIconButton extends StatelessWidget {
  const _PlaybackModeIconButton({required this.mode, required this.onPressed});

  final HeniPlaybackMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = mode != HeniPlaybackMode.sequence;

    return Tooltip(
      message: '播放模式：${mode.label}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              active
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                active
                    ? theme.colorScheme.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: IconButton(
          isSelected: active,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_regularIconButtonSize),
            padding: EdgeInsets.zero,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(_playbackModeIcon(mode), key: ValueKey(mode), size: 20),
          ),
        ),
      ),
    );
  }
}

class _CompactPaletteButton extends ConsumerStatefulWidget {
  const _CompactPaletteButton({required this.active});

  final HeniPalette active;

  @override
  ConsumerState<_CompactPaletteButton> createState() =>
      _CompactPaletteButtonState();
}

class _CompactPaletteButtonState
    extends ConsumerState<_CompactPaletteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.active;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: MenuAnchor(
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          shadowColor: WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
        alignmentOffset: const Offset(-8, 8),
        menuChildren: [
          _GlassPanel(
            radius: 22,
            fillColor: _shellGlassFill(palette, emphasis: 1.1),
            borderColor: _shellGlassBorder(palette, emphasis: 1.1),
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: 228,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '外观颜色',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final p in HeniPalette.all)
                        Tooltip(
                          message: p.name,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              ref
                                  .read(activePaletteProvider.notifier)
                                  .select(p);
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .persistShellPreferences(palette: p),
                              );
                            },
                            child: _PaletteSwatch(
                              palette: p,
                              selected: identical(widget.active, p),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        builder: (context, controller, _) {
          return Tooltip(
            message: '外观：${palette.name}',
            child: GestureDetector(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: AnimatedContainer(
                duration: _hoverDuration,
                curve: _hoverCurve,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.seed,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: _hovered || controller.isOpen ? 0.42 : 0.22,
                    ),
                    width: _hovered || controller.isOpen ? 2.5 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.seed.withValues(
                        alpha: _hovered || controller.isOpen ? 0.52 : 0.32,
                      ),
                      blurRadius: _hovered || controller.isOpen ? 14 : 8,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.palette, required this.selected});

  final HeniPalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final width = selected ? 34.0 : 24.0;
    final height = selected ? 28.0 : 22.0;

    return AnimatedContainer(
      duration: _hoverDuration,
      curve: _hoverCurve,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.seed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.24),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: palette.seed.withValues(alpha: 0.48),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: selected ? 18 : 14,
          height: 1.5,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: selected ? 0.42 : 0.18),
          ),
        ),
      ),
    );
  }
}

class _UiStyleSwitch extends StatelessWidget {
  const _UiStyleSwitch({
    required this.palette,
    required this.active,
    required this.onSelect,
  });

  final HeniPalette palette;
  final HeniUiStyle active;
  final ValueChanged<HeniUiStyle> onSelect;

  @override
  Widget build(BuildContext context) {
    final styles = HeniUiStyle.values;
    final activeIndex = styles.indexOf(active);

    return Container(
      width: 130,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / styles.length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: activeIndex * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.seed.withValues(alpha: 0.92),
                        Color.lerp(palette.seed, palette.accent, 0.55)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: palette.seed.withValues(alpha: 0.42),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final style in styles)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(style),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                style == HeniUiStyle.scenery
                                    ? Icons.wallpaper_outlined
                                    : Icons.table_rows_rounded,
                                size: 13,
                                color:
                                    style == active
                                        ? heniReadableForegroundOn(palette.seed)
                                        : Colors.white.withValues(alpha: 0.62),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  style.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        style == active
                                            ? heniReadableForegroundOn(
                                              palette.seed,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.62,
                                            ),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
