import Flutter
import UIKit
import os.log
import nRFMeshProvision
import CoreBluetooth

typealias DiscoveredPeripheral = (
    device: UnprovisionedDevice,
    peripheral: CBPeripheral,
    rssi: Int
)

public class SwiftNrfBleMeshPlugin: NSObject, FlutterPlugin {
    
    var streamHandle : SwiftStreamHandler?
    
    var meshNetworkManager: MeshNetworkManager!
    var connection: NetworkConnection!
    
    // MARK: - Properties
        
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [DiscoveredPeripheral] = []
    private var selectedDevice: UnprovisionedDevice?
    
//    var unprovisionedDevice: UnprovisionedDevice!
    var bearer: PBGattBearer?
    
    private var publicKey: PublicKey?
    private var authenticationMethod: AuthenticationMethod?
    private var provisioningManager: ProvisioningManager!
    
    private var capabilitiesReceived = false
    
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(name: "nrf_ble_mesh_plugin", binaryMessenger: registrar.messenger())
      
      let instance = SwiftNrfBleMeshPlugin()
      
      let eventChannel = FlutterEventChannel(name: "nrf_ble_mesh_plugin_event_channel", binaryMessenger: registrar.messenger())
      let streamHandle = SwiftStreamHandler()
      eventChannel.setStreamHandler(streamHandle)
      instance.streamHandle = streamHandle
      registrar.addMethodCallDelegate(instance, channel: channel)
      
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        if call.method == "getPlatformVersion" {
            result("iOS " + UIDevice.current.systemVersion)
        }
        else if call.method == "initMeshNetworkManager" {
            self.initMeshNetworkManager()
        }
        else if call.method == "createOrLoadSavedMeshNetwork" {
            result(self.createOrLoadSavedMeshNetwork())
        }
        else if call.method == "importMeshNetworkFromJson" {
            result(self.importMeshNetworkFromJson(json: call.arguments as! String))
        }
        else if call.method == "exportMeshNetwork" {
            result(exportMeshNetwork())
        }
        else if call.method == "scanUnProvisionDevice" {
            result(scanUnProvisionDevice())
        }
        else if call.method == "selectedProvisionDevice" {
            result(selectedProvisionDevice(uuidStr: call.arguments as! String))
        }
        else if call.method == "startProvisioning" {
            result(startProvisioning())
        }
    }
    
    
    func initMeshNetworkManager() {
        meshNetworkManager = MeshNetworkManager()
        meshNetworkManager.acknowledgmentTimerInterval = 0.600
        meshNetworkManager.transmissionTimerInterval = 0.600
        meshNetworkManager.retransmissionLimit = 2
        meshNetworkManager.acknowledgmentMessageInterval = 5.0
        meshNetworkManager.acknowledgmentMessageTimeout = 40.0
        meshNetworkManager.logger = self
    }
    
    func createOrLoadSavedMeshNetwork() -> Bool {
        // Try loading the saved configuration.
        var loaded = false
        do {
            loaded = try meshNetworkManager.load()
        } catch {
            print(error)
            // ignore
        }
        
        // If load failed, create a new MeshNetwork.
        if !loaded {
            createNewMeshNetwork()
        } else {
            meshNetworkDidChange()
        }
        
        return loaded
    }
    
    func importMeshNetworkFromJson(json : String) -> Bool {
        
        return true
    }
    
    func exportMeshNetwork() -> String {
        
        return ""
    }
    
    
    
    /// This method creates a new mesh network with a default name and a
    /// single Provisioner. When done, if calls `meshNetworkDidChange()`.
    func createNewMeshNetwork() {
        // TODO: Implement creator
        let provisioner = Provisioner(name: UIDevice.current.name,
                                      allocatedUnicastRange: [AddressRange(0x0001...0x199A)],
                                      allocatedGroupRange:   [AddressRange(0xC000...0xCC9A)],
                                      allocatedSceneRange:   [SceneRange(0x0001...0x3333)])
        _ = meshNetworkManager.createNewMeshNetwork(withName: "Vconnex Mesh Network", by: provisioner)
        _ = meshNetworkManager.save()
        
        meshNetworkDidChange()
    }
    
    /// Sets up the local Elements and reinitializes the `NetworkConnection`
    /// so that it starts scanning for devices advertising the new Network ID.
    func meshNetworkDidChange() {
        connection?.close()
        
        let meshNetwork = meshNetworkManager.meshNetwork!

        // Generic Default Transition Time Server model:
        let defaultTransitionTimeServerDelegate = GenericDefaultTransitionTimeServerDelegate(meshNetwork)
        // Scene Server and Scene Setup Server models:
        let sceneServer = SceneServerDelegate(meshNetwork,
                                              defaultTransitionTimeServer: defaultTransitionTimeServerDelegate, meshNetworkManager: meshNetworkManager)
        let sceneSetupServer = SceneSetupServerDelegate(server: sceneServer, meshNetworkManager: meshNetworkManager)
        
        // Set up local Elements on the phone.
        let element0 = Element(name: "Primary Element", location: .first, models: [
            // Scene Server and Scene Setup Server models (client is added automatically):
            Model(sigModelId: .sceneServerModelId, delegate: sceneServer),
            Model(sigModelId: .sceneSetupServerModelId, delegate: sceneSetupServer),
            // Sensor Client model:
            Model(sigModelId: .sensorClientModelId, delegate: SensorClientDelegate()),
            // Generic Default Transition Time Server model:
            Model(sigModelId: .genericDefaultTransitionTimeServerModelId,
                  delegate: defaultTransitionTimeServerDelegate),
            Model(sigModelId: .genericDefaultTransitionTimeClientModelId,
                  delegate: GenericDefaultTransitionTimeClientDelegate(meshNetworkManager: meshNetworkManager)),
            // 4 generic models defined by Bluetooth SIG:
            Model(sigModelId: .genericOnOffServerModelId,
                  delegate: GenericOnOffServerDelegate(meshNetwork,
                                                       defaultTransitionTimeServer: defaultTransitionTimeServerDelegate,
                                                       elementIndex: 0, meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericLevelServerModelId,
                  delegate: GenericLevelServerDelegate(meshNetwork,
                                                       defaultTransitionTimeServer: defaultTransitionTimeServerDelegate,
                                                       elementIndex: 0, meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericOnOffClientModelId, delegate: GenericOnOffClientDelegate(meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericLevelClientModelId, delegate: GenericLevelClientDelegate(meshNetworkManager: meshNetworkManager)),
            // A simple vendor model:
            Model(vendorModelId: .simpleOnOffModelId,
                  companyId: .nordicSemiconductorCompanyId,
                  delegate: SimpleOnOffClientDelegate(meshNetworkManager: self.meshNetworkManager))
        ])
        let element1 = Element(name: "Secondary Element", location: .second, models: [
            Model(sigModelId: .genericOnOffServerModelId,
                  delegate: GenericOnOffServerDelegate(meshNetwork,
                                                       defaultTransitionTimeServer: defaultTransitionTimeServerDelegate,
                                                       elementIndex: 1, meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericLevelServerModelId,
                  delegate: GenericLevelServerDelegate(meshNetwork,
                                                       defaultTransitionTimeServer: defaultTransitionTimeServerDelegate,
                                                       elementIndex: 1, meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericOnOffClientModelId, delegate: GenericOnOffClientDelegate(meshNetworkManager: meshNetworkManager)),
            Model(sigModelId: .genericLevelClientModelId, delegate: GenericLevelClientDelegate(meshNetworkManager: meshNetworkManager))
        ])
        meshNetworkManager.localElements = [element0, element1]
        
        connection = NetworkConnection(to: meshNetwork)
        connection!.dataDelegate = meshNetworkManager
        connection!.logger = self
        meshNetworkManager.transmitter = connection
        connection!.open()
    }
    
    
    func scanUnProvisionDevice() -> Bool {
        centralManager = CBCentralManager()
        centralManager.delegate = self
        if centralManager.state == .poweredOn {
            startScanning()
            return true
        }
        else {
            return false
        }
    }
    
    func selectedProvisionDevice(uuidStr : String) -> Bool {
        if let existsPeripheral = discoveredPeripherals.first(where: {$0.device.uuid.uuidString == uuidStr }) {
            stopScanning()
            
            bearer = PBGattBearer(target: existsPeripheral.peripheral)
            bearer?.logger = meshNetworkManager.logger
            bearer?.delegate = self
            
            
            selectedDevice = existsPeripheral.device
            
            bearer?.open()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                self.provisioningManager = try! self.meshNetworkManager.provision(unprovisionedDevice: self.selectedDevice!, over: self.bearer!)
                self.provisioningManager.delegate = self
                self.provisioningManager.logger = self.meshNetworkManager.logger
                
                do {
                    try self.provisioningManager.identify(andAttractFor: 5)
                } catch {
        //            self.abort()
        //            self.presentAlert(title: "Error", message: error.localizedDescription)
                }
            })
            
            
           
            
            return true
        }
        return false
    }

 
}

// MARK: - Logger

extension SwiftNrfBleMeshPlugin: LoggerDelegate {
    
    public func log(message: String, ofCategory category: LogCategory, withLevel level: LogLevel) {
        if #available(iOS 10.0, *) {
            os_log("%{public}@", log: category.log, type: level.type, message)
        } else {
            NSLog("%@", message)
        }
    }
    
}

extension LogLevel {
    
    /// Mapping from mesh log levels to system log types.
    var type: OSLogType {
        switch self {
        case .debug:       return .debug
        case .verbose:     return .debug
        case .info:        return .info
        case .application: return .default
        case .warning:     return .error
        case .error:       return .fault
        }
    }
    
}

extension LogCategory {
    
    var log: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier!, category: rawValue)
    }
    
}


