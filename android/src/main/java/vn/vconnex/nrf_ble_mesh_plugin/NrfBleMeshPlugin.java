package vn.vconnex.nrf_ble_mesh_plugin;

import android.Manifest;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;


import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;


import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import no.nordicsemi.android.log.LogSession;
import no.nordicsemi.android.log.Logger;
import no.nordicsemi.android.mesh.ApplicationKey;
import no.nordicsemi.android.mesh.MeshManagerApi;
import no.nordicsemi.android.mesh.MeshManagerCallbacks;
import no.nordicsemi.android.mesh.MeshNetwork;
import no.nordicsemi.android.mesh.MeshProvisioningStatusCallbacks;
import no.nordicsemi.android.mesh.MeshStatusCallbacks;

import no.nordicsemi.android.mesh.NetworkKey;
import no.nordicsemi.android.mesh.Provisioner;
import no.nordicsemi.android.mesh.UnprovisionedBeacon;
import no.nordicsemi.android.mesh.opcodes.ProxyConfigMessageOpCodes;
import no.nordicsemi.android.mesh.provisionerstates.ProvisioningCapabilities;
import no.nordicsemi.android.mesh.provisionerstates.ProvisioningState;
import no.nordicsemi.android.mesh.provisionerstates.UnprovisionedMeshNode;
import no.nordicsemi.android.mesh.transport.ConfigAppKeyAdd;
import no.nordicsemi.android.mesh.transport.ConfigAppKeyStatus;
import no.nordicsemi.android.mesh.transport.ConfigCompositionDataGet;
import no.nordicsemi.android.mesh.transport.ConfigDefaultTtlGet;
import no.nordicsemi.android.mesh.transport.ConfigDefaultTtlStatus;
import no.nordicsemi.android.mesh.transport.ConfigModelAppBind;
import no.nordicsemi.android.mesh.transport.ConfigModelAppStatus;
import no.nordicsemi.android.mesh.transport.ConfigModelPublicationSet;
import no.nordicsemi.android.mesh.transport.ConfigModelPublicationStatus;
import no.nordicsemi.android.mesh.transport.ConfigModelPublicationVirtualAddressSet;
import no.nordicsemi.android.mesh.transport.ConfigModelSubscriptionAdd;
import no.nordicsemi.android.mesh.transport.ConfigNetworkTransmitSet;
import no.nordicsemi.android.mesh.transport.ControlMessage;
import no.nordicsemi.android.mesh.transport.Element;
import no.nordicsemi.android.mesh.transport.GenericOnOffStatus;
import no.nordicsemi.android.mesh.transport.MeshMessage;
import no.nordicsemi.android.mesh.transport.MeshModel;
import no.nordicsemi.android.mesh.transport.ProvisionedMeshNode;
import no.nordicsemi.android.mesh.transport.ProxyConfigAddAddressToFilter;
import no.nordicsemi.android.mesh.transport.ProxyConfigFilterStatus;
import no.nordicsemi.android.mesh.transport.ProxyConfigSetFilterType;
import no.nordicsemi.android.mesh.transport.VendorModelMessageAcked;
import no.nordicsemi.android.mesh.transport.VendorModelMessageStatus;
import no.nordicsemi.android.mesh.utils.AddressArray;
import no.nordicsemi.android.mesh.utils.AddressType;
import no.nordicsemi.android.mesh.utils.AuthenticationOOBMethods;
import no.nordicsemi.android.mesh.utils.MeshAddress;
import no.nordicsemi.android.mesh.utils.MeshParserUtils;
import no.nordicsemi.android.mesh.utils.ProxyFilterType;
import no.nordicsemi.android.support.v18.scanner.BluetoothLeScannerCompat;
import no.nordicsemi.android.support.v18.scanner.ScanCallback;
import no.nordicsemi.android.support.v18.scanner.ScanFilter;
import no.nordicsemi.android.support.v18.scanner.ScanRecord;
import no.nordicsemi.android.support.v18.scanner.ScanResult;
import no.nordicsemi.android.support.v18.scanner.ScanSettings;
import vn.vconnex.nrf_ble_mesh_plugin.adapter.ExtendedBluetoothDevice;
import vn.vconnex.nrf_ble_mesh_plugin.ble.BleMeshManager;
import vn.vconnex.nrf_ble_mesh_plugin.ble.BleMeshManagerCallbacks;
import vn.vconnex.nrf_ble_mesh_plugin.utils.Utils;

import static no.nordicsemi.android.mesh.opcodes.ApplicationMessageOpCodes.GENERIC_LEVEL_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ApplicationMessageOpCodes.GENERIC_ON_OFF_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ApplicationMessageOpCodes.SCENE_REGISTER_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ApplicationMessageOpCodes.SCENE_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_APPKEY_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_COMPOSITION_DATA_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_DEFAULT_TTL_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_GATT_PROXY_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_HEARTBEAT_PUBLICATION_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_HEARTBEAT_SUBSCRIPTION_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_MODEL_APP_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_MODEL_PUBLICATION_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_MODEL_SUBSCRIPTION_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_NETWORK_TRANSMIT_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_NODE_RESET_STATUS;
import static no.nordicsemi.android.mesh.opcodes.ConfigMessageOpCodes.CONFIG_RELAY_STATUS;


/** NrfBleMeshPlugin */
public class NrfBleMeshPlugin implements FlutterPlugin, ActivityAware , MethodChannel.MethodCallHandler {

  private static final String TAG = NrfBleMeshPlugin.class.getSimpleName();

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;

  private EventChannel stateChannel;
  private EventChannel.StreamHandler streamHandler;
  private EventChannel.EventSink sink;

  private Context mContext;

  private MeshManagerApi mMeshManagerApi;
  private BleMeshManager mBleMeshManager;

  private Handler mHandler;

  private ExtendedBluetoothDevice mSelectedDevice;
  private UnprovisionedMeshNode mUnprovisionedMeshNode;
  private ProvisionedMeshNode mProvisionedMeshNode;

  private MeshNetwork mMeshNetwork;

  private final List<ExtendedBluetoothDevice> mDevices = new ArrayList<>();

  private ActivityPluginBinding activityBinding;

  private boolean mSetupProvisionedNode;

  private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;

  private  boolean mIsScanning = false;

  private Integer customUnicastAddress;
  private boolean mConnectToProxyNode = false;

