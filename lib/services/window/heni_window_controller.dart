import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HeniWindowResizeResult {
  const HeniWindowResizeResult({
    required this.achievedLogicalWidth,
    required this.reachedRequestedWidth,
  });

  const HeniWindowResizeResult.failure()
    : achievedLogicalWidth = 0,
      reachedRequestedWidth = false;

  final double achievedLogicalWidth;
  final bool reachedRequestedWidth;
}

final heniWindowControllerProvider =
    NotifierProvider<HeniWindowController, bool>(HeniWindowController.new);

class HeniWindowController extends Notifier<bool> {
  static const MethodChannel _channel = MethodChannel('heni/window');

  @override
  bool build() {
    _channel.setMethodCallHandler(_handleNativeCall);
    ref.onDispose(() {
      _channel.setMethodCallHandler(null);
    });
    unawaited(_readMaximized());
    return false;
  }

  Future<void> minimize() async {
    await _invoke('minimize');
  }

  Future<bool> close() => _invoke('close');

  Future<void> beginDrag() async {
    await _invoke('beginDrag');
  }

  Future<void> toggleMaximize() async {
    await _invoke('toggleMaximize');
    await _readMaximized();
  }

  Future<HeniWindowResizeResult> ensureClientWidth(double logicalWidth) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'ensureClientWidth',
        <String, Object?>{'logicalWidth': logicalWidth},
      );
      return HeniWindowResizeResult(
        achievedLogicalWidth:
            (result?['achievedLogicalWidth'] as num?)?.toDouble() ?? 0,
        reachedRequestedWidth: result?['reachedRequestedWidth'] == true,
      );
    } on PlatformException catch (error) {
      debugPrint('Heni window resize failed: $error');
      return const HeniWindowResizeResult.failure();
    } on MissingPluginException catch (error) {
      debugPrint('Heni window resize unavailable: $error');
      return const HeniWindowResizeResult.failure();
    }
  }

  Future<void> _readMaximized() async {
    try {
      state = await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Heni window state unavailable: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Heni window channel unavailable: $error');
    }
  }

  Future<bool> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
      return true;
    } on PlatformException catch (error) {
      debugPrint('Heni window action $method failed: $error');
      return false;
    } on MissingPluginException catch (error) {
      debugPrint('Heni window action $method unavailable: $error');
      return false;
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'maximizedChanged') {
      state = call.arguments == true;
    }
  }
}
