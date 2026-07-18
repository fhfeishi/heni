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
import '../../../design/heni_shell_theme.dart';
import '../../../domain/media/media_item.dart';
import '../../../domain/media/media_kind.dart';
import '../../../domain/media/media_path.dart';
import '../../../domain/media/media_probe.dart';
import '../../../domain/playback/heni_playlist.dart';
import '../../../domain/playback/playback_mode.dart';
import '../../../services/files/local_file_actions.dart';
import '../../../services/media/playback_engine.dart';
import '../../../services/media/playback_providers.dart';
import '../../../services/window/heni_window_controller.dart';
import '../application/playback_queue_controller.dart';
import '../application/player_state.dart';
import '../application/sidebar_mode.dart';
import 'adaptive_sidebar.dart';
import 'global_scenery_backdrop.dart';
import 'listening_console.dart';
import 'playback_mode_controls.dart';
import 'playback_queue_location.dart';
import 'player_progress.dart';
import 'player_responsive_layout.dart';
import 'player_shell_frame.dart';
import 'player_window_chrome.dart';
import 'volume_control.dart';

const _hoverDuration = Duration(milliseconds: 220);
const _hoverCurve = Curves.easeOutCubic;
const _contentSwitchDuration = Duration(milliseconds: 320);
const _denseIconButtonSize = 40.0;
const _regularIconButtonSize = 42.0;
const _compactIconSize = 18.0;
const _libraryLeadColumnWidth = 64.0;
const _libraryDurationColumnWidth = 64.0;
const _libraryActionColumnWidth = 92.0;
final _localFileActions = LocalFileActions();

class _LibraryTableColumns {
  const _LibraryTableColumns({
    required this.leadWidth,
    required this.durationWidth,
    required this.actionWidth,
    required this.gap,
    required this.showPath,
    required this.showAction,
    required this.compactAction,
  });

  factory _LibraryTableColumns.forWidth(double width) {
    if (width < 300) {
      return const _LibraryTableColumns(
        leadWidth: 48,
        durationWidth: 52,
        actionWidth: 0,
        gap: 6,
        showPath: false,
        showAction: false,
        compactAction: true,
      );
    }

    if (width < 520) {
      return const _LibraryTableColumns(
        leadWidth: 52,
        durationWidth: 54,
        actionWidth: 38,
        gap: 6,
        showPath: false,
        showAction: true,
        compactAction: true,
      );
    }

    if (width < 640) {
      return const _LibraryTableColumns(
        leadWidth: 58,
        durationWidth: 58,
        actionWidth: 42,
        gap: 8,
        showPath: false,
        showAction: true,
        compactAction: true,
      );
    }

    if (width < 760) {
      return const _LibraryTableColumns(
        leadWidth: 60,
        durationWidth: 60,
        actionWidth: 44,
        gap: 10,
        showPath: true,
        showAction: true,
        compactAction: true,
      );
    }

    return const _LibraryTableColumns(
      leadWidth: _libraryLeadColumnWidth,
      durationWidth: _libraryDurationColumnWidth,
      actionWidth: _libraryActionColumnWidth,
      gap: 12,
      showPath: true,
      showAction: true,
      compactAction: false,
    );
  }

  final double leadWidth;
  final double durationWidth;
  final double actionWidth;
  final double gap;
  final bool showPath;
  final bool showAction;
  final bool compactAction;
}

Color _shellGlassFill(HeniPalette palette, {double emphasis = 1}) {
  return Color.alphaBlend(
    palette.seed.withValues(alpha: 0.08 + 0.025 * emphasis),
    Color.alphaBlend(
      palette.surfaceAlt.withValues(alpha: 0.62 + 0.08 * emphasis),
      palette.surface,
    ),
  );
}

Color _shellGlassBorder(HeniPalette palette, {double emphasis = 1}) {
  return Color.alphaBlend(
    palette.seed.withValues(alpha: 0.12 + 0.025 * emphasis),
    Colors.white.withValues(alpha: 0.055),
  );
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

Color _accentControlForeground(BuildContext context) {
  return heniReadableForegroundOn(Theme.of(context).colorScheme.primary);
}

Color _stateIconOnGlass(BuildContext context, {bool active = false}) {
  final primary = Theme.of(context).colorScheme.primary;
  return heniAccentOnGlass(primary, alpha: active ? 0.96 : 0.82);
}

/// Heni 统一间距节奏：保持 4 的倍数，避免“贴边/过空”随手取值。
class _Gap {
  const _Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
}

/// 品牌主渐变：seed → accent 的方向性渐变，贯穿主操作控件，
/// 让颜色形成“调性”而非零散点缀。
LinearGradient heniBrandGradient(
  HeniPalette palette, {
  double opacity = 1,
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) {
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [
      palette.seed.withValues(alpha: opacity),
      Color.lerp(
        palette.seed,
        palette.accent,
        0.85,
      )!.withValues(alpha: opacity),
    ],
  );
}

/// 品牌渐变的柔和叠层（用于选中态/高亮底色）。
LinearGradient heniBrandWash(HeniPalette palette, {double opacity = 0.16}) {
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      palette.seed.withValues(alpha: opacity),
      palette.accent.withValues(alpha: opacity * 0.7),
    ],
  );
}

/// 监听控制器状态消息，在底栏上方浮出一枚短暂的 Toast 气泡，
/// 给“已加入《xx》”这类操作即时反馈。
class _ToastOverlay extends ConsumerStatefulWidget {
  const _ToastOverlay({required this.palette});

  final HeniPalette palette;

  @override
  ConsumerState<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends ConsumerState<_ToastOverlay> {
  String? _message;
  bool _isError = false;
  bool _visible = false;
  Timer? _dismissTimer;
  int _token = 0;

  void _show(String message, {required bool isError}) {
    _dismissTimer?.cancel();
    final token = ++_token;
    setState(() {
      _message = message;
      _isError = isError;
      _visible = true;
    });
    _dismissTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || token != _token) return;
      setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  IconData _iconFor(String message, bool isError) {
    if (isError) return Icons.error_outline_rounded;
    if (message.contains('已加入') || message.contains('已创建')) {
      return Icons.playlist_add_check_rounded;
    }
    if (message.contains('已删除') || message.contains('移除')) {
      return Icons.delete_outline_rounded;
    }
    if (message.contains('正在')) return Icons.sync_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackQueueState>(playbackQueueControllerProvider, (
      prev,
      next,
    ) {
      if (next.lastError != null && next.lastError != prev?.lastError) {
        _show(next.lastError!, isError: true);
      } else if (next.statusMessage != null &&
          next.statusMessage != prev?.statusMessage) {
        _show(next.statusMessage!, isError: false);
      }
    });

    final palette = widget.palette;
    final message = _message;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 104),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: _visible ? Offset.zero : const Offset(0, 0.4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: _visible ? 1 : 0,
            child:
                message == null
                    ? const SizedBox.shrink()
                    : _ToastBubble(
                      palette: palette,
                      message: message,
                      icon: _iconFor(message, _isError),
                      isError: _isError,
                    ),
          ),
        ),
      ),
    );
  }
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({
    required this.palette,
    required this.message,
    required this.icon,
    required this.isError,
  });

  final HeniPalette palette;
  final String message;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isError ? const Color(0xFFFF8C8C) : palette.accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.fromLTRB(_Gap.md, _Gap.sm + 2, _Gap.lg, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.alphaBlend(
                  palette.seed.withValues(alpha: 0.20),
                  palette.surfaceAlt.withValues(alpha: 0.86),
                ),
                Color.alphaBlend(
                  palette.surfaceAlt.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.2),
                ),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
            boxShadow: [
              BoxShadow(
                color: palette.seed.withValues(alpha: 0.28),
                blurRadius: 26,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: heniBrandGradient(palette, opacity: 0.9),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: heniReadableForegroundOn(palette.seed),
                ),
              ),
              const SizedBox(width: _Gap.sm + 2),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: Colors.white.withValues(alpha: 0.94),
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

final _activeModalActionProvider = NotifierProvider<ActiveModalAction, String?>(
  ActiveModalAction.new,
);

class ActiveModalAction extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String actionId) {
    state = actionId;
  }

  void finish(String actionId) {
    if (state == actionId) {
      state = null;
    }
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
  const _ShellLayout({
    required this.compact,
    required this.quiet,
    required this.narrow,
  });

  factory _ShellLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final compact = width < 1360 || height < 860;
    final quiet = width < 1120 || height < 740;
    final narrow = width < 900 || height < 620;
    return _ShellLayout(compact: compact, quiet: quiet, narrow: narrow);
  }

  final bool compact;
  final bool quiet;
  final bool narrow;

  double get topHeight =>
      narrow
          ? 58
          : quiet
          ? 62
          : 66;
  double get bottomHeight =>
      narrow
          ? 68
          : quiet
          ? 76
          : compact
          ? 84
          : 88;
  double sidebarWidth(HeniSidebarMode mode) {
    return switch (mode) {
      HeniSidebarMode.expanded => 224,
      HeniSidebarMode.compact => 72,
    };
  }

  double get sidebarPadding => narrow ? 8 : 12;
  double get topHorizontalMargin => narrow ? 8 : 12;
  double get contentGap => narrow ? 8 : 12;
  double get bottomDockExtent =>
      narrow
          ? 84
          : quiet
          ? 90
          : bottomHeight + 12;
  bool get showSidebarStatus => !quiet;
  bool get useDenseHeader => compact;
  bool get showSceneryOrb => !quiet;
  bool get showNowPlayingDetails => !quiet;
  bool get showNowPlayingMeta => !quiet;
  bool get preferCompactUtility => compact;
}

class _GlassPanel extends StatefulWidget {
  const _GlassPanel({
    required this.child,
    this.padding,
    this.radius = 24,
    this.fillColor,
    this.borderColor,
    this.auroraPalette,
    this.hoverAccentPalette,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? fillColor;
  final Color? borderColor;
  final HeniPalette? auroraPalette;

  /// 桌面端指针悬停时略微提亮描边与光晕，避免玻璃块「死板」。
  final HeniPalette? hoverAccentPalette;

  @override
  State<_GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<_GlassPanel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final resolvedFill =
        widget.fillColor ??
        Color.alphaBlend(Colors.white.withValues(alpha: 0.06), Colors.black);
    final baseBorder =
        widget.borderColor ?? Colors.white.withValues(alpha: 0.07);
    final accent = widget.hoverAccentPalette;
    final borderCol =
        _hover && accent != null
            ? Color.alphaBlend(accent.seed.withValues(alpha: 0.34), baseBorder)
            : baseBorder;

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      if (_hover && accent != null)
        BoxShadow(
          color: accent.seed.withValues(alpha: 0.055),
          blurRadius: 18,
          spreadRadius: -10,
          offset: const Offset(0, 8),
        ),
    ];

    final core = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: resolvedFill,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: borderCol),
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              if (widget.auroraPalette != null)
                Positioned(
                  left: 18,
                  right: 18,
                  top: 0,
                  height: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            widget.auroraPalette!.seed.withValues(alpha: 0.24),
                            widget.auroraPalette!.accent.withValues(
                              alpha: 0.20,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );

    if (accent == null) {
      return core;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: core,
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
    required this.shellTheme,
    required this.role,
    required this.padding,
    this.margin = EdgeInsets.zero,
    this.height,
    this.radius = 12,
  });

