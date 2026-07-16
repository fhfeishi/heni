import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> minimize() => _invoke('minimize');

  Future<void> close() => _invoke('close');

  Future<void> beginDrag() => _invoke('beginDrag');

  Future<void> toggleMaximize() async {
    await _invoke('toggleMaximize');
    await _readMaximized();
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

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      debugPrint('Heni window action $method failed: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Heni window action $method unavailable: $error');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'maximizedChanged') {
      state = call.arguments == true;
    }
  }
}
