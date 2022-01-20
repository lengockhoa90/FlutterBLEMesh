package vn.vconnex.nrf_ble_mesh_plugin;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.BluetoothLeScanner;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import no.nordicsemi.android.mesh.MeshManagerApi;
import no.nordicsemi.android.mesh.MeshNetwork;
import no.nordicsemi.android.mesh.transport.ProvisionedMeshNode;
import no.nordicsemi.android.support.v18.scanner.BluetoothLeScannerCompat;
import no.nordicsemi.android.support.v18.scanner.ScanCallback;
import no.nordicsemi.android.support.v18.scanner.ScanFilter;
import no.nordicsemi.android.support.v18.scanner.ScanRecord;
import no.nordicsemi.android.support.v18.scanner.ScanResult;
import no.nordicsemi.android.support.v18.scanner.ScanSettings;
import vn.vconnex.nrf_ble_mesh_plugin.ble.BleMeshManager;
import vn.vconnex.nrf_ble_mesh_plugin.utils.Utils;
import vn.vconnex.nrf_ble_mesh_plugin.viewmodels.ScannerLiveData;
import vn.vconnex.nrf_ble_mesh_plugin.viewmodels.ScannerStateLiveData;


/** NrfBleMeshPlugin */
public class NrfBleMeshPlugin implements FlutterPlugin, MethodCallHandler {

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

  private UUID mFilterUuid;

  private  ScannerLiveData mScannerLiveData;
  private  ScannerStateLiveData mScannerStateLiveData;


  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    mContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "nrf_ble_mesh_plugin");
    channel.setMethodCallHandler(this);

    stateChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "blufi_plugin/state");
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
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
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
    else if (call.method.equals("scanUnProvisionDevice")) {
      result.success(scanUnProvisionDevice());
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
//    mMeshManagerApi.setMeshManagerCallbacks(this);
//    mMeshManagerApi.setProvisioningStatusCallbacks(this);
//    mMeshManagerApi.setMeshStatusCallbacks(this);


    //Initialize the ble manager
    mBleMeshManager = new BleMeshManager(mContext);
    mBleMeshManager.setGattCallbacks(this);
    mHandler = new Handler(Looper.getMainLooper());

    mScannerStateLiveData = new ScannerStateLiveData(Utils.isBleEnabled(), Utils.isLocationEnabled(mContext));
    mScannerLiveData = new ScannerLiveData();

  }

  void clearInstance() {
    mBleMeshManager = null;
  }

  Boolean createOrLoadSavedMeshNetwork() {
    mMeshManagerApi.loadMeshNetwork();

    return false;
  }

  Boolean importMeshNetworkFromJson(String json) {

    return false;
  }

  Boolean exportMeshNetwork() {

    return false;
  }

  Boolean scanUnProvisionDevice() {

    // First, check the Location permission. This is required on Marshmallow onwards in order to scan for Bluetooth LE devices.
    if (Utils.isLocationPermissionsGranted(mContext)) {

      // Bluetooth must be enabled
      if (getScannerState().isBluetoothEnabled()) {

        if (!getScannerState().isScanning()) {
          // We are now OK to start scanning
          startScan(BleMeshManager.MESH_PROVISIONING_UUID);
          return true;
        }
      } else {
        return false;
      }
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

    if (mScannerStateLiveData.isScanning()) {
      return;
    }

    mScannerStateLiveData.scanningStarted();
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
  }

  /**
   * stop scanning for bluetooth devices.
   */
  public void stopScan() {
    final BluetoothLeScannerCompat scanner = BluetoothLeScannerCompat.getScanner();
    scanner.stopScan(mScanCallbacks);
    mScannerStateLiveData.scanningStopped();
    mScannerLiveData.clear();
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
        } else if (mFilterUuid.equals(BleMeshManager.MESH_PROXY_UUID)) {
          final byte[] serviceData = Utils.getServiceData(result, BleMeshManager.MESH_PROXY_UUID);
          if (mMeshManagerApi != null) {
            if (mMeshManagerApi.isAdvertisingWithNetworkIdentity(serviceData)) {
              if (mMeshManagerApi.networkIdMatches(null, serviceData)) {
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
      mScannerStateLiveData.scanningStopped();
    }
  };


  public ScannerStateLiveData getScannerState() {
    return mScannerStateLiveData;
  }

  public ScannerLiveData getScannerResults() {
    return mScannerLiveData;
  }

  private void updateScannerLiveData(final ScanResult result) {
    final ScanRecord scanRecord = result.getScanRecord();
    if (scanRecord != null) {
      if (scanRecord.getBytes() != null) {
        final byte[] beaconData = mMeshManagerApi.getMeshBeaconData(scanRecord.getBytes());
        if (beaconData != null) {
          mScannerLiveData.deviceDiscovered(result, mMeshManagerApi.getMeshBeacon(beaconData));
        } else {
          mScannerLiveData.deviceDiscovered(result);
        }
        mScannerStateLiveData.deviceFound();
      }
    }
  }

  /**
   * Check if node identity matches
   *
   * @param serviceData service data received from the advertising data
   * @return true if the node identity matches or false otherwise
   */
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




}