  final Widget child;
  final HeniShellTheme shellTheme;
  final HeniShellSurfaceRole role;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: AnimatedContainer(
        duration: _contentSwitchDuration,
        curve: _hoverCurve,
        height: height,
        child: HeniShellSurface(
          shellTheme: shellTheme,
          role: role,
          radius: radius,
          padding: padding,
          child: child,
        ),
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

class _AmbientBackdropState extends ConsumerState<_AmbientBackdrop> {
  bool _playing = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(playbackEngineProvider);
    _playing = engine.currentPlaying;
    _sub = engine.playing.listen((v) {
      if (!mounted) return;
      setState(() => _playing = v);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final intensity = _playing ? 1.0 : 0.68;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: palette.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                palette.seed.withValues(alpha: 0.075 * intensity),
                palette.surface,
              ),
              palette.surface,
              Color.alphaBlend(
                palette.accent.withValues(alpha: 0.045 * intensity),
                palette.surface,
              ),
            ],
            stops: const [0.0, 0.62, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -170,
              left: -120,
              child: _GlowOrb(
                size: 430,
                color: palette.seed.withValues(alpha: 0.12 * intensity),
              ),
            ),
            Positioned(
              bottom: -220,
              right: -130,
              child: _GlowOrb(
                size: 500,
                color: palette.accent.withValues(alpha: 0.07 * intensity),
              ),
            ),
          ],
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

class _CornerGlowState extends ConsumerState<_CornerGlow> {
  bool _playing = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(playbackEngineProvider);
    _playing = engine.currentPlaying;
    _sub = engine.playing.listen((v) {
      if (!mounted) return;
      setState(() => _playing = v);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final playBoost = _playing ? 1.0 : 0.66;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: playBoost,
      child: Stack(
        children: [
          Positioned(
            left: -150,
            top: -150,
            child: _CornerOrb(
              size: 340,
              color: palette.seed.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            right: -150,
            bottom: -150,
            child: _CornerOrb(
              size: 320,
              color: palette.accent.withValues(alpha: 0.055),
            ),
          ),
        ],
      ),
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
    final shellTheme = HeniShellTheme.fromPalette(palette);
    final uiStyle = ref.watch(activeUiStyleProvider);
    final sceneryImages = ref.watch(sceneryImagePathsProvider);
    final queue = ref.watch(playbackQueueControllerProvider);
    final currentMedia = queue.currentItem ?? ref.watch(currentMediaProvider);
    final mediaProbe = ref.watch(currentMediaProbeProvider);
    final engine = ref.watch(playbackEngineProvider);
    final videoController = ref.watch(videoControllerProvider);
    final focusMode = ref.watch(focusModeProvider);
    final sidebarPreference = ref.watch(sidebarModeProvider);
    final sidebarPreferencesRestored = ref.watch(
      sidebarPreferencesRestoredProvider,
    );
    final isMaximized = ref.watch(heniWindowControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeniPanoramicShellFrame(
        shellTheme: shellTheme,
        isMaximized: isMaximized,
        child: Stack(
          children: [
            Positioned.fill(
              child: GlobalSceneryBackdrop(
                imagePaths: sceneryImages,
                palette: palette,
                shellTheme: shellTheme,
                mode:
                    uiStyle == HeniUiStyle.scenery
                        ? HeniBackdropMode.playback
                        : HeniBackdropMode.library,
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = _ShellLayout.fromConstraints(constraints);

                    return Stack(
                      children: [
                        Positioned.fill(
                          bottom: layout.bottomDockExtent,
                          child: Column(
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
                                                      .read(
                                                        focusModeProvider
                                                            .notifier,
                                                      )
                                                      .toggle(),
                                        )
                                        : _TopNavigation(
                                          palette: palette,
                                          shellTheme: shellTheme,
                                          queue: queue,
                                          layout: layout,
                                        ),
                              ),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                                              : HeniAdaptiveSidebar(
                                                availableWidth:
                                                    constraints.maxWidth,
                                                preference: sidebarPreference,
                                                preferencesRestored:
                                                    sidebarPreferencesRestored,
                                                requestExpandedWidth: () async {
                                                  final result = await ref
                                                      .read(
                                                        heniWindowControllerProvider
                                                            .notifier,
                                                      )
                                                      .ensureClientWidth(
                                                        heniSidebarExpandedSafeWidth,
                                                      );
                                                  return result
                                                      .reachedRequestedWidth;
                                                },
                                                onPreferenceChanged: (mode) {
                                                  ref
                                                      .read(
                                                        sidebarModeProvider
                                                            .notifier,
                                                      )
                                                      .select(mode);
                                                  unawaited(
                                                    ref
                                                        .read(
                                                          playbackQueueControllerProvider
                                                              .notifier,
                                                        )
                                                        .persistShellPreferences(
                                                          sidebarMode: mode,
                                                        ),
                                                  );
                                                },
                                                builder: (
                                                  context,
                                                  effectiveMode,
                                                  widthForcedCompact,
                                                  selectMode,
                                                ) {
                                                  return _Sidebar(
                                                    palette: palette,
                                                    shellTheme: shellTheme,
                                                    queue: queue,
                                                    layout: layout,
                                                    mode: effectiveMode,
                                                    widthForcedCompact:
                                                        widthForcedCompact,
                                                    onModeChanged: selectMode,
                                                    onCreatePlaylist:
                                                        () => _createPlaylist(
                                                          context,
                                                          ref,
                                                        ),
                                                    onSelectPlaylist: (
                                                      playlistId,
                                                    ) {
                                                      ref
                                                          .read(
                                                            playbackQueueControllerProvider
                                                                .notifier,
                                                          )
                                                          .selectPlaylist(
                                                            playlistId,
                                                          );
                                                    },
                                                    onAddFromLibrary: (
                                                      playlistId,
                                                    ) {
                                                      _addFromLibrary(
                                                        context,
                                                        ref,
                                                        playlistId,
                                                      );
                                                    },
                                                    onRenamePlaylist: (
                                                      playlist,
                                                    ) {
                                                      _renamePlaylist(
                                                        context,
                                                        ref,
                                                        playlist,
                                                      );
                                                    },
                                                    onEditDescription: (
                                                      playlist,
                                                    ) {
                                                      _editPlaylistDescription(
                                                        context,
                                                        ref,
                                                        playlist,
                                                      );
                                                    },
                                                    onDeletePlaylist: (
                                                      playlist,
                                                    ) {
                                                      _confirmDeletePlaylist(
                                                        context,
                                                        ref,
                                                        playlist,
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                    ),
                                    Expanded(
                                      child: _ContentArea(
                                        palette: palette,
                                        shellTheme: shellTheme,
                                        uiStyle: uiStyle,
                                        queue: queue,
                                        currentMedia: currentMedia,
                                        mediaProbe: mediaProbe,
                                        engine: engine,
                                        videoController: videoController,
                                        layout: layout,
                                        onPickScenery: () => _pickScenery(ref),
                                        onPickMedia: () => _pickMedia(ref),
                                        onPickFolder: () => _pickFolder(ref),
                                        onShowPlaybackQueue:
                                            () => _showPlaybackQueue(
                                              context,
                                              ref,
                                            ),
                                        onOpenFileLocation:
                                            currentMedia == null
                                                ? () {}
                                                : () => unawaited(
                                                  _openFileLocation(
                                                    ref,
                                                    currentMedia,
                                                  ),
                                                ),
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
                                              .addItemToPlaylist(
                                                playlistId,
                                                item,
                                              );
                                        },
                                        onAddFromLibrary: (playlistId) {
                                          _addFromLibrary(
                                            context,
                                            ref,
                                            playlistId,
                                          );
                                        },
                                        onManagePlaylist: (playlist) {
                                          _managePlaylistItems(
                                            context,
                                            ref,
                                            playlist,
                                          );
                                        },
                                        onRemoveFromPlaylist: (
                                          playlistId,
                                          item,
                                        ) {
                                          ref
                                              .read(
                                                playbackQueueControllerProvider
                                                    .notifier,
                                              )
                                              .removeItemsFromPlaylist(
                                                playlistId,
                                                [item],
                                              );
                                        },
                                        onRemoveFromPlaybackQueue: (index) {
                                          unawaited(
                                            ref
                                                .read(
                                                  playbackQueueControllerProvider
                                                      .notifier,
                                                )
                                                .removePlaybackQueueItemAt(
                                                  index,
                                                ),
                                          );
                                        },
                                        onPlayNext: (item) {
                                          ref
                                              .read(
                                                playbackQueueControllerProvider
                                                    .notifier,
                                              )
                                              .playItemNext(item);
                                        },
                                        onEnqueue: (item) {
                                          ref
                                              .read(
                                                playbackQueueControllerProvider
                                                    .notifier,
                                              )
                                              .enqueueItem(item);
                                        },
                                        onSelectUiStyle: (style) {
                                          ref
                                              .read(
                                                activeUiStyleProvider.notifier,
                                              )
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
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: layout.bottomDockExtent,
                          child: _BottomPlayerBar(
                            palette: palette,
                            shellTheme: shellTheme,
                            currentMedia: currentMedia,
                            mediaProbe: mediaProbe,
                            queue: queue,
                            engine: engine,
                            layout: layout,
                            onPreviousTrack: () {
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .playPrevious(),
                              );
                            },
                            onNextTrack: () {
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .playNext(),
                              );
                            },
                            onToggleShuffle: () {
                              ref
                                  .read(
                                    playbackQueueControllerProvider.notifier,
                                  )
                                  .toggleShuffle();
                            },
                            onCycleRepeat: () {
                              ref
                                  .read(
                                    playbackQueueControllerProvider.notifier,
                                  )
                                  .cycleRepeatMode();
                            },
                            onShowPlaybackQueue: () {
                              _showPlaybackQueue(context, ref);
                            },
                            onPersistVolume: (volume) {
                              unawaited(
                                ref
                                    .read(
                                      playbackQueueControllerProvider.notifier,
                                    )
                                    .persistVolume(volume),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(child: _ToastOverlay(palette: palette)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(WidgetRef ref) async {
    await _runModalAction(ref, 'pick-media', () async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: [...audioExtensions, ...videoExtensions],
        dialogTitle: '添加音视频文件',
        lockParentWindow: true,
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
    });
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    await _runModalAction(ref, 'pick-folder', () async {
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
    });
  }

  Future<void> _pickScenery(WidgetRef ref) async {
    await _runModalAction(ref, 'pick-scenery', () async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: const ['bmp', 'jpeg', 'jpg', 'png', 'webp'],
        dialogTitle: '选择播放背景图片',
        lockParentWindow: true,
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
    });
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    await _runModalAction(ref, 'create-playlist', () async {
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
    });
  }

  Future<void> _addFromLibrary(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
    await _runModalAction(ref, 'add-from-library', () async {
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
    });
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    await _runModalAction(ref, 'rename-playlist', () async {
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
    });
  }

  Future<void> _editPlaylistDescription(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    await _runModalAction(ref, 'edit-playlist-description', () async {
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
    });
  }

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    await _runModalAction(ref, 'delete-playlist', () async {
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
    });
  }

  Future<void> _managePlaylistItems(
    BuildContext context,
    WidgetRef ref,
    HeniPlaylist playlist,
  ) async {
    await _runModalAction(ref, 'manage-playlist-items', () async {
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
    });
  }

  Future<void> _showPlaybackQueue(BuildContext context, WidgetRef ref) async {
    await _runModalAction(ref, 'show-playback-queue', () async {
      await showDialog<void>(
        context: context,
        builder: (context) => const _PlaybackQueueDialog(),
      );
    });
  }

  Future<void> _openFileLocation(WidgetRef ref, MediaItem media) async {
    final result = await _localFileActions.revealInFileManager(media.path);
    final message = switch (result) {
      LocalFileActionResult.success => '已打开文件位置',
      LocalFileActionResult.missing => '文件不存在，未修改曲库',
      LocalFileActionResult.unsupported => '当前平台不支持打开文件位置',
      LocalFileActionResult.failed => '无法打开文件位置',
    };
    ref.read(playbackQueueControllerProvider.notifier).reportStatus(message);
  }

  Future<void> _runModalAction(
    WidgetRef ref,
    String actionId,
    Future<void> Function() action,
  ) async {
    final activeAction = ref.read(_activeModalActionProvider);
    if (activeAction != null) {
      return;
    }

    ref.read(_activeModalActionProvider.notifier).start(actionId);
    try {
      await action();
    } finally {
      ref.read(_activeModalActionProvider.notifier).finish(actionId);
    }
  }
}

class _TopNavigation extends ConsumerWidget {
  const _TopNavigation({
    required this.palette,
    required this.shellTheme,
    required this.queue,
    required this.layout,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final PlaybackQueueState queue;
  final _ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ShellBand(
      shellTheme: shellTheme,
      role: HeniShellSurfaceRole.chrome,
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
        horizontal: layout.narrow ? 10 : 14,
        vertical: 8,
      ),
      height: layout.topHeight,
      radius: 0,
      child: Row(
        children: [
          HeniWindowDragRegion(child: _TopBrand(layout: layout)),
          Expanded(
            child: HeniTopChromeCenter(
              search: Padding(
                padding: EdgeInsets.only(
                  left: layout.narrow ? 8 : 18,
                  right: layout.narrow ? 8 : 12,
                ),
                child: _TopSearchField(layout: layout),
              ),
            ),
          ),
          _CompactPaletteButton(active: palette),
          SizedBox(width: layout.quiet ? 6 : 8),
          _SettingsMenu(queue: queue),
          SizedBox(width: layout.quiet ? 6 : 8),
          Container(
            width: 1,
            height: 24,
            color: palette.seed.withValues(alpha: 0.14),
          ),
          SizedBox(width: layout.quiet ? 4 : 6),
          HeniWindowControls(shellTheme: shellTheme),
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
    _focusNode =
        FocusNode()..addListener(() {
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
    final hintText = widget.layout.quiet ? '搜索歌曲或路径' : '搜索歌曲、歌单或本地路径';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: widget.layout.narrow ? 34 : 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _focused ? 0.058 : 0.034),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _focused
                  ? palette.accent.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.055),
          width: _focused ? 1.0 : 1,
        ),
        boxShadow:
            _focused
                ? [
                  BoxShadow(
                    color: palette.seed.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: 0,
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
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _tertiaryGlassText()),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color:
                _focused
                    ? palette.seed.withValues(alpha: 0.92)
                    : _secondaryGlassText(emphasis: 0.82),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _TopBrand extends StatelessWidget {
  const _TopBrand({required this.layout});

  final _ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.quiet ? 54 : 82,
      height: double.infinity,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: HeniBrandWordmark(),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.palette,
    required this.shellTheme,
    required this.queue,
    required this.layout,
    required this.mode,
    required this.widthForcedCompact,
    required this.onModeChanged,
    required this.onCreatePlaylist,
    required this.onSelectPlaylist,
    required this.onAddFromLibrary,
    required this.onRenamePlaylist,
    required this.onEditDescription,
    required this.onDeletePlaylist,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final HeniSidebarMode mode;
  final bool widthForcedCompact;
  final HeniSidebarModeCallback onModeChanged;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<String> onSelectPlaylist;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onRenamePlaylist;
  final ValueChanged<HeniPlaylist> onEditDescription;
  final ValueChanged<HeniPlaylist> onDeletePlaylist;

  @override
  Widget build(BuildContext context) {
    if (mode == HeniSidebarMode.compact) {
      return _CompactSidebar(
        palette: palette,
        shellTheme: shellTheme,
        queue: queue,
        layout: layout,
        widthForcedCompact: widthForcedCompact,
        onModeChanged: onModeChanged,
        onCreatePlaylist: onCreatePlaylist,
        onSelectPlaylist: onSelectPlaylist,
      );
    }

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
      child: HeniShellSurface(
        shellTheme: shellTheme,
        role: HeniShellSurfaceRole.rail,
        radius: 12,
        padding: EdgeInsets.fromLTRB(
          layout.quiet ? 10 : 12,
          layout.quiet ? 12 : 14,
          layout.quiet ? 8 : 10,
          layout.quiet ? 12 : 14,
        ),
        child: AnimatedContainer(
          duration: _contentSwitchDuration,
          curve: _hoverCurve,
          width: layout.sidebarWidth(mode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SidebarSectionHeader(
                title: '浏览',
                action: IconButton(
                  tooltip: '收起侧边栏',
                  onPressed:
                      () => unawaited(onModeChanged(HeniSidebarMode.compact)),
                  icon: const Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 6),
              _PlaylistTile(
                palette: palette,
                playlist: queue.library,
                selected: queue.activePlaylistId == queue.library.id,
                isPlayingHere: queue.currentItem != null,
                onTap: () => onSelectPlaylist(queue.library.id),
              ),
              const SizedBox(height: 4),
              _PlaylistTile(
                palette: palette,
                playlist: playbackQueuePlaylist,
                selected: queue.activePlaylistId == heniPlaybackQueueId,
                isPlayingHere: queue.currentItem != null,
                onTap: () => onSelectPlaylist(heniPlaybackQueueId),
              ),
              SizedBox(height: layout.quiet ? 16 : 22),
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
              const SizedBox(height: 6),
              Expanded(
                flex: 2,
                child:
                    queue.playlists.isEmpty
                        ? _SidebarEmptyState(
                          palette: palette,
                          message: '从曲库挑歌加入歌单，慢慢搭起自己的收藏。',
                        )
                        : ListView(
                          key: const PageStorageKey(
                            'expanded-sidebar-playlists',
                          ),
                          children: [
                            for (final playlist in queue.playlists)
                              _PlaylistTile(
                                palette: palette,
                                playlist: playlist,
                                selected: playlist.id == queue.activePlaylistId,
                                isPlayingHere:
                                    queue.currentItem != null &&
                                    playlist.items.any(
                                      (it) =>
                                          it.path == queue.currentItem!.path,
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
              SizedBox(height: layout.quiet ? 12 : 16),
              const Spacer(),
              if (layout.showSidebarStatus &&
                  (queue.statusMessage != null || queue.lastError != null))
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.024),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
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
    );
  }
}

class _CompactSidebar extends StatelessWidget {
  const _CompactSidebar({
    required this.palette,
    required this.shellTheme,
    required this.queue,
    required this.layout,
    required this.widthForcedCompact,
    required this.onModeChanged,
    required this.onCreatePlaylist,
    required this.onSelectPlaylist,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final bool widthForcedCompact;
  final HeniSidebarModeCallback onModeChanged;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<String> onSelectPlaylist;

  @override
  Widget build(BuildContext context) {
    Widget destination({
      required String tooltip,
      required IconData icon,
      required String id,
      required int count,
    }) {
      final selected = queue.activePlaylistId == id;
      return Tooltip(
        message: '$tooltip · $count 首',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => onSelectPlaylist(id),
              child: AnimatedContainer(
                duration: _hoverDuration,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? palette.accent.withValues(alpha: 0.14)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color:
                        selected
                            ? palette.accent.withValues(alpha: 0.20)
                            : Colors.transparent,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color:
                          selected
                              ? heniAccentOnGlass(palette.accent)
                              : _secondaryGlassText(),
                    ),
                    if (selected)
                      Positioned(
                        left: 0,
                        top: 12,
                        bottom: 12,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.sidebarPadding,
        0,
        6,
        layout.sidebarPadding,
      ),
      child: HeniShellSurface(
        shellTheme: shellTheme,
        role: HeniShellSurfaceRole.rail,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: SizedBox(
          width: layout.sidebarWidth(HeniSidebarMode.compact),
          child: Column(
            children: [
              IconButton(
                tooltip: widthForcedCompact ? '展开侧边栏并调整窗口' : '展开侧边栏',
                onPressed:
                    () => unawaited(onModeChanged(HeniSidebarMode.expanded)),
                icon: const Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(42),
                  foregroundColor: _secondaryGlassText(emphasis: 1.04),
                  backgroundColor: Colors.white.withValues(alpha: 0.025),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              destination(
                tooltip: '本地曲库',
                icon: Icons.library_music_outlined,
                id: heniLibraryPlaylistId,
                count: queue.library.items.length,
              ),
              destination(
                tooltip: '当前播放',
                icon: Icons.queue_music_rounded,
                id: heniPlaybackQueueId,
                count: queue.playbackQueue.items.length,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              if (queue.playlists.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: '我的歌单',
                  onSelected: onSelectPlaylist,
                  itemBuilder:
                      (context) => [
                        for (final playlist in queue.playlists)
                          PopupMenuItem<String>(
                            value: playlist.id,
                            child: Row(
                              children: [
                                Icon(
                                  playlist.id == queue.activePlaylistId
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.music_note_rounded,
                                  size: 17,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    playlist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${playlist.items.length}'),
                              ],
                            ),
                          ),
                      ],
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.playlist_play_rounded,
                      color: _secondaryGlassText(),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: '新建歌单',
                onPressed: onCreatePlaylist,
                icon: const Icon(Icons.add_rounded, size: 20),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(42),
                  foregroundColor: heniAccentOnGlass(palette.accent),
                  backgroundColor: palette.accent.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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
                fontWeight: FontWeight.w700,
                fontSize: 11.1,
                letterSpacing: 0.7,
                color: _secondaryGlassText(emphasis: 0.62),
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
        scale: widget.selected ? 1.0 : (_hovered ? 1.004 : 1.0),
        child: AnimatedSlide(
          duration: _hoverDuration,
          curve: _hoverCurve,
          offset:
              _hovered && !widget.selected
                  ? const Offset(0.006, 0)
                  : Offset.zero,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 40,
              decoration: BoxDecoration(
                gradient:
                    widget.selected
                        ? heniBrandWash(widget.palette, opacity: 0.18)
                        : null,
                color:
                    widget.selected
                        ? null
                        : tint.withValues(alpha: _hovered ? 0.038 : 0.0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      widget.selected
                          ? tint.withValues(alpha: 0.16)
                          : Colors.white.withValues(
                            alpha: _hovered ? 0.06 : 0.0,
                          ),
                ),
                boxShadow: [
                  if (_hovered || widget.selected)
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.selected ? 0.12 : 0.06,
                      ),
                      blurRadius: widget.selected ? 14 : 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  hoverColor: tint.withValues(alpha: 0.04),
                  splashColor: tint.withValues(alpha: 0.10),
                  highlightColor: tint.withValues(alpha: 0.06),
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
                          width: widget.selected ? 2.5 : (_hovered ? 1.5 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color:
                                widget.selected
                                    ? tint
                                    : Colors.white.withValues(alpha: 0.18),
                            boxShadow: [
                              if (widget.selected)
                                BoxShadow(
                                  color: tint.withValues(alpha: 0.34),
                                  blurRadius: 6,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: _hoverDuration,
                                width: 25,
                                height: 25,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient:
                                      widget.selected
                                          ? heniBrandGradient(
                                            widget.palette,
                                            opacity: 0.34,
                                          )
                                          : null,
                                  color:
                                      widget.selected
                                          ? null
                                          : tint.withValues(
                                            alpha: active ? 0.18 : 0.07,
                                          ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  widget.onDelete == null
                                      ? Icons.library_music_outlined
                                      : Icons.queue_music_rounded,
                                  size: 12.5,
                                  color: _primaryGlassText(
                                    emphasis: active ? 1.0 : 0.9,
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
                                    fontSize: 12.4,
                                    height: 1.15,
                                    fontWeight:
                                        widget.selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                    color: _primaryGlassText(
                                      emphasis: widget.selected ? 0.98 : 0.88,
                                    ),
                                    letterSpacing: 0.08,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (widget.isPlayingHere)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: StreamBuilder<bool>(
                                    stream:
                                        ref
                                            .read(playbackEngineProvider)
                                            .playing,
                                    initialData:
                                        ref
                                            .read(playbackEngineProvider)
                                            .currentPlaying,
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
                                      icon: const Icon(
                                        Icons.more_horiz,
                                        size: 16,
                                      ),
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
                                              value:
                                                  _PlaylistAction
                                                      .addFromLibrary,
                                              child: Text('添加歌曲'),
                                            ),
                                            PopupMenuItem<_PlaylistAction>(
                                              value: _PlaylistAction.rename,
                                              child: Text('重命名'),
                                            ),
                                            PopupMenuItem<_PlaylistAction>(
                                              value:
                                                  _PlaylistAction.description,
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
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.024),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _secondaryGlassText(emphasis: 1)),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _secondaryGlassText(emphasis: 0.82),
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: _secondaryGlassText(emphasis: 0.88),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              palette.seed.withValues(alpha: 0.10),
              palette.surfaceAlt,
            ),
            Color.alphaBlend(
              palette.seed.withValues(alpha: 0.04),
              palette.surface,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.045),
              Colors.white.withValues(alpha: 0.024),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
      ),
    );
  }
}

enum _PlaylistAction { addFromLibrary, rename, description, delete }

class _ContentArea extends ConsumerWidget {
  const _ContentArea({
    required this.palette,
    required this.shellTheme,
    required this.uiStyle,
    required this.queue,
    required this.currentMedia,
    required this.mediaProbe,
    required this.engine,
    required this.videoController,
    required this.layout,
    required this.onPickScenery,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onShowPlaybackQueue,
    required this.onOpenFileLocation,
    required this.onRefreshLibrary,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
    required this.onAddFromLibrary,
    required this.onManagePlaylist,
    required this.onRemoveFromPlaylist,
    required this.onRemoveFromPlaybackQueue,
    required this.onPlayNext,
    required this.onEnqueue,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final HeniUiStyle uiStyle;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final PlaybackEngine engine;
  final VideoController videoController;
  final _ShellLayout layout;
  final VoidCallback onPickScenery;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final VoidCallback onShowPlaybackQueue;
  final VoidCallback onOpenFileLocation;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;
  final ValueChanged<String> onAddFromLibrary;
  final ValueChanged<HeniPlaylist> onManagePlaylist;
  final void Function(String playlistId, MediaItem item) onRemoveFromPlaylist;
  final ValueChanged<int> onRemoveFromPlaybackQueue;
  final void Function(MediaItem item) onPlayNext;
  final void Function(MediaItem item) onEnqueue;
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
              hoverAccentPalette: palette,
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
                shellTheme: shellTheme,
                queue: queue,
                layout: layout,
                onPlayIndex: onPlayIndex,
                onAddToPlaylist: onAddToPlaylist,
                onRemoveFromPlaylist: onRemoveFromPlaylist,
                onRemoveFromPlaybackQueue: onRemoveFromPlaybackQueue,
                onPlayNext: onPlayNext,
                onEnqueue: onEnqueue,
                onPickFolder: onPickFolder,
                onPickMedia: onPickMedia,
                onRefreshLibrary: onRefreshLibrary,
                onAddFromLibrary: onAddFromLibrary,
                onManagePlaylist: onManagePlaylist,
                onSelectUiStyle: onSelectUiStyle,
              ),
              _ => _SceneryContent(
                palette: palette,
                queue: queue,
                currentMedia: currentMedia,
                mediaProbe: mediaProbe,
                engine: engine,
                videoController: videoController,
                layout: layout,
                onShowPlaybackQueue: onShowPlaybackQueue,
                onOpenFileLocation: onOpenFileLocation,
                onPickMedia: onPickMedia,
                onPickFolder: onPickFolder,
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

    if (uiStyle == HeniUiStyle.scenery) {
      return _StageHeaderDock(
        palette: palette,
        headingLabel: headingLabel,
        active: uiStyle,
        onPickScenery: onPickScenery,
        onSelectUiStyle: onSelectUiStyle,
      );
    }

    final actionButtons =
        browsingLibrary
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stackedHeader = width < 940;
        final compactHeader = width < 760;

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

        final titleText = Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: compactHeader ? 18 : 20,
            letterSpacing: -0.2,
          ),
        );

        final infoWrap = Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: infoPills,
        );

        final actionWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actionButtons,
        );

        if (compactHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _HeadingChip(label: headingLabel, palette: palette),
                  const Spacer(),
                  _UiStyleSwitch(
                    palette: palette,
                    active: uiStyle,
                    onSelect: onSelectUiStyle,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              titleText,
              const SizedBox(height: 10),
              infoWrap,
              if (actionButtons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actionWrap),
              ],
            ],
          );
        }

        final headerRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _HeadingChip(label: headingLabel, palette: palette),
            const SizedBox(width: 10),
            Expanded(child: titleText),
            const SizedBox(width: 12),
            _UiStyleSwitch(
              palette: palette,
              active: uiStyle,
              onSelect: onSelectUiStyle,
            ),
          ],
        );

        if (stackedHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              headerRow,
              const SizedBox(height: 10),
              infoWrap,
              if (actionButtons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actionWrap),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            headerRow,
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoWrap),
                if (actionButtons.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  actionWrap,
                ],
              ],
            ),
          ],
        );
      },
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

class _StageHeaderDock extends StatelessWidget {
  const _StageHeaderDock({
    required this.palette,
    required this.headingLabel,
    required this.active,
    required this.onPickScenery,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final String headingLabel;
  final HeniUiStyle active;
  final VoidCallback onPickScenery;
  final ValueChanged<HeniUiStyle> onSelectUiStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 520;
        final veryTight = constraints.maxWidth < 380;

        return AnimatedContainer(
          duration: _contentSwitchDuration,
          curve: _hoverCurve,
          padding: EdgeInsets.fromLTRB(
            tight ? 8 : 10,
            tight ? 6 : 8,
            tight ? 8 : 10,
            tight ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: tight ? 0.022 : 0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
            boxShadow: [
              BoxShadow(
                color: palette.seed.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!veryTight) ...[
                _HeadingChip(label: headingLabel, palette: palette),
                if (!tight) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      '安静播放 · 专注当前声音',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ] else
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.seed.withValues(alpha: 0.14),
                    border: Border.all(
                      color: palette.seed.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 15,
                    color: heniAccentOnGlass(palette.seed),
                  ),
                ),
              const Spacer(),
              _UiStyleSwitch(
                palette: palette,
                active: active,
                onSelect: onSelectUiStyle,
              ),
              SizedBox(width: tight ? 6 : 8),
              Tooltip(
                message: '更换背景',
                child: AnimatedContainer(
                  duration: _hoverDuration,
                  curve: _hoverCurve,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: IconButton(
                    onPressed: onPickScenery,
                    style: IconButton.styleFrom(
                      fixedSize: Size.square(tight ? 34 : 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: heniAccentOnGlass(palette.accent),
                    ),
                    icon: const Icon(Icons.image_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

String _playbackQualityLine(MediaItem? media, MediaProbe? probe) {
  if (media == null) {
    return '选择一首本地音频或视频，开始播放';
  }

  final audio = probe?.primaryAudioStream;
  if (audio == null) {
    return media.kind == MediaKind.video ? '本地视频' : '本地音频';
  }

  final codec = audio.codecName?.toUpperCase();
  final bitRate = audio.bitRate;
  final sampleRate = audio.sampleRate;
  final pieces = <String>[
    if (codec != null) codec,
    if (bitRate != null && bitRate > 0) '${(bitRate / 1000).round()} kbps',
    if (sampleRate != null && sampleRate > 0)
      sampleRate % 1000 == 0
          ? '${sampleRate ~/ 1000} kHz'
          : '${(sampleRate / 1000).toStringAsFixed(1)} kHz',
    if (_audioQualityTag(audio) case final String tag) tag,
  ];

  return pieces.isEmpty
      ? (media.kind == MediaKind.video ? '本地视频' : '本地音频')
      : pieces.join(' · ');
}

String? _audioQualityTag(MediaStreamProbe? audio) {
  final codec = audio?.codecName?.toLowerCase();
  if (codec == null) {
    return null;
  }
  if (codec == 'flac' ||
      codec == 'alac' ||
      codec == 'wavpack' ||
      codec.startsWith('pcm_')) {
    return '无损';
  }
  final bitRate = audio?.bitRate;
  if ((codec == 'aac' || codec == 'mp3') &&
      bitRate != null &&
      bitRate > 0 &&
      bitRate <= 135000) {
    return '低码率源';
  }
  return null;
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
    this.playbackSourceName,
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

  /// 浏览「当前播放列表」时用于 Tooltip 展示队列来源歌单名。
  final String? playbackSourceName;

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

    final subtitleParts = <String>['$itemCount 首'];
    if (browsingLibrary) {
      subtitleParts.add('$libraryDirCount 个目录');
    } else if (!browsingPlaybackQueue && totalDurationLabel != '--') {
      subtitleParts.add(totalDurationLabel);
    }

    final subtitleLine = subtitleParts.join(' · ');

    final tooltipLines = <String>[
      if (browsingLibrary && totalDurationLabel != '--')
        '合计时长约 $totalDurationLabel',
      if (browsingPlaybackQueue && totalDurationLabel != '--')
        '队列合计约 $totalDurationLabel',
      if (browsingPlaybackQueue &&
          playbackSourceName != null &&
          playbackSourceName!.isNotEmpty)
        '播放来源：$playbackSourceName',
    ];
    final subtitleTooltip =
        tooltipLines.isEmpty ? null : tooltipLines.join('\n');

    final scopeStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      color: Colors.white.withValues(alpha: 0.48),
    );

    Widget titleBlock() {
      final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: Colors.white.withValues(alpha: 0.46),
        letterSpacing: 0.12,
      );
      final subtitle = Text(
        subtitleLine,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: subtitleStyle,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headingLabel.toUpperCase(), style: scopeStyle),
              if (isScanning) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.sync_rounded,
                  size: 13,
                  color: palette.accent.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 4),
                Text(
                  '整理中',
                  style: scopeStyle?.copyWith(
                    color: palette.accent.withValues(alpha: 0.78),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            activePlaylist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 5),
          if (subtitleTooltip case final String tip when tip.isNotEmpty)
            Tooltip(
              message: tip,
              waitDuration: const Duration(milliseconds: 320),
              child: MouseRegion(
                cursor: SystemMouseCursors.help,
                child: subtitle,
              ),
            )
          else
            subtitle,
        ],
      );
    }

    Widget artwork() {
      return Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: palette.accent.withValues(alpha: 0.16)),
        ),
        child: Icon(
          heroIcon,
          size: 23,
          color: heniAccentOnGlass(palette.accent),
        ),
      );
    }

    final controls = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        ...actions,
        _UiStyleSwitch(
          palette: palette,
          active: uiStyle,
          onSelect: onSelectUiStyle,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        return Container(
          padding: EdgeInsets.fromLTRB(
            stacked ? 16 : 18,
            14,
            stacked ? 14 : 16,
            14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                palette.accent.withValues(alpha: 0.075),
                Colors.white.withValues(alpha: 0.025),
                Colors.transparent,
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child:
              stacked
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          artwork(),
                          const SizedBox(width: 14),
                          Expanded(child: titleBlock()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  )
                  : Row(
                    children: [
                      artwork(),
                      const SizedBox(width: 16),
                      Expanded(child: titleBlock()),
                      const SizedBox(width: 16),
                      controls,
                    ],
                  ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.seed.withValues(alpha: 0.22),
            Color.lerp(
              palette.seed,
              palette.accent,
              0.55,
            )!.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.seed.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _SceneryContent extends ConsumerWidget {
  const _SceneryContent({
    required this.palette,
    required this.queue,
    required this.currentMedia,
    required this.mediaProbe,
    required this.engine,
    required this.videoController,
    required this.layout,
    required this.onShowPlaybackQueue,
    required this.onOpenFileLocation,
    required this.onPickMedia,
    required this.onPickFolder,
  });

  final HeniPalette palette;
  final PlaybackQueueState queue;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final PlaybackEngine engine;
  final VideoController videoController;
  final _ShellLayout layout;
  final VoidCallback onShowPlaybackQueue;
  final VoidCallback onOpenFileLocation;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = currentMedia?.kind == MediaKind.video;
    final focusMode = ref.watch(focusModeProvider);

    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: engine.currentPlaying,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return ClipRRect(
          borderRadius: BorderRadius.circular(focusMode ? 0 : 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.surface.withValues(alpha: 0.18),
                      palette.seed.withValues(alpha: 0.06),
                      palette.surfaceAlt.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
              if (!focusMode)
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
                            Colors.black.withValues(alpha: 0.14),
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.20),
                          ],
                          stops: const [0.0, 0.46, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              if (!focusMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.22, 0.15),
                          radius: 1.05,
                          colors: [
                            palette.seed.withValues(
                              alpha: isPlaying ? 0.13 : 0.08,
                            ),
                            palette.accent.withValues(alpha: 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.36, 1.0],
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
              else if (!focusMode)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.narrow ? 10 : 16,
                    layout.narrow ? 10 : 16,
                    layout.narrow ? 10 : 16,
                    layout.narrow ? 10 : 16,
                  ),
                  child: HeniListeningConsole(
                    palette: palette,
                    currentMedia: currentMedia,
                    nextMedia:
                        queue.currentIndex >= 0 &&
                                queue.currentIndex + 1 <
                                    queue.playbackQueue.items.length
                            ? queue.playbackQueue.items[queue.currentIndex + 1]
                            : null,
                    mediaProbe: mediaProbe,
                    isPlaying: isPlaying,
                    libraryItemCount: queue.library.items.length,
                    libraryDirectoryCount: queue.libraryDirectories.length,
                    statusMessage: queue.statusMessage,
                    onLocateCurrent: onShowPlaybackQueue,
                    onOpenFileLocation: onOpenFileLocation,
                    onPickMedia: onPickMedia,
                    onPickFolder: onPickFolder,
                  ),
                ),
              if (!focusMode && currentMedia != null && isVideo)
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: _SceneryInfoBlock(
                    palette: palette,
                    currentMedia: currentMedia,
                    mediaProbe: mediaProbe,
                  ),
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
    final recall = MouseRegion(
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

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: HeniWindowDragRegion(child: SizedBox.expand()),
          ),
          Positioned(left: 0, right: 134, child: recall),
          Positioned(
            right: 6,
            child: HeniWindowControls(
              shellTheme: HeniShellTheme.fromPalette(widget.palette),
            ),
          ),
        ],
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

class _SceneryInfoBlock extends StatelessWidget {
  const _SceneryInfoBlock({
    required this.palette,
    required this.currentMedia,
    required this.mediaProbe,
  });

  final HeniPalette palette;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.042)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 14),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (currentMedia != null) const SizedBox(height: 12),
            Text(
              currentMedia?.title ?? '还没有播放内容',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 38,
                height: 1.08,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.36),
                    blurRadius: 14,
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
                  color: Colors.white.withValues(alpha: 0.64),
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 10),
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
    required this.shellTheme,
    required this.queue,
    required this.layout,
    required this.onPlayIndex,
    required this.onAddToPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onRemoveFromPlaybackQueue,
    required this.onPlayNext,
    required this.onEnqueue,
    required this.onPickFolder,
    required this.onPickMedia,
    required this.onRefreshLibrary,
    required this.onAddFromLibrary,
    required this.onManagePlaylist,
    required this.onSelectUiStyle,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final PlaybackQueueState queue;
  final _ShellLayout layout;
  final ValueChanged<int> onPlayIndex;
  final void Function(String playlistId, MediaItem item) onAddToPlaylist;
  final void Function(String playlistId, MediaItem item) onRemoveFromPlaylist;
  final ValueChanged<int> onRemoveFromPlaybackQueue;
  final void Function(MediaItem item) onPlayNext;
  final void Function(MediaItem item) onEnqueue;
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
              IconButton(
                tooltip: '刷新曲库',
                onPressed:
                    widget.queue.isScanning ? null : widget.onRefreshLibrary,
                icon: Icon(
                  widget.queue.isScanning
                      ? Icons.sync_rounded
                      : Icons.refresh_rounded,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: _secondaryGlassText(emphasis: 1.08),
                ),
              ),
              IconButton(
                tooltip: '导入文件夹',
                onPressed: widget.onPickFolder,
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: _secondaryGlassText(emphasis: 1.08),
                ),
              ),
              IconButton.filled(
                tooltip: '添加文件',
                onPressed: widget.onPickMedia,
                icon: const Icon(Icons.add_rounded, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: _accentControlForeground(context),
                ),
              ),
            ]
            : browsingPlaybackQueue
            ? <Widget>[
              IconButton.filledTonal(
                tooltip: '回到播放界面',
                onPressed:
                    widget.queue.currentItem == null
                        ? null
                        : () => widget.onSelectUiStyle(HeniUiStyle.scenery),
                icon: const Icon(Icons.play_circle_outline, size: 22),
                style: IconButton.styleFrom(
                  minimumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: _stateIconOnGlass(context, active: true),
                ),
              ),
            ]
            : <Widget>[
              IconButton(
                tooltip: '管理歌单',
                onPressed: () => widget.onManagePlaylist(activePlaylist),
                icon: const Icon(Icons.tune_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: _secondaryGlassText(emphasis: 1.08),
                ),
              ),
              IconButton.filled(
                tooltip: '从曲库添加',
                onPressed: () => widget.onAddFromLibrary(activePlaylist.id),
                icon: const Icon(Icons.add_rounded, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: _accentControlForeground(context),
                ),
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
          playbackSourceName:
              browsingPlaybackQueue
                  ? widget.queue
                      .playlistById(widget.queue.playbackSourceId)
                      .name
                  : null,
        ),
        SizedBox(height: widget.layout.contentGap),
        Expanded(
          child: HeniShellSurface(
            shellTheme: widget.shellTheme,
            role: HeniShellSurfaceRole.content,
            radius: 12,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrowToolbar = constraints.maxWidth < 720;
                      final statusWidgets = <Widget>[
                        if (query.isNotEmpty)
                          _InfoPill(
                            icon: Icons.search_rounded,
                            label: '筛出 ${filteredEntries.length} 首',
                          ),
                        if (_selectionMode)
                          _RefreshStatusBadge(
                            icon: Icons.done_all_rounded,
                            label: '已选 $selectedCount 首',
                            accent: true,
                          ),
                      ];
                      final actionWidgets =
                          _selectionMode
                              ? <Widget>[
                                TextButton(
                                  onPressed: items.isEmpty ? null : _selectAll,
                                  child: const Text('全选'),
                                ),
                                FilledButton.tonal(
                                  onPressed:
                                      selectedCount == 0
                                          ? null
                                          : _removeSelected,
                                  child: Text('移除 $selectedCount 首'),
                                ),
                                OutlinedButton(
                                  onPressed: _exitSelectionMode,
                                  child: const Text('取消'),
                                ),
                              ]
                              : <Widget>[
                                PopupMenuButton<_SongsSortMode>(
                                  tooltip: '排序 · ${_sortMode.label}',
                                  icon: Icon(
                                    Icons.sort_rounded,
                                    size: 20,
                                    color: _secondaryGlassText(emphasis: 0.96),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  onSelected: (mode) {
                                    setState(() {
                                      _sortMode = mode;
                                    });
                                  },
                                  itemBuilder:
                                      (context) => [
                                        for (final mode
                                            in _SongsSortMode.values)
                                          PopupMenuItem<_SongsSortMode>(
                                            value: mode,
                                            child: Text(mode.label),
                                          ),
                                      ],
                                ),
                                if (canMultiSelect)
                                  IconButton(
                                    tooltip: '多选',
                                    onPressed: _enterSelectionMode,
                                    icon: Icon(
                                      Icons.checklist_rounded,
                                      size: 20,
                                      color: _secondaryGlassText(
                                        emphasis: 0.96,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                              ];

                      if (narrowToolbar) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (statusWidgets.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: statusWidgets,
                              ),
                            if (statusWidgets.isNotEmpty &&
                                actionWidgets.isNotEmpty)
                              const SizedBox(height: 8),
                            if (actionWidgets.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: actionWidgets,
                                ),
                              ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          if (statusWidgets.isNotEmpty)
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: statusWidgets,
                              ),
                            )
                          else
                            const Spacer(),
                          if (actionWidgets.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: actionWidgets,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  height: 22,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _LibraryTableColumns.forWidth(
                        constraints.maxWidth,
                      );

                      return Row(
                        children: [
                          SizedBox(width: columns.leadWidth),
                          Expanded(
                            child: Text(
                              '曲目',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                          ),
                          SizedBox(width: columns.gap),
                          SizedBox(
                            width: columns.durationWidth,
                            child: Text(
                              '时长',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: Colors.white.withValues(alpha: 0.30),
                              ),
                            ),
                          ),
                          if (columns.showAction) ...[
                            SizedBox(width: columns.gap),
                            SizedBox(width: columns.actionWidth),
                          ],
                        ],
                      );
                    },
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
                                currentPlaylistId: activePlaylist.id,
                                selectionMode: _selectionMode,
                                checked: _selectedPaths.contains(item.path),
                                onPlay:
                                    () =>
                                        _selectionMode
                                            ? _toggleItem(item)
                                            : widget.onPlayIndex(itemIndex),
                                onAddToPlaylist:
                                    (playlistId) => widget.onAddToPlaylist(
                                      playlistId,
                                      item,
                                    ),
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
                                onPlayNext:
                                    browsingPlaybackQueue
                                        ? null
                                        : () => widget.onPlayNext(item),
                                onEnqueue:
                                    browsingPlaybackQueue
                                        ? null
                                        : () => widget.onEnqueue(item),
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
    required this.currentPlaylistId,
    required this.selectionMode,
    required this.checked,
    required this.onPlay,
    required this.onAddToPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onToggleSelect,
    this.onPlayNext,
    this.onEnqueue,
  });

  final MediaItem item;
  final int index;
  final bool selected;
  final bool browsingLibrary;
  final bool browsingPlaybackQueue;
  final List<HeniPlaylist> playlists;

  /// 当前正在浏览的歌单 id（曲库/队列时为对应特殊 id），用于在“加入歌单”里排除自身。
  final String currentPlaylistId;
  final bool selectionMode;
  final bool checked;
  final VoidCallback onPlay;
  final ValueChanged<String> onAddToPlaylist;
  final VoidCallback onRemoveFromPlaylist;
  final VoidCallback onToggleSelect;
  final VoidCallback? onPlayNext;
  final VoidCallback? onEnqueue;

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
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.085)
            : checked
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
            : _hovered
            ? Colors.white.withValues(alpha: 0.034)
            : Colors.white.withValues(alpha: evenRow ? 0.010 : 0.003);
    final borderColor =
        playing
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.17)
            : checked
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.11)
            : _hovered
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.transparent;
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
        scale: 1,
        child: AnimatedSlide(
          duration: _hoverDuration,
          curve: _hoverCurve,
          offset: Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: rowColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
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
                            ? 3
                            : checked
                            ? 2
                            : _hovered
                            ? 1
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.018),
                    splashColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    highlightColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.04),
                    onTap: widget.onPlay,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _LibraryTableColumns.forWidth(
                          constraints.maxWidth,
                        );
                        final compactLead = columns.leadWidth < 58;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: columns.leadWidth,
                                child: Row(
                                  mainAxisAlignment:
                                      compactLead
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.start,
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
                                                    (_) =>
                                                        widget.onToggleSelect(),
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
                                                      child: StreamBuilder<
                                                        bool
                                                      >(
                                                        stream:
                                                            ref
                                                                .read(
                                                                  playbackEngineProvider,
                                                                )
                                                                .playing,
                                                        initialData:
                                                            ref
                                                                .read(
                                                                  playbackEngineProvider,
                                                                )
                                                                .currentPlaying,
                                                        builder: (
                                                          context,
                                                          snap,
                                                        ) {
                                                          return _NowPlayingWave(
                                                            color: leadingColor,
                                                            active:
                                                                snap.data ??
                                                                false,
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
                                                key: ValueKey(
                                                  'index-${widget.index}',
                                                ),
                                                width: 26,
                                                child: Text(
                                                  '${widget.index + 1}',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.34,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                    ),
                                    if (!compactLead) ...[
                                      SizedBox(
                                        width: columns.compactAction ? 6 : 10,
                                      ),
                                      AnimatedContainer(
                                        duration: _hoverDuration,
                                        width: columns.compactAction ? 25 : 28,
                                        height: columns.compactAction ? 28 : 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color:
                                              playing
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.14)
                                                  : checked
                                                  ? Colors.white.withValues(
                                                    alpha: 0.14,
                                                  )
                                                  : Colors.white.withValues(
                                                    alpha:
                                                        hoverOrSelected
                                                            ? 0.16
                                                            : 0.07,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          widget.item.kind == MediaKind.video
                                              ? Icons.movie_outlined
                                              : Icons.music_note_outlined,
                                          size: 13,
                                          color:
                                              playing
                                                  ? heniAccentOnGlass(
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  )
                                                  : Colors.white.withValues(
                                                    alpha: 0.82,
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (columns.showPath) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        p.dirname(widget.item.path),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 10.7,
                                              color:
                                                  checked
                                                      ? Colors.white.withValues(
                                                        alpha: 0.52,
                                                      )
                                                      : Colors.white.withValues(
                                                        alpha: 0.34,
                                                      ),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(width: columns.gap),
                              SizedBox(
                                width: columns.durationWidth,
                                child: _StableTimeText(
                                  text: _formatDuration(widget.item.duration),
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    fontFeatures: const [
                                      ui.FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              if (columns.showAction) ...[
                                SizedBox(width: columns.gap),
                                SizedBox(
                                  width: columns.actionWidth,
                                  child:
                                      widget.selectionMode
                                          ? Align(
                                            alignment: Alignment.centerLeft,
                                            child: AnimatedContainer(
                                              duration: _hoverDuration,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    widget.checked
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.14,
                                                            )
                                                        : Colors.white
                                                            .withValues(
                                                              alpha: 0.04,
                                                            ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color:
                                                      widget.checked
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.22,
                                                              )
                                                          : Colors.white
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                ),
                                              ),
                                              child: Text(
                                                columns.compactAction
                                                    ? (widget.checked
                                                        ? '已选'
                                                        : '选')
                                                    : (widget.checked
                                                        ? '已选择'
                                                        : '选择'),
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color:
                                                          widget.checked
                                                              ? heniAccentOnGlass(
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                              )
                                                              : Colors.white
                                                                  .withValues(
                                                                    alpha: 0.42,
                                                                  ),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          )
                                          : Align(
                                            alignment: Alignment.centerLeft,
                                            child: AnimatedOpacity(
                                              duration: _hoverDuration,
                                              opacity:
                                                  hoverOrSelected ? 1 : 0.8,
                                              child: _SongRowMenu(
                                                item: widget.item,
                                                targetPlaylists: [
                                                  for (final pl
                                                      in widget.playlists)
                                                    if (pl.id !=
                                                        widget
                                                            .currentPlaylistId)
                                                      pl,
                                                ],
                                                onAddToPlaylist:
                                                    widget.onAddToPlaylist,
                                                onPlayNext: widget.onPlayNext,
                                                onEnqueue: widget.onEnqueue,
                                                onRemove:
                                                    widget.browsingLibrary
                                                        ? null
                                                        : widget
                                                            .onRemoveFromPlaylist,
                                                removeLabel:
                                                    widget.browsingPlaybackQueue
                                                        ? '从播放列表移除'
                                                        : '从该歌单移除',
                                                active: hoverOrSelected,
                                                compact: columns.compactAction,
                                              ),
                                            ),
                                          ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StableTimeText extends StatelessWidget {
  const _StableTimeText({
    required this.text,
    required this.textAlign,
    required this.style,
  });

  final String text;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final alignment =
        textAlign == TextAlign.right
            ? Alignment.centerRight
            : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: style,
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

sealed class _SongMenuAction {
  const _SongMenuAction();
}

class _PlaySongNext extends _SongMenuAction {
  const _PlaySongNext();
}

class _EnqueueSong extends _SongMenuAction {
  const _EnqueueSong();
}

class _AddSongToPlaylist extends _SongMenuAction {
  const _AddSongToPlaylist(this.playlistId);
  final String playlistId;
}

class _RemoveSongFromCurrent extends _SongMenuAction {
  const _RemoveSongFromCurrent();
}

/// 歌曲行的「更多操作」菜单：下一首播放、加到当前播放列表、
/// 快捷加入其它歌单，以及（在歌单/队列里）从当前位置移除。
class _SongRowMenu extends StatelessWidget {
  const _SongRowMenu({
    required this.item,
    required this.targetPlaylists,
    required this.onAddToPlaylist,
    required this.active,
    this.onPlayNext,
    this.onEnqueue,
    this.onRemove,
    this.removeLabel,
    this.compact = false,
  });

  final MediaItem item;
  final List<HeniPlaylist> targetPlaylists;
  final ValueChanged<String> onAddToPlaylist;
  final bool active;
  final VoidCallback? onPlayNext;
  final VoidCallback? onEnqueue;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final bool compact;

  bool _contains(HeniPlaylist playlist) {
    final key = item.path.toLowerCase();
    return playlist.items.any((it) => it.path.toLowerCase() == key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dangerColor = const Color(0xFFFF6B6B);

    PopupMenuItem<_SongMenuAction> buildAction({
      required _SongMenuAction value,
      required IconData icon,
      required String label,
    }) {
      return PopupMenuItem<_SongMenuAction>(
        value: value,
        height: 42,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: heniAccentOnGlass(primary, alpha: 0.86),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasQueueActions = onPlayNext != null || onEnqueue != null;

    return PopupMenuButton<_SongMenuAction>(
      tooltip: '更多操作',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      splashRadius: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.06),
        const Color(0xFF1A1B1F),
      ),
      constraints: const BoxConstraints(minWidth: 208, maxWidth: 268),
      onSelected: (action) {
        switch (action) {
          case _PlaySongNext():
            onPlayNext?.call();
          case _EnqueueSong():
            onEnqueue?.call();
          case _AddSongToPlaylist(:final playlistId):
            onAddToPlaylist(playlistId);
          case _RemoveSongFromCurrent():
            onRemove?.call();
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<_SongMenuAction>>[
          if (hasQueueActions) ...[
            if (onPlayNext != null)
              buildAction(
                value: const _PlaySongNext(),
                icon: Icons.playlist_play_rounded,
                label: '下一首播放',
              ),
            if (onEnqueue != null)
              buildAction(
                value: const _EnqueueSong(),
                icon: Icons.queue_music_rounded,
                label: '加到当前播放列表',
              ),
            if (targetPlaylists.isNotEmpty || onRemove != null)
              const PopupMenuDivider(height: 8),
          ],
          if (targetPlaylists.isNotEmpty) ...[
            PopupMenuItem<_SongMenuAction>(
              enabled: false,
              height: 30,
              child: Text(
                '加入歌单',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final playlist in targetPlaylists)
              () {
                final already = _contains(playlist);
                return PopupMenuItem<_SongMenuAction>(
                  value: already ? null : _AddSongToPlaylist(playlist.id),
                  enabled: !already,
                  height: 42,
                  child: Row(
                    children: [
                      Icon(
                        already
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 18,
                        color:
                            already
                                ? heniAccentOnGlass(primary, alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.74),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                already
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (already)
                        Text(
                          '已加入',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                );
              }(),
            if (onRemove != null) const PopupMenuDivider(height: 8),
          ],
          if (onRemove != null)
            PopupMenuItem<_SongMenuAction>(
              value: const _RemoveSongFromCurrent(),
              height: 42,
              child: Row(
                children: [
                  Icon(
                    Icons.remove_circle_outline,
                    size: 18,
                    color: dangerColor.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    removeLabel ?? '移除',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: dangerColor.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      child: AnimatedContainer(
        duration: _hoverDuration,
        width: compact ? 32 : 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              active
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                active
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: active ? 0.82 : 0.55),
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
      child: AnimatedScale(
        duration: _hoverDuration,
        curve: _hoverCurve,
        scale: highlighted ? 1.02 : 1.0,
        child: AnimatedContainer(
          duration: _hoverDuration,
          curve: _hoverCurve,
          decoration: BoxDecoration(
            color:
                highlighted
                    ? foreground.withValues(alpha: widget.danger ? 0.14 : 0.16)
                    : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  highlighted
                      ? foreground.withValues(
                        alpha: widget.danger ? 0.24 : 0.22,
                      )
                      : Colors.white.withValues(alpha: 0.04),
            ),
            boxShadow: [
              if (highlighted)
                BoxShadow(
                  color: foreground.withValues(
                    alpha: widget.danger ? 0.10 : 0.08,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: IconButton(
            onPressed: widget.onPressed,
            style: IconButton.styleFrom(
              foregroundColor:
                  highlighted
                      ? foreground
                      : Colors.white.withValues(alpha: 0.62),
              fixedSize: const Size.square(_denseIconButtonSize),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(widget.icon, size: _compactIconSize),
          ),
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
    required this.shellTheme,
    required this.currentMedia,
    required this.mediaProbe,
    required this.queue,
    required this.engine,
    required this.layout,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onShowPlaybackQueue,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final MediaItem? currentMedia;
  final AsyncValue<MediaProbe?> mediaProbe;
  final PlaybackQueueState queue;
  final PlaybackEngine engine;
  final _ShellLayout layout;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onShowPlaybackQueue;
  final ValueChanged<double> onPersistVolume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusMode = ref.watch(focusModeProvider);
    final windowWidth = MediaQuery.sizeOf(context).width;
    final compactBottom = shouldUseCompactBottomBar(
      windowWidth: windowWidth,
      focusMode: focusMode,
      verticallyDense: layout.quiet,
    );

    return _ShellBand(
      shellTheme: shellTheme,
      role: HeniShellSurfaceRole.dock,
      margin: EdgeInsets.fromLTRB(
        layout.topHorizontalMargin,
        0,
        layout.topHorizontalMargin,
        layout.narrow ? 6 : 10,
      ),
      padding: EdgeInsets.fromLTRB(
        layout.narrow ? 10 : 16,
        compactBottom ? 7 : 5,
        layout.narrow ? 10 : 16,
        compactBottom ? 7 : 5,
      ),
      height:
          compactBottom
              ? layout.narrow
                  ? 66
                  : 72
              : layout.bottomHeight,
      radius: 12,
      child:
          compactBottom
              ? _CompactBottomBar(
                palette: palette,
                shellTheme: shellTheme,
                currentMedia: currentMedia,
                engine: engine,
                queue: queue,
                onPreviousTrack: onPreviousTrack,
                onNextTrack: onNextTrack,
                onToggleShuffle: onToggleShuffle,
                onCycleRepeat: onCycleRepeat,
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
                          palette: palette,
                          shuffle: queue.shuffle,
                          repeatMode: queue.repeatMode,
                          enabled: queue.playbackQueue.items.isNotEmpty,
                          onPreviousTrack: onPreviousTrack,
                          onNextTrack: onNextTrack,
                          onToggleShuffle: onToggleShuffle,
                          onCycleRepeat: onCycleRepeat,
                        ),
                        const SizedBox(height: 4),
                        PlayerProgressWithTime(
                          engine: engine,
                          palette: palette,
                          fallbackDuration:
                              currentMedia?.duration ??
                              mediaProbe.when(
                                data: (probe) => probe?.duration,
                                error: (error, stackTrace) => null,
                                loading: () => null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: layout.quiet ? 10 : 16),
                  _UtilityControls(
                    palette: palette,
                    shellTheme: shellTheme,
                    engine: engine,
                    queue: queue,
                    onShowPlaybackQueue: onShowPlaybackQueue,
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
    required this.shellTheme,
    required this.currentMedia,
    required this.engine,
    required this.queue,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onShowPlaybackQueue,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final MediaItem? currentMedia;
  final PlaybackEngine engine;
  final PlaybackQueueState queue;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onShowPlaybackQueue;
  final ValueChanged<double> onPersistVolume;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: engine.currentPlaying,
      builder: (context, snap) {
        final isPlaying = snap.data ?? false;
        return LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxWidth < 780;
            final veryTight = constraints.maxWidth < 680;
            final tiny = constraints.maxWidth < 560;
            final ultraTiny = constraints.maxWidth < 460;
            final controlSize = tight ? 36.0 : _regularIconButtonSize;
            final playSize = tight ? 38.0 : 42.0;
            final iconSize = tight ? 20.0 : 22.0;
            final artworkSize = tight ? 34.0 : 40.0;

            Widget compactIcon({
              required String tooltip,
              required VoidCallback onPressed,
              required IconData icon,
            }) {
              return IconButton(
                tooltip: tooltip,
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize),
                style: IconButton.styleFrom(
                  fixedSize: Size.square(controlSize),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }

            return Row(
              children: [
                if (!veryTight) ...[
                  _NowPlayingArtwork(
                    size: artworkSize,
                    isVideo: currentMedia?.kind == MediaKind.video,
                    isPlaying: isPlaying,
                    hasMedia: currentMedia != null,
                    palette: palette,
                  ),
                  SizedBox(width: tight ? 8 : 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentMedia?.title ?? '未播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tight ? 12.8 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PlayerProgressWithTime(
                        engine: engine,
                        palette: palette,
                        fallbackDuration: currentMedia?.duration,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tight ? 8 : 12),
                HeniPlaybackModeControls(
                  palette: palette,
                  shuffle: queue.shuffle,
                  repeatMode: queue.repeatMode,
                  enabled: queue.playbackQueue.items.isNotEmpty,
                  onToggleShuffle: onToggleShuffle,
                  onCycleRepeat: onCycleRepeat,
                  size: ultraTiny ? 32 : controlSize,
                  iconSize: tight ? 18 : 20,
                  gap: tight ? 0 : 2,
                  transport: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!tiny)
                        compactIcon(
                          tooltip: '上一首',
                          onPressed: onPreviousTrack,
                          icon: Icons.skip_previous_rounded,
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: heniBrandGradient(palette),
                          boxShadow: [
                            BoxShadow(
                              color: palette.seed.withValues(
                                alpha: isPlaying ? 0.22 : 0.10,
                              ),
                              blurRadius: 12,
                              spreadRadius: isPlaying ? 1 : 0,
                            ),
                          ],
                        ),
                        child: IconButton.filled(
                          tooltip: isPlaying ? '暂停' : '播放',
                          onPressed: () {
                            if (isPlaying) {
                              unawaited(engine.pause());
                            } else {
                              unawaited(engine.play());
                            }
                          },
                          style: IconButton.styleFrom(
                            fixedSize: Size.square(playSize),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            foregroundColor: heniReadableForegroundOn(
                              palette.seed,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: iconSize,
                          ),
                        ),
                      ),
                      if (!tiny)
                        compactIcon(
                          tooltip: '下一首',
                          onPressed: onNextTrack,
                          icon: Icons.skip_next_rounded,
                        ),
                    ],
                  ),
                ),
                SizedBox(width: tight ? 2 : 6),
                if (!veryTight) ...[
                  const SizedBox(width: 4),
                  HeniVolumeControl(
                    engine: engine,
                    palette: palette,
                    shellTheme: shellTheme,
                    onVolumeCommitted: onPersistVolume,
                  ),
                ],
                if (!tiny)
                  compactIcon(
                    tooltip: '播放队列',
                    onPressed: onShowPlaybackQueue,
                    icon: Icons.queue_music_rounded,
                  ),
              ],
            );
          },
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
              ? 210
              : layout.compact
              ? 232
              : 252,
      child: StreamBuilder<bool>(
        stream: engine.playing,
        initialData: engine.currentPlaying,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? false;
          final qualityLine = mediaProbe.when(
            data: (probe) => _playbackQualityLine(currentMedia, probe),
            loading: () => currentMedia == null ? '等待播放' : '正在读取音频参数',
            error:
                (error, stackTrace) =>
                    currentMedia?.kind == MediaKind.video ? '本地视频' : '本地音频',
          );

          final discSize = layout.quiet ? 46.0 : 52.0;
          final isVideo = currentMedia?.kind == MediaKind.video;

          return Row(
            children: [
              _NowPlayingArtwork(
                size: discSize,
                isVideo: isVideo,
                isPlaying: isPlaying,
                hasMedia: currentMedia != null,
                palette: palette,
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
                            theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9.6,
                              color: heniAccentOnGlass(
                                palette.accent,
                                alpha: isPlaying ? 0.92 : 0.62,
                              ),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ) ??
                            const TextStyle(),
                        child: Text(
                          currentMedia == null ? '等待播放' : '正在播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: _Gap.xs + 1),
                      Text(
                        currentMedia?.title ?? '未播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: layout.quiet ? 15 : 16.4,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      if (layout.showNowPlayingDetails) ...[
                        const SizedBox(height: 4),
                        Text(
                          qualityLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.46),
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
  });

  final double size;
  final bool isVideo;
  final bool isPlaying;
  final bool hasMedia;
  final HeniPalette palette;

  @override
  State<_NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<_NowPlayingArtwork>
    with TickerProviderStateMixin {
  late AnimationController _breath;
  late AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.isPlaying) {
      _breath.repeat(reverse: true);
      _wave.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _NowPlayingArtwork old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
      _wave.repeat();
    } else if (!widget.isPlaying && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _wave.dispose();
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
                        alpha: widget.isPlaying ? 0.22 + 0.18 * pulse : 0.10,
                      ),
                      blurRadius: 18 + 8 * pulse,
                      spreadRadius: widget.isPlaying ? 1 : 0,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CustomPaint(
              painter: _ArtworkRingPainter(
                seedColor: p.seed,
                accentColor: p.accent,
                active: widget.hasMedia,
              ),
            ),
          ),
          if (widget.hasMedia)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _wave,
                builder: (context, _) {
                  return SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CustomPaint(
                      painter: _SpectrumRingPainter(
                        progress: _wave.value,
                        playing: widget.isPlaying,
                        seedColor: p.seed,
                        accentColor: p.accent,
                      ),
                    ),
                  );
                },
              ),
            ),
          widget.isVideo
              ? Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    p.seed.withValues(alpha: widget.isPlaying ? 0.24 : 0.18),
                    p.surfaceAlt,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: p.seed.withValues(
                      alpha: widget.isPlaying ? 0.42 : 0.32,
                    ),
                  ),
                ),
                child: Icon(Icons.movie_outlined, size: widget.size * 0.42),
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
    required this.seedColor,
    required this.accentColor,
    required this.active,
  });

  final Color seedColor;
  final Color accentColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final outerHint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = seedColor.withValues(alpha: active ? 0.14 : 0.06);
    canvas.drawCircle(center, radius + 0.4, outerHint);

    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: active ? 0.11 : 0.065);
    canvas.drawCircle(center, radius, trackPaint);

    if (!active) return;

    final accentRing =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: [
              seedColor.withValues(alpha: 0.35),
              accentColor.withValues(alpha: 0.22),
              seedColor.withValues(alpha: 0.35),
            ],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect);
    canvas.drawCircle(center, radius, accentRing);
  }

  @override
  bool shouldRepaint(covariant _ArtworkRingPainter old) {
    return old.seedColor != seedColor ||
        old.accentColor != accentColor ||
        old.active != active;
  }
}

/// Heni 的视觉签名：环绕封面的一圈圆形频谱，
/// 播放时随一条环游的行波起伏，暂停时收成平静的细齿。
class _SpectrumRingPainter extends CustomPainter {
  const _SpectrumRingPainter({
    required this.progress,
    required this.playing,
    required this.seedColor,
    required this.accentColor,
  });

  final double progress;
  final bool playing;
  final Color seedColor;
  final Color accentColor;

  static const _bars = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // 把频谱齿放进封面边缘与外圈之间的窄带里，避免越出布局尺寸。
    final baseRadius = size.width / 2 - 6.0;
    final t = progress * 2 * math.pi;

    for (var i = 0; i < _bars; i++) {
      final frac = i / _bars;
      final angle = frac * 2 * math.pi - math.pi / 2;

      // 两条相位不同的正弦叠加，制造环游的“行波”律动。
      final wave =
          0.5 +
          0.5 *
              (0.6 * math.sin(frac * 2 * math.pi * 3 - t) +
                  0.4 * math.sin(frac * 2 * math.pi * 5 + t * 1.3));
      final amp = playing ? wave.clamp(0.0, 1.0) : 0.12;
      final barLen = playing ? (1.0 + amp * 4.4) : 1.4;

      final inner = baseRadius;
      final outer = baseRadius + barLen;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final p1 = Offset(center.dx + cosA * inner, center.dy + sinA * inner);
      final p2 = Offset(center.dx + cosA * outer, center.dy + sinA * outer);

      final color =
          Color.lerp(seedColor, accentColor, (math.sin(angle) + 1) / 2)!;
      final paint =
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.7
            ..color = color.withValues(
              alpha: playing ? (0.30 + amp * 0.55) : 0.18,
            );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumRingPainter old) {
    return old.progress != progress ||
        old.playing != playing ||
        old.seedColor != seedColor ||
        old.accentColor != accentColor;
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
                  color: p.seed.withValues(
                    alpha: widget.spinning ? 0.32 : 0.18,
                  ),
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
                      colors: [Color.lerp(p.accent, p.seed, 0.3)!, p.seed],
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
    required this.shellTheme,
    required this.engine,
    required this.queue,
    required this.onShowPlaybackQueue,
    required this.onPersistVolume,
  });

  final HeniPalette palette;
  final HeniShellTheme shellTheme;
  final PlaybackEngine engine;
  final PlaybackQueueState queue;
  final VoidCallback onShowPlaybackQueue;
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
        const SizedBox(width: 4),
        HeniVolumeControl(
          engine: engine,
          palette: palette,
          shellTheme: shellTheme,
          onVolumeCommitted: onPersistVolume,
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
        curve: _hoverCurve,
        decoration: BoxDecoration(
          color:
              hasCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.11)
                  : Colors.white.withValues(alpha: 0.018),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                hasCurrent
                    ? theme.colorScheme.primary.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_regularIconButtonSize),
            padding: EdgeInsets.zero,
            foregroundColor:
                hasCurrent
                    ? _stateIconOnGlass(context, active: true)
                    : _secondaryGlassText(),
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
                      horizontal: 4.5,
                      vertical: 1.5,
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
                        fontSize: 10,
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
  final _listController = ScrollController();
  final _currentRowKey = GlobalKey();
  Timer? _highlightTimer;
  var _query = '';
  var _scheduledInitialLocate = false;
  var _highlightCurrent = false;
  String? _locateMessage;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _locateCurrentTrack(PlaybackQueueState queue) async {
    final locateState = currentTrackLocateState(
      items: queue.playbackQueue.items,
      currentIndex: queue.currentIndex,
      query: _query,
    );
    if (locateState == CurrentTrackLocateState.unavailable) {
      setState(() => _locateMessage = '当前没有正在播放的曲目');
      return;
    }
    if (locateState == CurrentTrackLocateState.hiddenByFilter) {
      setState(() => _locateMessage = '当前曲目被搜索条件隐藏；清除搜索后即可定位');
      return;
    }
    if (_locateMessage != null) {
      setState(() => _locateMessage = null);
    }

    final visibleItems =
        queue.playbackQueue.items
            .where((item) => _matchesQueueQuery(item, _query))
            .toList();
    final currentPath = queue.playbackQueue.items[queue.currentIndex].path;
    final visibleIndex = visibleItems.indexWhere(
      (item) => item.path == currentPath,
    );
    if (visibleIndex < 0) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    if (_currentRowKey.currentContext == null && _listController.hasClients) {
      final lastIndex = math.max(1, visibleItems.length - 1);
      final fraction = visibleIndex / lastIndex;
      final estimatedOffset =
          _listController.position.maxScrollExtent * fraction;
      await _listController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
    }

    final rowContext = _currentRowKey.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(
        rowContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    if (!mounted) {
      return;
    }
    _highlightTimer?.cancel();
    setState(() => _highlightCurrent = true);
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _highlightCurrent = false);
      }
    });
  }

  bool _matchesQueueQuery(MediaItem item, String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        item.title.toLowerCase().contains(normalized) ||
        item.path.toLowerCase().contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playbackQueueControllerProvider);
    final theme = Theme.of(context);
    final palette = ref.watch(activePaletteProvider);
    final shellTheme = HeniShellTheme.fromPalette(palette);
    final allItems = queue.playbackQueue.items;
    final items =
        allItems.where((item) => _matchesQueueQuery(item, _query)).toList();
    final current = queue.currentItem;

    if (!_scheduledInitialLocate && current != null && _query.isEmpty) {
      _scheduledInitialLocate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_locateCurrentTrack(queue));
        }
      });
    }

    return _HeniDialog(
      title: const Text('当前播放列表'),
      content: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: 620,
            height: playbackQueueDialogContentHeight(constraints.maxHeight),
            child: Column(
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value.trim();
                            _locateMessage = null;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: '搜索当前播放列表',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '定位当前歌曲',
                      onPressed:
                          current == null
                              ? null
                              : () => unawaited(_locateCurrentTrack(queue)),
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topLeft,
                  child:
                      _locateMessage == null
                          ? const SizedBox.shrink()
                          : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_alt_outlined,
                                  size: 15,
                                  color: shellTheme.secondaryText,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _locateMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: shellTheme.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
                const SizedBox(height: 14),
                Expanded(
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
                            controller: _listController,
                            itemCount: items.length,
                            separatorBuilder:
                                (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final actualIndex = allItems.indexOf(item);
                              final isCurrent =
                                  actualIndex == queue.currentIndex;

                              return KeyedSubtree(
                                key:
                                    isCurrent
                                        ? _currentRowKey
                                        : ValueKey(item.path),
                                child: _PlaybackQueueRow(
                                  item: item,
                                  index: index,
                                  isCurrent: isCurrent,
                                  locateHighlighted:
                                      isCurrent && _highlightCurrent,
                                  shellTheme: shellTheme,
                                  onPlay: () {
                                    Navigator.of(context).pop();
                                    unawaited(
                                      ref
                                          .read(
                                            playbackQueueControllerProvider
                                                .notifier,
                                          )
                                          .playQueueIndex(actualIndex),
                                    );
                                  },
                                  onRemove: () {
                                    unawaited(
                                      ref
                                          .read(
                                            playbackQueueControllerProvider
                                                .notifier,
                                          )
                                          .removePlaybackQueueItemAt(
                                            actualIndex,
                                          ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          );
        },
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
    required this.locateHighlighted,
    required this.shellTheme,
    required this.onPlay,
    required this.onRemove,
  });

  final MediaItem item;
  final int index;
  final bool isCurrent;
  final bool locateHighlighted;
  final HeniShellTheme shellTheme;
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
              widget.locateHighlighted
                  ? widget.shellTheme.selected
                  : active
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
                                    stream:
                                        ref
                                            .read(playbackEngineProvider)
                                            .playing,
                                    initialData:
                                        ref
                                            .read(playbackEngineProvider)
                                            .currentPlaying,
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
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w700,
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
          if (primaryAudio?.bitRate case final int bitRate when bitRate > 0)
            '${(bitRate / 1000).round()} kbps',
          if (primaryAudio?.sampleRate case final int sampleRate)
            sampleRate % 1000 == 0
                ? '${sampleRate ~/ 1000} kHz'
                : '${(sampleRate / 1000).toStringAsFixed(1)} kHz',
          if (primaryAudio?.channels case final int channels)
            channels == 1 ? '单声道' : '$channels 声道',
          if (_audioQualityTag(primaryAudio) case final String tag) tag,
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
            final opacity = (1.0 - t) * (widget.active ? 0.42 : 0.0);
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
    required this.palette,
    required this.shuffle,
    required this.repeatMode,
    required this.enabled,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
  });

  final PlaybackEngine engine;
  final HeniPalette palette;
  final bool shuffle;
  final HeniRepeatMode repeatMode;
  final bool enabled;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: engine.playing,
      initialData: engine.currentPlaying,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return HeniPlaybackModeControls(
          palette: palette,
          shuffle: shuffle,
          repeatMode: repeatMode,
          enabled: enabled,
          onToggleShuffle: onToggleShuffle,
          onCycleRepeat: onCycleRepeat,
          gap: 8,
          transport: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TransportButton(
                tooltip: '上一首',
                onPressed: onPreviousTrack,
                icon: Icons.skip_previous_rounded,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        gradient: heniBrandGradient(palette),
                        boxShadow: [
                          BoxShadow(
                            color: palette.seed.withValues(
                              alpha: playing ? 0.24 : 0.12,
                            ),
                            blurRadius: playing ? 18 : 10,
                            spreadRadius: playing ? 2 : 0,
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
                          fixedSize: const Size.square(44),
                          backgroundColor: Colors.transparent,
                          foregroundColor: heniReadableForegroundOn(
                            palette.seed,
                          ),
                        ),
                        iconSize: 22,
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
          ),
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
          color: Colors.white.withValues(alpha: 0.022),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_regularIconButtonSize),
            padding: EdgeInsets.zero,
            foregroundColor: _primaryGlassText(),
          ),
          icon: Icon(icon, size: 22),
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

class _CompactPaletteButtonState extends ConsumerState<_CompactPaletteButton> {
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
    final selectedMarkColor = heniReadableForegroundOn(palette.seed);

    return AnimatedContainer(
      duration: _hoverDuration,
      curve: _hoverCurve,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: palette.seed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              selected
                  ? selectedMarkColor.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.24),
          width: selected ? 2.2 : 1,
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
      child: Center(
        child: AnimatedContainer(
          duration: _hoverDuration,
          curve: _hoverCurve,
          width: selected ? 7 : 0,
          height: selected ? 7 : 0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selectedMarkColor.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: selectedMarkColor.withValues(alpha: 0.22),
                blurRadius: 6,
              ),
            ],
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
      width: 132,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                        palette.accent.withValues(alpha: 0.92),
                        Color.lerp(palette.accent, palette.seed, 0.36)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.20),
                        blurRadius: 8,
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
                                        ? heniReadableForegroundOn(
                                          palette.accent,
                                        )
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
                                              palette.accent,
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
