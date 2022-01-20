
import 'dart:async';

import 'package:flutter/services.dart';

typedef ResultCallback = void Function(Map<dynamic, dynamic> data);

class NrfBleMeshPlugin {
  static const MethodChannel _channel =
      const MethodChannel('nrf_ble_mesh_plugin');

  static const EventChannel _eventChannel = EventChannel('nrf_ble_mesh_plugin_event_channel');

  NrfBleMeshPlugin._() {
    _channel.setMethodCallHandler(null);

    _eventChannel
        .receiveBroadcastStream()
        .listen(resultCallbackHandler);
  }

  ResultCallback? _resultCallback;
  // ResultCallback? _resultErrorCallback;

  static NrfBleMeshPlugin _instance = new NrfBleMeshPlugin._();
  static NrfBleMeshPlugin get instance => _instance;


  void onMessageReceived(
      {ResultCallback? resultCallback}) {
    _resultCallback = resultCallback;
  }


  Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<bool> initMeshNetworkManager() async {
    final bool isSuccess = await _channel.invokeMethod('initMeshNetworkManager');
      return isSuccess;
  }

  Future<bool> createOrLoadSavedMeshNetwork() async {
    final bool isSuccess = await _channel.invokeMethod('createOrLoadSavedMeshNetwork');
    return isSuccess;
  }

  Future<bool> importMeshNetworkFromJson({String? jsonStr}) async {
    final bool isSuccess = await _channel.invokeMethod('importMeshNetworkFromJson', jsonStr);
    return isSuccess;
  }

  Future<String> exportMeshNetwork() async {
    final String jsonString = await _channel.invokeMethod('exportMeshNetwork');
    return jsonString;
  }

  Future<bool> scanUnProvisionDevice() async {
    final bool isSuccess = await _channel.invokeMethod('scanUnProvisionDevice');
    return isSuccess;
  }

  Future<bool> selectedProvisionDevice({required String uuid}) async {
    final bool isSuccess = await _channel.invokeMethod('selectedProvisionDevice', uuid);
    return isSuccess;
  }

  Future<String> startProvisioning() async {
    final String result = await _channel.invokeMethod('startProvisioning');
    return result;
  }

  resultCallbackHandler(dynamic event) {
    if (_resultCallback != null) _resultCallback!(event);
  }

}
