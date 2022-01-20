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
          child: Column(
            children: [
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.initMeshNetworkManager();
              }, child: Text('Start Mesh Manager')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.createOrLoadSavedMeshNetwork();
              }, child: Text('Create And Load Mesh Network')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.importMeshNetworkFromJson();
              }, child: Text('Import Mesh Network')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.exportMeshNetwork();
              }, child: Text('Export Mesh Network')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.scanUnProvisionDevice();
              }, child: Text('Scan Unprovisioning Device')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.selectedProvisionDevice(uuid: _platformVersion);
              }, child: Text('Selected Unprovisioning Device')),
              TextButton(onPressed: () {
                NrfBleMeshPlugin.instance.startProvisioning();
              }, child: Text('Start Provisioning')),
              Text(_platformVersion)
            ],
          ),
        ),
      ),
    );
  }
}