// MARK: - CBCentralManagerDelegate

extension SwiftNrfBleMeshPlugin: CBCentralManagerDelegate {
    
    private func startScanning() {
        centralManager.scanForPeripherals(withServices: [MeshProvisioningService.uuid],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    private func stopScanning() {
        centralManager.stopScan()
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {

        
        
        
        if discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) != nil {

        } else {
            if let unprovisionedDevice = UnprovisionedDevice(advertisementData: advertisementData) {
                discoveredPeripherals.append((unprovisionedDevice, peripheral, RSSI.intValue))
                sendEvent(["detectUnprovisionDevice": ["uuid": unprovisionedDevice.uuid.uuidString, "rssi" : RSSI.intValue, "name" : peripheral.name ?? "__"]])
                
                NSLog("%@", peripheral.name ?? "__")
                
            
            }
        }
        
        
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            print("Central is not powered on")
            sendEvent(["centralManager" : "notPowerOn"])
        } else {
            startScanning()
            sendEvent(["centralManager" : "startScanning"])
        }
    }
    
}

extension SwiftNrfBleMeshPlugin: GattBearerDelegate {
    
    public func bearerDidConnect(_ bearer: Bearer) {
        
        sendEvent(["bearerDelegate" : "bearerDidConnect"])
    }
    