  private UUID mFilterUuid;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    mContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "nrf_ble_mesh_plugin");
    channel.setMethodCallHandler(this);

    stateChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "nrf_ble_mesh_plugin_event_channel");
    streamHandler = new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        sink = events;
      }

      @Override
      public void onCancel(Object arguments) {
        sink = null;
      }
    };
    stateChannel.setStreamHandler(streamHandler);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    }
    else if (call.method.equals("initMeshNetworkManager")) {
      initMeshNetworkManager();
    }
    else if (call.method.equals("createOrLoadSavedMeshNetwork")) {
      result.success(createOrLoadSavedMeshNetwork());
    }
    else if (call.method.equals("importMeshNetworkFromJson")) {
      result.success(importMeshNetworkFromJson((String) call.arguments));
    }
    else if (call.method.equals("exportMeshNetwork")) {
      result.success(exportMeshNetwork());
    }
    else if (call.method.equals("selectedProvisionDevice")) {
      Map<String, Object> args = (Map<String, Object>) call.arguments;

      result.success(selectedProvisionDevice((String) args.get("uuidStr"), (Integer) args.get("unicastAddress")));
    }
    else if (call.method.equals("scanUnProvisionDevice")) {
      result.success(scanUnProvisionDevice());
    }
    else if (call.method.equals("stopScanUnProvisionDevice")) {
      stopScan();
    }
    else if (call.method.equals("startProvisioning")) {
      result.success(onNoOOBSelected());
    }
    else if (call.method.equals("generateAppKeyForNewMeshNetwork")) {

    }
    else if (call.method.equals("resetAllProcess")) {
      resetAllProcess();
    }
    else if (call.method.equals("removeNodeInMesh")) {
      result.success(removeNodeInMesh((Integer) call.arguments));
    }
    else if (call.method.equals("checkHasMeshNetwork")) {
      result.success(checkHasMeshNetwork());
    }
    else if (call.method.equals("sendMessageToAddress")) {
      Map<String, Object> args = (Map<String, Object>) call.arguments;
      sendMessageToAddress((Integer) args.get("address"),(Integer) args.get("vendorModelId"),(Integer) args.get("companyId"),(String) args.get("opCodeString"), (String) args.get("params"));
    }
    else if (call.method.equals("bindAppKeyToModel")) {
      Map<String, Object> args = (Map<String, Object>) call.arguments;
      result.success(bindAppKeyToModel((Integer) args.get("modelId"), (Integer) args.get("nodeAddress")));
    }
    else if (call.method.equals("setPublicationToAddress")) {
      Map<String, Object> args = (Map<String, Object>) call.arguments;
      result.success(setPublicationToAddress((Integer) args.get("publicAddress"),(Integer) args.get("modelId"), (Integer) args.get("nodeAddress")));
    }
    else if (call.method.equals("disConnectProvisionNode")) {
      disConnectProvisionNode();
    }
    else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  public void initMeshNetworkManager() {
    mMeshManagerApi = new MeshManagerApi(mContext);
    initOrUpdateBleMeshManager();
    if (mHandler == null) {
      mHandler = new Handler(Looper.getMainLooper());
    }
    handleCallBack();
  }

  void clearInstance() {
    mBleMeshManager = null;
  }

  Boolean createOrLoadSavedMeshNetwork() {
    mMeshManagerApi.loadMeshNetwork();
    return true;
  }

  Boolean importMeshNetworkFromJson(String json) {
    mMeshManagerApi.importMeshNetworkJson(json);
    return true;
  }

  String exportMeshNetwork() {
    return mMeshManagerApi.exportMeshNetwork();
  }

  void initOrUpdateBleMeshManager() {
    if (mBleMeshManager == null) {
      //Initialize the ble manager
      mBleMeshManager = new BleMeshManager(mContext);

      mBleMeshManager.setGattCallbacks(new BleMeshManagerCallbacks() {
        @Override
        public void onDataReceived(BluetoothDevice bluetoothDevice, int mtu, byte[] pdu) {
          mMeshManagerApi.handleNotifications(mtu, pdu);
        }

        @Override
        public void onDataSent(BluetoothDevice device, int mtu, byte[] pdu) {
          mMeshManagerApi.handleWriteCallbacks(mtu, pdu);
        }

        @Override
        public void onDeviceConnecting(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onDeviceConnected(@NonNull BluetoothDevice device) {

//          addGroupAddress();
          HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();

          HashMap<String, Object> contentMap =new HashMap<>();
          contentMap.put("state", "bearerDidConnect");
          contentMap.put("uuid", device.getAddress());
          hashMap.put("bearerDelegate" , contentMap);
          sendEvent(hashMap);
        }

        @Override
        public void onDeviceDisconnecting(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onDeviceDisconnected(@NonNull BluetoothDevice device) {
          HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
          HashMap<String, Object> contentMap =new HashMap<>();
          contentMap.put("state", "bearerDidClose");
          contentMap.put("uuid", device.getAddress());
          hashMap.put("bearerDelegate" , contentMap);
          sendEvent(hashMap);
        }

        @Override
        public void onLinkLossOccurred(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onServicesDiscovered(@NonNull BluetoothDevice device, boolean optionalServicesFound) {

          HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
          HashMap<String, Object> contentMap =new HashMap<>();
          contentMap.put("state", "bearerDidDiscoverServices");
          contentMap.put("uuid", device.getAddress());
          hashMap.put("bearerDelegate" , contentMap);
          sendEvent(hashMap);
        }

        @Override
        public void onDeviceReady(@NonNull BluetoothDevice device) {

          if (mSetupProvisionedNode) {
            sendConpositionData();
          }
          else if (mConnectToProxyNode) {
            addGroupAddress();
          }
          else {
            identifyNode();
            HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
            HashMap<String, Object> contentMap =new HashMap<>();
            contentMap.put("state", "bearerDidOpen");
            contentMap.put("uuid", device.getAddress());
            hashMap.put("bearerDelegate" , contentMap);
            sendEvent(hashMap);
          }
        }

        @Override
        public void onBondingRequired(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onBonded(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onBondingFailed(@NonNull BluetoothDevice device) {

        }

        @Override
        public void onError(@NonNull BluetoothDevice device, @NonNull String message, int errorCode) {

        }

        @Override
        public void onDeviceNotSupported(@NonNull BluetoothDevice device) {

        }
      });
    }
  }

  Boolean scanUnProvisionDevice() {

    initOrUpdateBleMeshManager();

    if (mHandler == null) {
      mHandler = new Handler(Looper.getMainLooper());
    }

    // First, check the Location permission. This is required on Marshmallow onwards in order to scan for Bluetooth LE devices.
    if (Utils.isLocationPermissionsGranted(mContext)) {
          // We are now OK to start scanning
        mDevices.clear();
        mConnectToProxyNode = false;
        startScan(BleMeshManager.MESH_PROVISIONING_UUID);
        return true;
    }
    else {
      ActivityCompat.requestPermissions(
              activityBinding.getActivity(),
              new String[] {
                      Manifest.permission.ACCESS_FINE_LOCATION
              },
              REQUEST_FINE_LOCATION_PERMISSIONS);
    }
    return false;
  }

  /**
   * Start scanning for Bluetooth devices.
   *
   * @param filterUuid UUID to filter scan results with
   */
  public void startScan(final UUID filterUuid) {
       mFilterUuid = filterUuid;

    if (mIsScanning == true) return;

    //Scanning settings
    final no.nordicsemi.android.support.v18.scanner.ScanSettings settings = new no.nordicsemi.android.support.v18.scanner.ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            // Refresh the devices list every second
            .setReportDelay(0)
            // Hardware filtering has some issues on selected devices
            .setUseHardwareFilteringIfSupported(false)
            // Samsung S6 and S6 Edge report equal value of RSSI for all devices. In this app we ignore the RSSI.
            /*.setUseHardwareBatchingIfSupported(false)*/
            .build();

    //Let's use the filter to scan only for unprovisioned mesh nodes.
    final List<no.nordicsemi.android.support.v18.scanner.ScanFilter> filters = new ArrayList<>();
    filters.add(new ScanFilter.Builder().setServiceUuid(new ParcelUuid((filterUuid))).build());

    final BluetoothLeScannerCompat scanner = BluetoothLeScannerCompat.getScanner();
    scanner.startScan(filters, settings, mScanCallbacks);

    mIsScanning = true;
  }

  /**
   * stop scanning for bluetooth devices.
   */
  public void stopScan() {
    final BluetoothLeScannerCompat scanner = BluetoothLeScannerCompat.getScanner();
    scanner.stopScan(mScanCallbacks);
    mIsScanning = false;
  }

  public Boolean selectedProvisionDevice(String uuidStr, Integer unicashAddress) {
      stopScan();
      if (unicashAddress != null) {
        customUnicastAddress = unicashAddress;
        final MeshNetwork network = mMeshManagerApi.getMeshNetwork();
        network.assignUnicastAddress((int) unicashAddress);
      }
    for (final ExtendedBluetoothDevice device : mDevices) {
      if (device.getAddress().equals(uuidStr)) {
        final LogSession logSession = Logger.newSession(mContext, null, device.getAddress(), device.getName());
        mBleMeshManager.setLogger(logSession);
        mBleMeshManager.connect(device.getDevice()).retry(10, 3000).enqueue();
        mSelectedDevice = device;
        return true;
      }
    }
      return  false;
  }

  void identifyNode() {
      if (mSelectedDevice != null) {
        final UnprovisionedBeacon beacon = (UnprovisionedBeacon) mSelectedDevice.getBeacon();
        if (beacon != null) {
          mMeshManagerApi.identifyNode(beacon.getUuid(), 5);
        } else {
          final byte[] serviceData = Utils.getServiceData(mSelectedDevice.getScanResult(), BleMeshManager.MESH_PROVISIONING_UUID);
          if (serviceData != null) {
            final UUID uuid = mMeshManagerApi.getDeviceUuid(serviceData);
            mMeshManagerApi.identifyNode(uuid, 5);
          }
        }
      }
  }

  Boolean provisionNode() {
    if (mUnprovisionedMeshNode != null && mUnprovisionedMeshNode.getProvisioningCapabilities() != null) {
      final ProvisioningCapabilities capabilities = mUnprovisionedMeshNode.getProvisioningCapabilities();

      final MeshNetwork network = mMeshManagerApi.getMeshNetwork();
      if (network != null) {
        try {
          final int elementCount = capabilities.getNumberOfElements();
          final Provisioner provisioner = network.getSelectedProvisioner();
          final int unicast = customUnicastAddress != null ? customUnicastAddress : network.nextAvailableUnicastAddress(elementCount, provisioner);
          network.assignUnicastAddress(unicast);
        } catch (IllegalArgumentException ex) {
        }
      }

      if (mUnprovisionedMeshNode.getProvisioningCapabilities().getAvailableOOBTypes().size() == 1 &&
              mUnprovisionedMeshNode.getProvisioningCapabilities().getAvailableOOBTypes().get(0) == AuthenticationOOBMethods.NO_OOB_AUTHENTICATION) {
        return onNoOOBSelected();
      }
      else {
        return false;
      }
    }
    else {
      return false;
    }
  }

  public Boolean onNoOOBSelected() {
    if (mUnprovisionedMeshNode != null) {
      try {
        mMeshManagerApi.startProvisioning(mUnprovisionedMeshNode);
        return true;
      } catch (IllegalArgumentException ex) {
        return false;
      }
    }
    return false;
  }


  private final ScanCallback mScanCallbacks = new ScanCallback() {

    @Override
    public void onScanResult(final int callbackType, @NonNull final ScanResult result) {
      try {

        if (mFilterUuid.equals(BleMeshManager.MESH_PROVISIONING_UUID)) {
          // If the packet has been obtained while Location was disabled, mark Location as not required
          if (Utils.isLocationRequired(mContext) && !Utils.isLocationEnabled(mContext))
            Utils.markLocationNotRequired(mContext);

          updateScannerLiveData(result);
        }
        else if (mFilterUuid.equals(BleMeshManager.MESH_PROXY_UUID)) {
          final byte[] serviceData = Utils.getServiceData(result, BleMeshManager.MESH_PROXY_UUID);
          if (mMeshManagerApi != null) {
            if (mMeshManagerApi.isAdvertisingWithNetworkIdentity(serviceData)) {
              if (mMeshManagerApi.networkIdMatches(serviceData)) {
                updateScannerLiveData(result);
              }
            } else if (mMeshManagerApi.isAdvertisedWithNodeIdentity(serviceData)) {
              if (checkIfNodeIdentityMatches(serviceData)) {
                updateScannerLiveData(result);
              }
            }
          }
        }
      } catch (Exception ex) {
        Log.e(TAG, "Error: " + ex.getMessage());
      }
    }

    @Override
    public void onBatchScanResults(@NonNull final List<ScanResult> results) {
      // Batch scan is disabled (report delay = 0)
    }

    @Override
    public void onScanFailed(final int errorCode) {
//      mScannerStateLiveData.scanningStopped();
    }
  };


  private void updateScannerLiveData(final ScanResult result) {

    if (mSetupProvisionedNode) {
      if (result.getDevice().getAddress().equals(mSelectedDevice.getAddress())) {
        stopScan();
        mBleMeshManager.connect(result.getDevice()).retry(20, 3000).enqueue();
      }
    }
    else if (mConnectToProxyNode) {
      stopScan();
      mBleMeshManager.connect(result.getDevice()).retry(5, 1000).enqueue();
    }
    else {
      final ScanRecord scanRecord = result.getScanRecord();
      if (scanRecord != null) {
        if (scanRecord.getBytes() != null) {
          final byte[] beaconData = getMeshBeaconData(scanRecord.getBytes());
          if (beaconData != null) {

            SparseArray<byte[]> _manufacturerSpecificData = scanRecord.getManufacturerSpecificData();

            String manuFacturalData = null;
            Integer vendorId = null;
            if (_manufacturerSpecificData != null && _manufacturerSpecificData.size() > 0) {
              manuFacturalData = byteArrayToHex(_manufacturerSpecificData.valueAt(0));
              vendorId = _manufacturerSpecificData.keyAt(0);
              Log.v(TAG,  "onNetworkLoaded" + manuFacturalData);
            }


            final int index = indexOf(result);
            if (index == -1) {
              HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
              HashMap<String, Object> contentMap =new HashMap<>();

              String beaconDataHex = byteArrayToHex(beaconData);
              int startIndex = beaconDataHex.indexOf("dddd");

              contentMap.put("uuid", result.getDevice().getAddress());
              contentMap.put("rssi", result.getRssi());
              contentMap.put("name", scanRecord.getDeviceName());

              if (beaconDataHex.length() > 20 && startIndex != -1) {
                contentMap.put("macAddress", (beaconDataHex.substring(startIndex + 4, startIndex + 16)).toUpperCase());
                contentMap.put("deviceType", Integer.parseInt(beaconDataHex.substring(startIndex + 16, startIndex + 20), 16));
                contentMap.put("firmwareVersion", getVersionFirmware(beaconDataHex, startIndex));
              }

              if (manuFacturalData != null && manuFacturalData.length() > 42 && vendorId != null) {
                contentMap.put("macAddressMnf", (manuFacturalData.substring(0, 12)).toUpperCase());
                contentMap.put("vendorId", vendorId);
                contentMap.put("deviceTypeMnf", Integer.parseInt(manuFacturalData.substring(34, 38), 16));
                contentMap.put("userData", intergerToHex(vendorId) + manuFacturalData);
              }

              ExtendedBluetoothDevice device = new ExtendedBluetoothDevice(result, mMeshManagerApi.getMeshBeacon(beaconData));
              mDevices.add(device);
              hashMap.put("detectUnprovisionDevice" , contentMap);

              sendEvent(hashMap);
            }
          }
        }
      }
    }
  }


  private boolean checkIfNodeIdentityMatches(final byte[] serviceData) {
    final MeshNetwork network = mMeshManagerApi.getMeshNetwork();
    if (network != null) {
      for (ProvisionedMeshNode node : network.getNodes()) {
        if (mMeshManagerApi.nodeIdentityMatches(node, serviceData)) {
          return true;
        }
      }
    }
    return false;
  }

  private String getVersionFirmware(final String beaconDataHex, int startIndex) {

    if (beaconDataHex.length() >= 32) {
     int firstVersionNumber = Integer.parseInt(beaconDataHex.substring(startIndex + 20, startIndex + 24), 16);
      int secondVersionNumber = Integer.parseInt(beaconDataHex.substring(startIndex + 24, startIndex + 28), 16);
      int thirdVersionNumber = Integer.parseInt(beaconDataHex.substring(startIndex + 28, startIndex + 32), 16);

      return firstVersionNumber + "." + secondVersionNumber + "." + secondVersionNumber;
    }
    return "";
  }

  void  handleCallBack() {

    mMeshManagerApi.setMeshManagerCallbacks(new MeshManagerCallbacks() {
      @Override
      public void onNetworkLoaded(MeshNetwork meshNetwork) {
        Log.v(TAG, meshNetwork.getMeshName() + "onNetworkLoaded");
//        addGroupAddress();
      }

      @Override
      public void onNetworkUpdated(MeshNetwork meshNetwork) {
        Log.v(TAG, meshNetwork.getMeshName() + "onNetworkUpdated");

        loadNetwork(meshNetwork);
      }

      @Override
      public void onNetworkLoadFailed(String error) {
        Log.v(TAG,  "onNetworkLoadFailed");
      }

      @Override
      public void onNetworkImported(MeshNetwork meshNetwork) {
        loadNetwork(meshNetwork);
      }

      @Override
      public void onNetworkImportFailed(String error) {
      }

      @Override
      public void sendProvisioningPdu(UnprovisionedMeshNode meshNode, byte[] pdu) {
        Log.v(TAG, meshNode.getNodeName() + "sendProvisioningPdu");
        mBleMeshManager.sendPdu(pdu);
      }

      @Override
      public void onMeshPduCreated(byte[] pdu) {
        Log.v(TAG, "onMeshPduCreated");
        mBleMeshManager.sendPdu(pdu);
      }

      @Override
      public int getMtu() {
        return mBleMeshManager.getMaximumPacketSize();
      }
    });

    mMeshManagerApi.setMeshStatusCallbacks(new MeshStatusCallbacks() {
      @Override
      public void onTransactionFailed(int dst, boolean hasIncompleteTimerExpired) {
        mProvisionedMeshNode = mMeshNetwork.getNode(dst);
      }

      @Override
      public void onUnknownPduReceived(int src, byte[] accessPayload) {
        final ProvisionedMeshNode node = mMeshNetwork.getNode(src);
        if (node != null) {
          updateNode(node);
        }
      }

      @Override
      public void onBlockAcknowledgementProcessed(int dst, @NonNull ControlMessage message) {
        final ProvisionedMeshNode node = mMeshNetwork.getNode(dst);
        if (node != null) {
          mProvisionedMeshNode = node;
        }
      }

      @Override
      public void onBlockAcknowledgementReceived(int src, @NonNull ControlMessage message) {
        final ProvisionedMeshNode node = mMeshNetwork.getNode(src);
        if (node != null) {
          mProvisionedMeshNode = node;
        }
      }

      @Override
      public void onMeshMessageProcessed(int dst, @NonNull MeshMessage meshMessage) {
        Log.v(TAG,   "onMeshMessageProcessed ----" + meshMessage.toString());
        final ProvisionedMeshNode node = mMeshNetwork.getNode(dst);
        if (node != null) {
          mProvisionedMeshNode = node;
          if (meshMessage instanceof ConfigCompositionDataGet) {

          } else if (meshMessage instanceof ConfigDefaultTtlGet) {

          } else if (meshMessage instanceof ConfigAppKeyAdd) {

          } else if (meshMessage instanceof ConfigNetworkTransmitSet) {

          }
          else if (meshMessage instanceof ConfigModelAppBind) {

          }

          else if (meshMessage instanceof ProxyConfigSetFilterType) {
//            final ProxyConfigFilterStatus status = (ProxyConfigFilterStatus) meshMessage;
//            final int unicastAddress = status.getSrc();
//            Log.v(TAG, "Proxy configuration source: " + MeshAddress.formatAddress(status.getSrc(), false));


          }
        }
      }

      @Override
      public void onMeshMessageReceived(int src, @NonNull MeshMessage meshMessage) {

        Log.v(TAG,   "onMeshMessageReceived ----" + meshMessage.toString());
        final ProvisionedMeshNode node = mMeshNetwork.getNode(src);
        if (node != null)
          mProvisionedMeshNode = node;

        if (meshMessage.getOpCode() == CONFIG_COMPOSITION_DATA_STATUS) {
            if (mSetupProvisionedNode) {

              mHandler.postDelayed(() -> {
                final ConfigDefaultTtlGet configDefaultTtlGet = new ConfigDefaultTtlGet();
                mMeshManagerApi.createMeshPdu(node.getUnicastAddress(), configDefaultTtlGet);
              }, 500);
            } else {
              updateNode(node);
            }
          } else if (meshMessage.getOpCode() == CONFIG_DEFAULT_TTL_STATUS) {
            final ConfigDefaultTtlStatus status = (ConfigDefaultTtlStatus) meshMessage;
            if (mSetupProvisionedNode) {

              mHandler.postDelayed(() -> {
                final ConfigNetworkTransmitSet networkTransmitSet = new ConfigNetworkTransmitSet(2, 1);
                mMeshManagerApi.createMeshPdu(node.getUnicastAddress(), networkTransmitSet);
              }, 1500);
            } else {
              updateNode(node);
            }
          } else if (meshMessage.getOpCode() == CONFIG_NETWORK_TRANSMIT_STATUS) {
            if (mSetupProvisionedNode) {

              List<ApplicationKey> appKeys = mMeshNetwork.getAppKeys();
              if (appKeys != null && appKeys.size() > 0) {
                final ApplicationKey appKey = appKeys.get(0);
                if (appKey != null) {
                  mHandler.postDelayed(() -> {
                    final int index = node.getAddedNetKeys().get(0).getIndex();
                    final NetworkKey networkKey = mMeshNetwork.getNetKeys().get(index);
                    final ConfigAppKeyAdd configAppKeyAdd = new ConfigAppKeyAdd(networkKey, appKey);
                    mMeshManagerApi.createMeshPdu(node.getUnicastAddress(), configAppKeyAdd);
                  }, 1500);


                } else {
                  mSetupProvisionedNode = false;
                }
              }
              else {
                mSetupProvisionedNode = false;
              }

            } else {
              updateNode(node);
            }
          } else if (meshMessage.getOpCode() == CONFIG_APPKEY_STATUS) {
            final ConfigAppKeyStatus status = (ConfigAppKeyStatus) meshMessage;
            if (mSetupProvisionedNode) {
              mSetupProvisionedNode = false;
              addGroupAddress();
//              mBleMeshManager.disconnect().enqueue();
              if (status.isSuccessful()) {
                HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();

                HashMap<String, Object> contentMap =new HashMap<>();
                contentMap.put("uuid", mSelectedDevice.getAddress());
                contentMap.put("state", "addAppKeySuccessful");
                contentMap.put("unicashAddress", String.valueOf(mProvisionedMeshNode.getUnicastAddress()));
                hashMap.put("meshNetworkDelegate" , contentMap);
                sendEvent(hashMap);
              }
            } else {
              updateNode(node);
//              mMeshMessageLiveData.postValue(status);
            }
          } else if (meshMessage.getOpCode() == CONFIG_MODEL_APP_STATUS) {
            if (updateNode(node)) {
              final ConfigModelAppStatus status = (ConfigModelAppStatus) meshMessage;

              HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();

              HashMap<String, Object> contentMap =new HashMap<>();
              contentMap.put("nodeAddress", src);
              contentMap.put("modelId", status.getModelIdentifier());
              contentMap.put("elementAddress", status.getElementAddress());
              hashMap.put("bindAppKeyToModel" , contentMap);
              sendEvent(hashMap);

            }
          } else if (meshMessage.getOpCode() == CONFIG_MODEL_PUBLICATION_STATUS) {
            if (updateNode(node)) {
              final ConfigModelPublicationStatus status = (ConfigModelPublicationStatus) meshMessage;

              HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();

              HashMap<String, Object> contentMap =new HashMap<>();
              contentMap.put("nodeAddress", src);
              contentMap.put("modelId", status.getModelIdentifier());
              contentMap.put("elementAddress", status.getElementAddress());
              hashMap.put("publicationToAddress" , contentMap);
              sendEvent(hashMap);
            }

          } else if (meshMessage.getOpCode() == CONFIG_MODEL_SUBSCRIPTION_STATUS) {
            if (updateNode(node)) {
//              final ConfigModelSubscriptionStatus status = (ConfigModelSubscriptionStatus) meshMessage;
//              if (node.getElements().containsKey(status.getElementAddress())) {
//                final Element element = node.getElements().get(status.getElementAddress());
//                mSelectedElement.postValue(element);
//                final MeshModel model = element.getMeshModels().get(status.getModelIdentifier());
//                mSelectedModel.postValue(model);
//              }
            }

          } else if (meshMessage.getOpCode() == CONFIG_NODE_RESET_STATUS) {
            mBleMeshManager.setClearCacheRequired();
//            final ConfigNodeResetStatus status = (ConfigNodeResetStatus) meshMessage;
//            mExtendedMeshNode.postValue(null);
            loadNodes();
//            mMeshMessageLiveData.postValue(status);

          } else if (meshMessage.getOpCode() == CONFIG_RELAY_STATUS) {
            if (updateNode(node)) {
//              final ConfigRelayStatus status = (ConfigRelayStatus) meshMessage;
//              mMeshMessageLiveData.postValue(status);
            }
          } else if (meshMessage.getOpCode() == CONFIG_HEARTBEAT_PUBLICATION_STATUS) {
            if (updateNode(node)) {
//              final Element element = node.getElements().get(meshMessage.getSrc());
//              final MeshModel model = element.getMeshModels().get((int) SigModelParser.CONFIGURATION_SERVER);
//              mSelectedModel.postValue(model);
//              mMeshMessageLiveData.postValue(meshMessage);
            }
          } else if (meshMessage.getOpCode() == CONFIG_HEARTBEAT_SUBSCRIPTION_STATUS) {
            if (updateNode(node)) {
//              final Element element = node.getElements().get(meshMessage.getSrc());
//              final MeshModel model = element.getMeshModels().get((int) SigModelParser.CONFIGURATION_SERVER);
//              mSelectedModel.postValue(model);
//              mMeshMessageLiveData.postValue(meshMessage);
            }
          } else if (meshMessage.getOpCode() == CONFIG_GATT_PROXY_STATUS) {
            if (updateNode(node)) {
//              final ConfigProxyStatus status = (ConfigProxyStatus) meshMessage;
//              mMeshMessageLiveData.postValue(status);
            }
          } else if (meshMessage.getOpCode() == GENERIC_ON_OFF_STATUS) {
            if (updateNode(node)) {
              final GenericOnOffStatus status = (GenericOnOffStatus) meshMessage;

              HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
              HashMap<String, Object> contentMap =new HashMap<>();
              contentMap.put("address", intergerToHex(src));
              contentMap.put("opcode", intergerToHex(status.getOpCode()));
              contentMap.put("param", byteArrayToHex(status.getParameters()));
              hashMap.put("receivedMessage" , contentMap);
              sendEvent(hashMap);


//              if (node.getElements().containsKey(status.getSrcAddress())) {
//                final Element element = node.getElements().get(status.getSrcAddress());
//                mSelectedElement.postValue(element);
//                final MeshModel model = element.getMeshModels().get((int) SigModelParser.GENERIC_ON_OFF_SERVER);
//                mSelectedModel.postValue(model);
//              }
            }
          } else if (meshMessage.getOpCode() == GENERIC_LEVEL_STATUS) {
            if (updateNode(node)) {
//              final GenericLevelStatus status = (GenericLevelStatus) meshMessage;
//              if (node.getElements().containsKey(status.getSrcAddress())) {
//                final Element element = node.getElements().get(status.getSrcAddress());
//                mSelectedElement.postValue(element);
//                final MeshModel model = element.getMeshModels().get((int) SigModelParser.GENERIC_LEVEL_SERVER);
//                mSelectedModel.postValue(model);
//              }
            }
          } else if (meshMessage.getOpCode() == SCENE_STATUS) {
            if (updateNode(node)) {
//              final SceneStatus status = (SceneStatus) meshMessage;
//              if (node.getElements().containsKey(status.getSrcAddress())) {
//                final Element element = node.getElements().get(status.getSrcAddress());
//                mSelectedElement.postValue(element);
//              }
            }
          } else if (meshMessage.getOpCode() == SCENE_REGISTER_STATUS) {
            if (updateNode(node)) {
//              final SceneRegisterStatus status = (SceneRegisterStatus) meshMessage;
//              if (node.getElements().containsKey(status.getSrcAddress())) {
//                final Element element = node.getElements().get(status.getSrcAddress());
//                mSelectedElement.postValue(element);
//              }
            }
          } else if (meshMessage instanceof VendorModelMessageStatus) {

            if (updateNode(node)) {
              final VendorModelMessageStatus status = (VendorModelMessageStatus) meshMessage;

              HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
              HashMap<String, Object> contentMap =new HashMap<>();
              contentMap.put("address", src);
              contentMap.put("opcode", intergerToHex(status.getOpCode()));
              contentMap.put("param", byteArrayToHex(status.getParameters()));
              hashMap.put("receivedMessage" , contentMap);
              sendEvent(hashMap);

            }
          }
      }

      @Override
      public void onMessageDecryptionFailed(String meshLayer, String errorMessage) {
        Log.v(TAG,   "onMessageDecryptionFailed ----" + errorMessage);
      }
    });
    mMeshManagerApi.setProvisioningStatusCallbacks(new MeshProvisioningStatusCallbacks() {
      @Override
      public void onProvisioningStateChanged(UnprovisionedMeshNode meshNode, ProvisioningState.States state, byte[] data) {
          mUnprovisionedMeshNode = meshNode;

        HashMap<String, HashMap> hashMap =new HashMap<String, HashMap>();
        HashMap<String, Object> contentMap =new HashMap<>();
        switch (state) {
          case PROVISIONING_INVITE:

            contentMap.put("state", "Identifying");
            contentMap.put("uuid", mSelectedDevice.getAddress());
            hashMap.put("provisioningDelegate" , contentMap);
            sendEvent(hashMap);
            break;
          case PROVISIONING_CAPABILITIES:

            contentMap.put("state", "capabilitiesReceived_startProvisioning");
            contentMap.put("uuid", mSelectedDevice.getAddress());
            hashMap.put("provisioningDelegate" , contentMap);
            sendEvent(hashMap);

            provisionNode();
            break;
          case PROVISIONING_START:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_START");
            break;
          case PROVISIONING_PUBLIC_KEY_SENT:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_PUBLIC_KEY_SENT");
            break;
          case PROVISIONING_PUBLIC_KEY_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_PUBLIC_KEY_RECEIVED");
            break;
          case PROVISIONING_AUTHENTICATION_STATIC_OOB_WAITING:

            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_AUTHENTICATION_STATIC_OOB_WAITING");
            break;
          case PROVISIONING_AUTHENTICATION_OUTPUT_OOB_WAITING:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_AUTHENTICATION_OUTPUT_OOB_WAITING");
            break;
          case PROVISIONING_AUTHENTICATION_INPUT_OOB_WAITING:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_AUTHENTICATION_INPUT_OOB_WAITING");
            break;
          case PROVISIONING_AUTHENTICATION_INPUT_ENTERED:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_AUTHENTICATION_INPUT_ENTERED");
            break;
          case PROVISIONING_INPUT_COMPLETE:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_INPUT_COMPLETE");
            break;
          case PROVISIONING_CONFIRMATION_SENT:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_CONFIRMATION_SENT");
            break;
          case PROVISIONING_CONFIRMATION_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_CONFIRMATION_RECEIVED");
            break;
          case PROVISIONING_RANDOM_SENT:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_RANDOM_SENT");
            break;
          case PROVISIONING_RANDOM_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_RANDOM_RECEIVED");
            break;
          case PROVISIONING_DATA_SENT:
            Log.v(TAG, "onProvisioningStateChanged------ PROVISIONING_DATA_SENT");
            break;
          case PROVISIONING_COMPLETE:
            contentMap.put("state", "provisionSuccessful");
            contentMap.put("uuid", mSelectedDevice.getAddress());
            hashMap.put("provisioningDelegate" , contentMap);
            sendEvent(hashMap);
            break;
          case PROVISIONING_FAILED:

            contentMap.put("state", "provisionFail");
            contentMap.put("uuid", mSelectedDevice.getAddress());
            hashMap.put("provisioningDelegate" , contentMap);
            sendEvent(hashMap);
          default:
            break;
          case COMPOSITION_DATA_GET_SENT:
            Log.v(TAG, "onProvisioningStateChanged------ COMPOSITION_DATA_GET_SENT");
            break;
          case COMPOSITION_DATA_STATUS_RECEIVED:

            break;
          case SENDING_DEFAULT_TTL_GET:
            Log.v(TAG, "onProvisioningStateChanged------ SENDING_DEFAULT_TTL_GET");
            break;
          case DEFAULT_TTL_STATUS_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ DEFAULT_TTL_STATUS_RECEIVED");
            break;
          case SENDING_APP_KEY_ADD:
            Log.v(TAG, "onProvisioningStateChanged------ SENDING_APP_KEY_ADD");
            break;
          case APP_KEY_STATUS_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ APP_KEY_STATUS_RECEIVED");
            break;
          case SENDING_NETWORK_TRANSMIT_SET:
            Log.v(TAG, "onProvisioningStateChanged------ SENDING_NETWORK_TRANSMIT_SET");
            break;
          case NETWORK_TRANSMIT_STATUS_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ NETWORK_TRANSMIT_STATUS_RECEIVED");
            break;
          case SENDING_BLOCK_ACKNOWLEDGEMENT:
            Log.v(TAG, "onProvisioningStateChanged------ SENDING_BLOCK_ACKNOWLEDGEMENT");
            break;
          case BLOCK_ACKNOWLEDGEMENT_RECEIVED:
            Log.v(TAG, "onProvisioningStateChanged------ BLOCK_ACKNOWLEDGEMENT_RECEIVED");
            break;
        }
      }

      @Override
      public void onProvisioningFailed(UnprovisionedMeshNode meshNode, ProvisioningState.States state, byte[] data) {
        mUnprovisionedMeshNode = meshNode;
      }

      @Override
      public void onProvisioningCompleted(ProvisionedMeshNode meshNode, ProvisioningState.States state, byte[] data) {
        mProvisionedMeshNode = meshNode;
        loadNodes();
        mSetupProvisionedNode = true;

        mBleMeshManager.disconnect().enqueue();
//        connectToProxy(mSelectedDevice);

        if (state == ProvisioningState.States.PROVISIONING_COMPLETE) {
          HashMap<String, HashMap> hashMap = new HashMap<String, HashMap>();
          HashMap<String, Object> contentMap = new HashMap<>();
          contentMap.put("state", "provisionSuccessful");
          contentMap.put("uuid", mSelectedDevice.getAddress());
          hashMap.put("provisioningDelegate" , contentMap);
          sendEvent(hashMap);

          Log.v(TAG, "onProvisioningCompleted------ PROVISIONING_COMPLETE");

          mHandler.postDelayed(() -> {
            //Adding a slight delay here so we don't send anything before we receive the mesh beacon message
            if (mSetupProvisionedNode) {
              startScan(BleMeshManager.MESH_PROXY_UUID);

            }
          }, 3000);
        }
      }
    });

  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activityBinding = binding;
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
  }

  @Override
  public void onDetachedFromActivity() {
  }

  private int indexOf(final ScanResult result) {
    int i = 0;
    for (final ExtendedBluetoothDevice device : mDevices) {
      if (device.getAddress().equals(result.getDevice().getAddress()))
        return i;
      i++;
    }
    return -1;
  }


  void sendEvent(HashMap data) {
    if (sink != null) {
      mHandler.post(
              new Runnable() {
                @Override
                public void run() {
                  sink.success(data);
                }
              });
    }
  }


  public String byteArrayToHex(byte[] a) {
    StringBuilder sb = new StringBuilder(a.length * 2);
    for(byte b: a)
      sb.append(String.format("%02x", b));
    return sb.toString();
  }

  public  String intergerToHex(Integer value) {

    String strValue = Integer.toHexString(value);

    if (strValue.length() < 4) {
      return String.format("%" + (4 - strValue.length()) + "c", '0') + Integer.toHexString(value);
    }
    else {
      return Integer.toHexString(value);
    }
  }

  private void loadNetwork(final MeshNetwork meshNetwork) {
    mMeshNetwork = meshNetwork;
    if (mMeshNetwork != null) {

      if (!mMeshNetwork.isProvisionerSelected()) {
        final Provisioner provisioner = meshNetwork.getProvisioners().get(0);
        provisioner.setLastSelected(true);
        mMeshNetwork.selectProvisioner(provisioner);
      }
      //Load live data with mesh network
//      mMeshNetworkLiveData.loadNetworkInformation(meshNetwork);
      //Load live data with provisioned nodes
      loadNodes();

//      final ProvisionedMeshNode node = getSelectedMeshNode().getValue();
//      if (node != null) {
////        mExtendedMeshNode.postValue(mMeshNetwork.getNode(node.getUuid()));
//      }
    }
  }

  private void loadNodes() {
    final List<ProvisionedMeshNode> nodes = new ArrayList<>();
    for (final ProvisionedMeshNode node : mMeshNetwork.getNodes()) {
      if (!node.getUuid().equalsIgnoreCase(mMeshNetwork.getSelectedProvisioner().getProvisionerUuid())) {
        nodes.add(node);
      }
    }
//    mProvisionedNodes.postValue(nodes);
  }

  private boolean updateNode(@NonNull final ProvisionedMeshNode node) {
    if (mProvisionedMeshNode != null && mProvisionedMeshNode.getUnicastAddress() == node.getUnicastAddress()) {
      mProvisionedMeshNode = node;
      return true;
    }
    return false;
  }

  Boolean sendConpositionData() {
    if (mSetupProvisionedNode) {
      if (mMeshNetwork.getSelectedProvisioner().getProvisionerAddress() != null) {
        mHandler.postDelayed(() -> {
          //Adding a slight delay here so we don't send anything before we receive the mesh beacon message
          if (mProvisionedMeshNode != null) {
            final ConfigCompositionDataGet compositionDataGet = new ConfigCompositionDataGet();
            mMeshManagerApi.createMeshPdu(mProvisionedMeshNode.getUnicastAddress(), compositionDataGet);
          }
        }, 2000);

        return true;
      } else {
        mSetupProvisionedNode = false;
        return false;
      }
    }
    return false;
  }

   void sendMessageToAddress(int address, int modelId, int companyIdentifier, String opcode, String parameters) {

    final ApplicationKey appKey = mMeshManagerApi.getMeshNetwork().getAppKey(0);
    if (appKey != null) {

      connectToProxyNode();

      if (mBleMeshManager.isConnected()) {
        VendorModelMessageAcked meshMessage = new VendorModelMessageAcked(appKey, modelId, companyIdentifier, Integer.parseInt(opcode, 16), MeshParserUtils.toByteArray(parameters));
        mMeshManagerApi.createMeshPdu(address,meshMessage);

      }
      else {
        mHandler.postDelayed(() -> {
          //Adding a slight delay here so we don't send anything before we receive the mesh beacon message

            stopScan();
          if (mBleMeshManager.isConnected()) {
            VendorModelMessageAcked meshMessage = new VendorModelMessageAcked(appKey, modelId, companyIdentifier, Integer.parseInt(opcode, 16), MeshParserUtils.toByteArray(parameters));
            mMeshManagerApi.createMeshPdu(address,meshMessage);

          }
          else {

          }

        }, 5000);
      }
    }

  }

  private boolean bindAppKeyToModel(int modelId,int  nodeAddress) {
    final ApplicationKey appKey = mMeshManagerApi.getMeshNetwork().getAppKey(0);

    ProvisionedMeshNode node = mMeshManagerApi.getMeshNetwork().getNode(nodeAddress);

    if (node != null && appKey != null) {
      for (Element element : node.getElements().values()) {
        if (element.getMeshModels().containsKey(modelId)) {
//          MeshModel model = element.getMeshModels().get(modelId);
          final ConfigModelAppBind configModelAppBind = new ConfigModelAppBind(element.getElementAddress(), modelId, 0);
          mMeshManagerApi.createMeshPdu(node.getUnicastAddress(), configModelAppBind);
          return true;
        }

      }
    }

    return false;
  }

  private boolean setPublicationToAddress(int publicAddress, int modelId, int nodeAddress) {


    ProvisionedMeshNode node = mMeshManagerApi.getMeshNetwork().getNode(nodeAddress);

    if (node != null) {
      for (Element element : node.getElements().values()) {
        if (element.getMeshModels().containsKey(modelId)) {
          MeshModel model = element.getMeshModels().get(modelId);
          final MeshMessage configModelPublicationSet = createMessage(element, model, publicAddress);
          mMeshManagerApi.createMeshPdu(node.getUnicastAddress(), configModelPublicationSet);
          return true;
        }
      }
    }
    return false;
  }

  public MeshMessage createMessage(Element element, MeshModel model, int publishAddress) {
    if (element != null && model != null) {
      final AddressType type = MeshAddress.getAddressType(publishAddress);
      if (type != null && type != AddressType.VIRTUAL_ADDRESS) {
        return new ConfigModelPublicationSet(element.getElementAddress(),
                publishAddress,
                0,
                false,
                0xFF,
                0,
                0b00,
                1,
                1,
                model.getModelId());
      } else {
        return new ConfigModelPublicationVirtualAddressSet(element.getElementAddress(),
                UUID.randomUUID(),
                0,
                false,
                0xFF,
                0,
                0b00,
                1,
                1,
                model.getModelId());
      }
    }
    return null;
  }


  private void resetAllProcess() {
    if (mIsScanning) {
      stopScan();
      mIsScanning = false;
    }

    if (mSelectedDevice != null) {
      mBleMeshManager.disconnect().enqueue();
    }

    mDevices.clear();
    mSetupProvisionedNode = false;
    mUnprovisionedMeshNode = null;
    mProvisionedMeshNode = null;
    mConnectToProxyNode = false;

  }

  private void connectToProxyNode() {

    if (!mBleMeshManager.isConnected()) {
      mConnectToProxyNode = true;
      stopScan();
      startScan(BleMeshManager.MESH_PROXY_UUID);
    }
  }

  private void addGroupAddress() {
    final ProxyConfigSetFilterType setFilterType = new ProxyConfigSetFilterType(new ProxyFilterType(ProxyFilterType.INCLUSION_LIST_FILTER));

    try {
      mMeshManagerApi.createMeshPdu(MeshAddress.UNASSIGNED_ADDRESS, setFilterType);
      mHandler.postDelayed(() -> {
        final byte[] address = MeshParserUtils.toByteArray("F000");
        List<AddressArray> addresses = new ArrayList<>();
        addresses.add(new AddressArray(address[0], address[1]));
        final ProxyConfigAddAddressToFilter addAddressToFilter = new ProxyConfigAddAddressToFilter(addresses);
        mMeshManagerApi.createMeshPdu(MeshAddress.UNASSIGNED_ADDRESS, addAddressToFilter);
      }, 3000);
    } catch (IllegalArgumentException ex) {

    }
  }


  private boolean removeNodeInMesh(Integer address) {

    ProvisionedMeshNode node = mMeshNetwork.getNode(address);
    if (node != null) {
      mMeshNetwork.deleteNode(node);
    }
    return false;
  }

  private void disConnectProvisionNode() {
    if (mSelectedDevice != null) {
      mBleMeshManager.disconnect().enqueue();
    }
  }

  private  boolean checkHasMeshNetwork() {
    return mMeshNetwork != null;
  }




  private byte[] getMeshBeaconData(@NonNull final byte[] advertisementData) {
    if (isMeshBeacon(advertisementData)) {
      for (int i = 0; i < advertisementData.length; i++) {
        final int length = MeshParserUtils.unsignedByteToInt(advertisementData[i]);
        final int type = MeshParserUtils.unsignedByteToInt(advertisementData[i + 1]);
        if (type == 0x2B || type == 0x16) {
          final byte[] beaconData = new byte[length];
          final ByteBuffer buffer = ByteBuffer.wrap(advertisementData);
          buffer.position(i + 2);
          buffer.get(beaconData, 0, length);
          return beaconData;
        }
        i = i + length;
      }
    }
    return null;
  }

  private boolean isMeshBeacon(@NonNull final byte[] advertisementData) {
    for (int i = 0; i < advertisementData.length; i++) {
      final int length = MeshParserUtils.unsignedByteToInt(advertisementData[i]);
      if (length == 0)
        break;
      final int type = MeshParserUtils.unsignedByteToInt(advertisementData[i + 1]);
      if (type == 0x2B || type == 0x16) {
        return true;
      }
      i = i + length;
    }
    return false;
  }
}
