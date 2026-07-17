import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heni/services/window/heni_window_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('heni/window');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isMaximized') {
            return false;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the four native window actions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(heniWindowControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    calls.clear();

    await controller.minimize();
    await controller.toggleMaximize();
    await controller.beginDrag();
    await controller.close();

    expect(calls.map((call) => call.method), [
      'minimize',
      'toggleMaximize',
      'isMaximized',
      'beginDrag',
      'close',
    ]);
  });

  test('updates state from maximizedChanged', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(heniWindowControllerProvider);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'heni/window',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('maximizedChanged', true),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(heniWindowControllerProvider), isTrue);
  });

  test('close reports a native channel failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'close') {
            throw PlatformException(code: 'close-failed');
          }
          if (call.method == 'isMaximized') {
            return false;
          }
          return null;
        });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final closed =
        await container.read(heniWindowControllerProvider.notifier).close();

    expect(closed, isFalse);
  });
}