    public func bearerDidDiscoverServices(_ bearer: Bearer) {

        sendEvent(["bearerDelegate" : "bearerDidDiscoverServices"])
    }
        
    public func bearerDidOpen(_ bearer: Bearer) {

        sendEvent(["bearerDelegate" : "bearerDidOpen"])
    }
    
    public func bearer(_ bearer: Bearer, didClose error: Error?) {
    
        self.selectedDevice = nil
    
        sendEvent(["bearerDelegate" : "bearerDidClose"])
        
    }
    
}

extension SwiftNrfBleMeshPlugin: ProvisioningDelegate {
    
    public func provisioningState(of unprovisionedDevice: UnprovisionedDevice, didChangeTo state: ProvisioningState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
                
            case .requestingCapabilities:
                self.sendEvent(["provisioningDelegate" : ["state": "Identifying"]])
//                self.presentStatusDialog(message: "Identifying...")
                
            case .capabilitiesReceived(let capabilities):
//                self.elementsCountLabel.text = "\(capabilities.numberOfElements)"
//                self.supportedAlgorithmsLabel.text = "\(capabilities.algorithms)"
//                self.publicKeyTypeLabel.text = "\(capabilities.publicKeyType)"
//                self.staticOobTypeLabel.text = "\(capabilities.staticOobType)"
//                self.outputOobSizeLabel.text = "\(capabilities.outputOobSize)"
//                self.supportedOutputOobActionsLabel.text = "\(capabilities.outputOobActions)"
//                self.inputOobSizeLabel.text = "\(capabilities.inputOobSize)"
//                self.supportedInputOobActionsLabel.text = "\(capabilities.inputOobActions)"
                
                // If the Unicast Address was set to automatic (nil), it should be
                // set to the correct value by now, as we know the number of elements.
                let addressValid = self.provisioningManager.isUnicastAddressValid == true
                if !addressValid {
                   self.provisioningManager.unicastAddress = nil
                }
//                self.unicastAddressLabel.text = self.provisioningManager.unicastAddress?.asString() ?? "No address available"
//                self.actionProvision.isEnabled = addressValid
//
                let capabilitiesWereAlreadyReceived = self.capabilitiesReceived
                self.capabilitiesReceived = true
                
                let deviceSupported = self.provisioningManager.isDeviceSupported == true
                
                                if deviceSupported && addressValid {
                                    // If the device got disconnected after the capabilities were received
                                    // the first time, the app had to send invitation again.
                                    // This time we can just directly proceed with provisioning.
                                    if capabilitiesWereAlreadyReceived {
                                        _ = self.startProvisioning()
                                    }
                                    
                                }
                
//                self.dismissStatusDialog {
//                    if deviceSupported && addressValid {
//                        // If the device got disconnected after the capabilities were received
//                        // the first time, the app had to send invitation again.
//                        // This time we can just directly proceed with provisioning.
//                        if capabilitiesWereAlreadyReceived {
//                            self.startProvisioning()
//                        }
//                    } else {
//                        if !deviceSupported {
//                            self.presentAlert(title: "Error", message: "Selected device is not supported.")
//                            self.actionProvision.isEnabled = false
//                        } else if !addressValid {
//                            self.presentAlert(title: "Error", message: "No available Unicast Address in Provisioner's range.")
//                        }
//                    }
//                }
                
            case .complete:
            
                self.bearer?.close()
//                self.presentStatusDialog(message: "Disconnecting...")
                
            case let .fail(_): break
//                self.dismissStatusDialog {
//                    self.presentAlert(title: "Error", message: error.localizedDescription)
//                    self.abort()
//                }
                
            default:
                break
            }
        }
    }
    
    public func authenticationActionRequired(_ action: AuthAction) {
//        switch action {
//        case let .provideStaticKey(callback: callback):
//            self.dismissStatusDialog {
//                let message = "Enter 16-character hexadecimal string."
//                self.presentTextAlert(title: "Static OOB Key", message: message,
//                                      type: .keyRequired, cancelHandler: nil) { hex in
//                    callback(Data(hex: hex))
//                }
//            }
//        case let .provideNumeric(maximumNumberOfDigits: _, outputAction: action, callback: callback):
//            self.dismissStatusDialog {
//                var message: String
//                switch action {
//                case .blink:
//                    message = "Enter number of blinks."
//                case .beep:
//                    message = "Enter number of beeps."
//                case .vibrate:
//                    message = "Enter number of vibrations."
//                case .outputNumeric:
//                    message = "Enter the number displayed on the device."
//                default:
//                    message = "Action \(action) is not supported."
//                }
//                self.presentTextAlert(title: "Authentication", message: message,
//                                      type: .unsignedNumberRequired, cancelHandler: nil) { text in
//                    callback(UInt(text)!)
//                }
//            }
//        case let .provideAlphanumeric(maximumNumberOfCharacters: _, callback: callback):
//            self.dismissStatusDialog {
//                let message = "Enter the text displayed on the device."
//                self.presentTextAlert(title: "Authentication", message: message,
//                                      type: .nameRequired, cancelHandler: nil) { text in
//                    callback(text)
//                }
//            }
//        case let .displayAlphanumeric(text):
//            self.presentStatusDialog(message: "Enter the following text on your device:\n\n\(text)")
//        case let .displayNumber(value, inputAction: action):
//            self.presentStatusDialog(message: "Perform \(action) \(value) times on your device.")
//        }
    }
    
    public func inputComplete() {
//        self.presentStatusDialog(message: "Provisioning...")
    }
    
}


