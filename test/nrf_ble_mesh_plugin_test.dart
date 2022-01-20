import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_mesh_plugin/nrf_ble_mesh_plugin.dart';

void main() {
  const MethodChannel channel = MethodChannel('nrf_ble_mesh_plugin');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await NrfBleMeshPlugin.instance.platformVersion, '42');
  });
}
