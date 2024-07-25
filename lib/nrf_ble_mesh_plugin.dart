
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

      initMeshNetworkManager();
  }

  ResultCallback? _resultCallback;

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
    final bool isSuccess = await _channel.invokeMethod('vcnImportMeshNetworkFromJson', jsonStr);
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

  Future<bool> selectedProvisionDevice({required String uuid, int? unicastAddress}) async {
    Map<String, dynamic> data = Map<String, dynamic>();

    data["uuidStr"] = uuid;
    data["unicastAddress"] = unicastAddress;

    final bool isSuccess = await _channel.invokeMethod('selectedProvisionDevice', data);
    return isSuccess;
  }

  Future<String> startProvisioning() async {
    final String result = await _channel.invokeMethod('startProvisioning');
    return result;
  }

  Future<String> stopScanUnProvisionDevice() async {
    final String result = await _channel.invokeMethod('stopScanUnProvisionDevice');
    return result;
  }

  Future<String> generateAppKeyForNewMeshNetwork() async {
    final String appKey = await _channel.invokeMethod('generateAppKeyForNewMeshNetwork');
    return appKey;
  }

  Future resetAllProcess() async {
    await _channel.invokeMethod('resetAllProcess');
  }

  Future<bool> removeNodeInMesh({required int address}) async {
    final bool result = await _channel.invokeMethod('removeNodeInMesh', address);

    return result;
  }

  Future<bool> checkHasMeshNetwork() async {
    final bool result = await _channel.invokeMethod('checkHasMeshNetwork');
    return result;
  }

  Future<bool> sendMessageToAddress({required int address, required int vendorModelId, required int companyId, required String opCodeString, String? param, int? isSegmented, int? security}) async {

    Map<String, dynamic> data = Map<String, dynamic>();
    data["address"] = address;
    data["vendorModelId"] = vendorModelId;
    data["companyId"] = companyId;
    data["opCodeString"] = opCodeString;
    data["params"] = param ?? '';
    data["isSegmented"] = isSegmented ?? 0;
    data["security"] = security ?? 0;

    return await _channel.invokeMethod("sendMessageToAddress", data);
  }

  Future<bool> bindAppKeyToModel({required int nodeAddress, required int modelId}) async {

    Map<String, dynamic> data = Map<String, dynamic>();
    data["modelId"] = modelId;
    data["nodeAddress"] = nodeAddress;
    return await _channel.invokeMethod("bindAppKeyToModel", data);
  }

  Future<bool> setPublicationToAddress({required int nodeAddress, required int modelId, required int publicAddress}) async {

    Map<String, dynamic> data = Map<String, dynamic>();
    data["modelId"] = modelId;
    data["nodeAddress"] = nodeAddress;
    data["publicAddress"] = publicAddress;
    return await _channel.invokeMethod("setPublicationToAddress", data);
  }

  Future disConnectProvisionNode() async {
    return await _channel.invokeMethod("disConnectProvisionNode");
  }

  resultCallbackHandler(dynamic event) {
    if (_resultCallback != null) _resultCallback!(event);
  }

}