extension SwiftNrfBleMeshPlugin {
    func sendEvent(_ data: Dictionary<String, Any>) {
        if streamHandle != nil && streamHandle?.eventSink != nil {
            self.streamHandle?.eventSink!(data)
        }
    }
}


class SwiftStreamHandler: NSObject, FlutterStreamHandler {
    public var eventSink : FlutterEventSink?
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        
        eventSink = events;
 
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

private extension SwiftNrfBleMeshPlugin {
    
    /// This method tries to open the bearer had it been closed when on this screen.
    func openBearer() {
        if self.bearer != nil && !self.bearer!.isOpen {
            self.bearer?.open()
        }

    }
    
    
    func closeBearer() {
        if self.bearer != nil && self.bearer!.isOpen {
            self.bearer?.close()
        }
    }
    
    /// Starts provisioning process of the device.
    func startProvisioning() -> String {
        
       
        
        guard let capabilities = provisioningManager.provisioningCapabilities else {
            return "notCapabilities"
        }
        
        // If the device's Public Key is available OOB, it should be read.
        let publicKeyNotAvailable = capabilities.publicKeyType.isEmpty
        guard publicKeyNotAvailable || publicKey != nil else {
            
            return "publicKeyNotAvailable"
        }
        publicKey = publicKey ?? .noOobPublicKey
        
        // If any of OOB methods is supported, if should be chosen.
        let staticOobNotSupported = capabilities.staticOobType.isEmpty
        let outputOobNotSupported = capabilities.outputOobActions.isEmpty
        let inputOobNotSupported  = capabilities.inputOobActions.isEmpty
        guard (staticOobNotSupported && outputOobNotSupported && inputOobNotSupported) || authenticationMethod != nil else {
//            self.startProvisioning()
            return "obbNotSupport"
        }
        
        // If none of OOB methods are supported, select the only option left.
        if authenticationMethod == nil {
            authenticationMethod = .noOob
        }
        
        if provisioningManager.networkKey == nil {
            let network = meshNetworkManager.meshNetwork!
            let networkKey = try! network.add(networkKey: Data.random128BitKey(), name: "Primary Network Key")
            provisioningManager.networkKey = networkKey
        }
        
        // Start provisioning.
        do {
            try self.provisioningManager.provision(usingAlgorithm:       .fipsP256EllipticCurve,
                                                   publicKey:            self.publicKey!,
                                                   authenticationMethod: self.authenticationMethod!)
            return "provisioningStarted"
        } catch {
//            self.abort()
//            self.presentAlert(title: "Error", message: error.localizedDescription)
            
            return "provisioningFail"
        }
    }
    
}


