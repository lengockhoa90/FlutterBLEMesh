import 'dart:ffi';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nrf_ble_mesh_plugin/nrf_ble_mesh_plugin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();

    NrfBleMeshPlugin.instance.onMessageReceived( resultCallback: (data) {
      print(data);
      if (data["detectUnprovisionDevice"] != null) {
        setState(() {
          _platformVersion = data["detectUnprovisionDevice"]["uuid"];
        });
      }
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await NrfBleMeshPlugin.instance.platformVersion ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(

            child: Column(
              children: [
                TextButton(onPressed: () async {
                  NrfBleMeshPlugin.instance.initMeshNetworkManager();
                }, child: Text('Start Mesh Manager')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.createOrLoadSavedMeshNetwork();
                }, child: Text('Create And Load Mesh Network')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.importMeshNetworkFromJson(jsonStr: _platformVersion);
                }, child: Text('Import Mesh Network')),
                TextButton(onPressed: () async {
                  _platformVersion = await NrfBleMeshPlugin.instance.exportMeshNetwork();
                  setState(() {
                  });
                }, child: Text('Export Mesh Network')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.scanUnProvisionDevice();
                }, child: Text('Scan Unprovisioning Device')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.stopScanUnProvisionDevice();
                }, child: Text('Stop Scan Unprovisioning Device')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.selectedProvisionDevice(uuid: _platformVersion, unicastAddress: int.parse('0002', radix: 16));
                }, child: Text('Selected Unprovisioning Device')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.startProvisioning();
                }, child: Text('Start Provisioning')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.generateAppKeyForNewMeshNetwork();
                }, child: Text('Generate Appkey')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.resetAllProcess();
                }, child: Text('Rết All Process')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.sendMessageToAddress(address: 0x02, vendorModelId: 0x0211, companyId: 0x0211, opCodeString: 'E0', param: "0200000000000000" );
                }, child: Text('Send Message')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.sendSaveGatewayMessage(address: 0x02, opCodeString: '12', param: "0200000000000000" );
                }, child: Text('Send Save Gateway')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.bindAppKeyToModel(nodeAddress: 0x02, modelId: 0x1000);
                }, child: Text('bind App key')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.setPublicationToAddress(nodeAddress: 0x02, modelId: 0x0211, publicAddress: 0xF000);
                }, child: Text('public')),
                TextButton(onPressed: () {
                  NrfBleMeshPlugin.instance.disConnectProvisionNode();
                }, child: Text('Disconnect')),
                Text(_platformVersion)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
