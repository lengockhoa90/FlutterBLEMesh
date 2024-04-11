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
    
    var bearer: PBGattBearer?
    
    private var publicKey: PublicKey?
    private var authenticationMethod: AuthenticationMethod?
    private var provisioningManager: ProvisioningManager!
    
    private var capabilitiesReceived = false
    private var provisioningSuccess = false
    
    var customUnicastAddress: UInt16?
    
    static let sharedInstance = SwiftNrfBleMeshPlugin()
    private override init() {
        super.init()
        self.initMeshNetworkManager()
    }
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(name: "nrf_ble_mesh_plugin", binaryMessenger: registrar.messenger())
      
        let instance = SwiftNrfBleMeshPlugin.sharedInstance
      
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
            result(self.importMeshNetworkFromJson(json: call.arguments as? String))
        }
        else if call.method == "exportMeshNetwork" {
            result(exportMeshNetwork())
        }
        else if call.method == "scanUnProvisionDevice" {
            result(scanUnProvisionDevice())
        }
        else if call.method == "selectedProvisionDevice" {
            let args : Dictionary = call.arguments as? Dictionary<String, Any> ?? [:]
            
            result(selectedProvisionDevice(uuidStr: args["uuidStr"] as? String ?? "", unicastAddress: args["unicastAddress"] as? UInt16))
        }
        else if call.method == "startProvisioning" {
            result(startProvisioning())
        }
        else if call.method == "stopScanUnProvisionDevice" {
            stopScanning()
        }
        else if call.method == "generateAppKeyForNewMeshNetwork" {
            result(generateAppKeyForNewMeshNetwork())
        }
        else if call.method == "resetAllProcess" {
            resetAllProcess()
        }
        else if call.method == "removeNodeInMesh" {
            result(removeNodeInMesh(address:  UInt16(call.arguments as! Int)))
        }
        else if (call.method == "checkHasMeshNetwork") {
            result(checkHasMeshNetwork())
        }
        else if (call.method == "sendMessageToAddress") {
            guard let args : Dictionary = call.arguments as? Dictionary<String, Any>, let address = args["address"] as? Int32, let vendorId = args["vendorModelId"] as? Int32, let companyId = args["companyId"] as? Int32, let opCodeString = args["opCodeString"] as? String, let paramString = args["params"] as? String  else {
                return
            }
            
            sendMessageToAddress(address: UInt16(address), vendorModelId: UInt16(vendorId), companyId: UInt16(companyId), opCodeString: opCodeString, params: paramString, isSegmented: args["isSegmented"] as? Int, security: args["security"] as? Int)
        }
    }
    
    
    func initMeshNetworkManager() {
        if (meshNetworkManager == nil) {
            
            
            meshNetworkManager = MeshNetworkManager()
            meshNetworkManager.acknowledgmentTimerInterval = 0.600
            meshNetworkManager.transmissionTimerInterval = 0.600
            meshNetworkManager.retransmissionLimit = 2
            meshNetworkManager.acknowledgmentMessageInterval = 5.0
            meshNetworkManager.acknowledgmentMessageTimeout = 40.0
            meshNetworkManager.delegate = self
            meshNetworkManager.logger = self
            
        }
    }
    
    func createOrLoadSavedMeshNetwork() -> Bool {
        createNewMeshNetwork()
        return true;
    }
    
    func importMeshNetworkFromJson(json : String!) -> Bool {
        
        do {
            let data = json.data(using: .utf8)
            if data != nil {
                _ = try meshNetworkManager.import(from: data!)
                if meshNetworkManager.save() {
                    meshNetworkDidChange()
                }
                return true
            }
            else {
                return false
            }
        } catch {
            print("Import failed: \(error)")
        
            return false
        
        }
    }
    
    func exportMeshNetwork() -> String {
    
      let data = meshNetworkManager.export(.full)

            return String(data: data,
                          encoding: .utf8) ?? ""
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
        
        _ = generateAppKeyForNewMeshNetwork()
        
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
                  delegate: SimpleOnOffClientDelegate(meshNetworkManager: self.meshNetworkManager)),
            
            Model(sigModelId: .vendorVconnexOnOffModelId, delegate: GenericLevelClientDelegate(meshNetworkManager: self.meshNetworkManager))
        ])

        meshNetworkManager.localElements = [element0]
        
        connection = NetworkConnection(to: meshNetwork)
        connection!.dataDelegate = meshNetworkManager
        connection!.logger = self
        connection.isConnectionModeAutomatic = true
        meshNetworkManager.transmitter = connection
        connection!.open()
        
        
//       try! addSubscription(to: Group(name: "AAA", address: 0xF000))
        
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
    
    func selectedProvisionDevice(uuidStr : String, unicastAddress : UInt16?) -> Bool {
        if let existsPeripheral = discoveredPeripherals.first(where: {$0.device.uuid.uuidString == uuidStr }) {
            
            if (unicastAddress != nil) {
                self.customUnicastAddress = unicastAddress
//                self.provisioningManager.unicastAddress = Address(unicastAddress!)
            }
            
            stopScanning()
            
            provisioningSuccess = false
            
            bearer = PBGattBearer(target: existsPeripheral.peripheral)
            bearer?.logger = meshNetworkManager.logger
            bearer?.delegate = self
            
            selectedDevice = existsPeripheral.device
            
            bearer?.open()
            
            return true
        }
        return false
    }
    
    
    func addAppkeyForNode() {
        
        if let address = provisioningManager.unicastAddress, let appKey = meshNetworkManager.meshNetwork?.applicationKeys.first, let node = meshNetworkManager.meshNetwork?.node(withAddress: address) {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let message = ConfigAppKeyAdd(applicationKey: appKey)
                _ = try? self.meshNetworkManager.send(message, to: node)
             }
        }
        
    }
    
    func removeNodeInMesh(address : UInt16!) -> Bool {

        let node = meshNetworkManager.meshNetwork?.node(withAddress: address)
        if node != nil {
            meshNetworkManager.meshNetwork?.remove(node: node!)
        }

        if meshNetworkManager.save() {
            return true
        } else {
            return false
        }
    }
    
    func sendMessageToAddress(address : UInt16!, vendorModelId : UInt16!, companyId : UInt16!, opCodeString : String!, params: String!, isSegmented : Int! = 0, security: Int! = 0) {
        
        
        let model : Model = Model(vendorModelId: vendorModelId, companyId: companyId, delegate: SimpleOnOffClientDelegate(meshNetworkManager: meshNetworkManager))
//        let model : Model = Model(vendorModelId: 0x10, companyId: 0x2e5, delegate: SimpleOnOffClientDelegate(meshNetworkManager: meshNetworkManager))
        
        
        if let opCode = UInt8(opCodeString, radix: 16), let meshNetwork = meshNetworkManager.meshNetwork, let appKey = meshNetwork.applicationKeys.first {
            let parameters = Data(hex: params)
            var message = RuntimeVendorMessage(opCode: opCode, for: model, parameters: parameters)
            message.isSegmented = isSegmented == 1
            message.security = security == 1 ? .high : .low
            
            do {
                try meshNetworkManager.send(message, to: MeshAddress(address), using: appKey)
            } catch {
                
            }
        }
    }
    
    func addSubscription(to group: Group) {
                
        guard let model : Model = (meshNetworkManager.localElements.first?.model(withModelId: 0x10)), let node = self.meshNetworkManager.meshNetwork?.localProvisioner, let address = node.unicastAddress else {
            return
        }
        
        if (!model.isSubscribed(to: group)) {
            do {
                let message: ConfigMessage =
                    ConfigModelSubscriptionAdd(group: group, to: model) ??
                    ConfigModelSubscriptionVirtualAddressAdd(group: group, to: model)!
                try self.meshNetworkManager.send(message, to: address)
            }
            catch {
                
            }
        }
    }
    
    func checkHasMeshNetwork() -> Bool {
        return meshNetworkManager.meshNetwork != nil
    }
    
    func bindAppKeyToModel(_ modelId : UInt32?, noteAddress : UInt16?) -> Bool {
        if let address = noteAddress, let appKey = meshNetworkManager.meshNetwork?.applicationKeys.first, let node = meshNetworkManager.meshNetwork?.node(withAddress: address), let modelId = modelId {

                for element in node.elements {
                    if let model = element.model(withModelId: UInt32(modelId)) {
                        if let message = ConfigModelAppBind(applicationKey: appKey, to: model) {
                            _ = try? self.meshNetworkManager.send(message, to: node)
                            
                            return true
                        }
                    }
                }
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
        if centralManager != nil {
            centralManager.stopScan()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if discoveredPeripherals.firstIndex(where: { $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }) != nil {

        } else {
            if let unprovisionedDevice = UnprovisionedDevice(advertisementData: advertisementData) {
                discoveredPeripherals.append((unprovisionedDevice, peripheral, RSSI.intValue))
                
                let uuidString = unprovisionedDevice.uuid.uuidString.replacingOccurrences(of: "-", with: "")
                
               
                if let manufactory = advertisementData[CBAdvertisementDataManufacturerDataKey], let data = manufactory as? Data {
                    let dataString = data.toHexString()
                    
                    sendEvent(["detectUnprovisionDevice": ["uuid": unprovisionedDevice.uuid.uuidString, "rssi" : RSSI.intValue, "name" : peripheral.name ?? advertisementData["kCBAdvDataLocalName"] ?? "__", "macAddressMnf" : getMacFromDataManufacturer(dataString), "deviceTypeMnf" : getDeviceTypeFromManufacturer(dataString), "vendorId" : getVendorIdFromManufacturer(dataString), "userData" : dataString , "macAddress" : getMacFromUUID(uuidString), "deviceType" : getDeviceTypeUUID(uuidString), "firmwareVersion" : getVersionFirmware(uuidString)]])
                }
                else {
                    sendEvent(["detectUnprovisionDevice": ["uuid": unprovisionedDevice.uuid.uuidString, "rssi" : RSSI.intValue, "name" : peripheral.name ?? advertisementData["kCBAdvDataLocalName"] ??  "__", "macAddress" : getMacFromUUID(uuidString), "deviceType" : getDeviceTypeUUID(uuidString), "firmwareVersion" : getVersionFirmware(uuidString)]])
                }
            }
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            sendEvent(["centralManager" : ["state": "notPowerOn"]])
        } else {
            startScanning()
            sendEvent(["centralManager" : ["state" : "startScanning"]])
        }
    }
}

extension SwiftNrfBleMeshPlugin: GattBearerDelegate {
    
    public func bearerDidConnect(_ bearer: Bearer) {
        sendEvent(["bearerDelegate" : ["state": "bearerDidConnect", "uuid": selectedDevice?.uuid.uuidString ?? ""]])
    }
    
    public func bearerDidDiscoverServices(_ bearer: Bearer) {
        sendEvent(["bearerDelegate" : ["state" : "bearerDidDiscoverServices", "uuid": selectedDevice?.uuid.uuidString ?? ""]])
    }
        
    public func bearerDidOpen(_ bearer: Bearer) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            if (self.meshNetworkManager.meshNetwork != nil && self.selectedDevice != nil && self.bearer != nil) {
                self.provisioningManager = try! self.meshNetworkManager.provision(unprovisionedDevice: self.selectedDevice!, over: self.bearer!)
                self.provisioningManager.delegate = self
                self.provisioningManager.logger = self.meshNetworkManager.logger
                
                do {
                    try self.provisioningManager.identify(andAttractFor: 5)
                } catch {

                }
            }
        })
        sendEvent(["bearerDelegate" : ["state" : "bearerDidOpen", "uuid": selectedDevice?.uuid.uuidString ?? ""]])
    }
    
    public func bearer(_ bearer: Bearer, didClose error: Error?) {
        
        sendEvent(["bearerDelegate" : ["state" : "bearerDidClose", "uuid": selectedDevice?.uuid.uuidString ?? ""]])
    }
}

extension SwiftNrfBleMeshPlugin: ProvisioningDelegate {
    
    public func provisioningState(of unprovisionedDevice: UnprovisionedDevice, didChangeTo state: ProvisioningState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
                
            case .requestingCapabilities:
                self.sendEvent(["provisioningDelegate" : ["state" : "Identifying", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
                
            case .capabilitiesReceived(_):

                var addressValid = self.provisioningManager.isUnicastAddressValid == true
                if self.customUnicastAddress != nil {
                    self.provisioningManager.unicastAddress = Address(self.customUnicastAddress!)
                    addressValid = true
                }
                else {
                
                    if !addressValid {
                       self.provisioningManager.unicastAddress = nil
                    }
                }
            

                let deviceSupported = self.provisioningManager.isDeviceSupported == true
                
                                if deviceSupported && addressValid {
                              
                                _ = self.startProvisioning()
                                    self.sendEvent(["provisioningDelegate" : ["state" : "capabilitiesReceived_startProvisioning", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
                                
                                }
                                else {
                                    if !deviceSupported {
                                        self.sendEvent(["provisioningDelegate" :  ["state" : "capabilitiesReceived_deviceNotSupport", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
        } else if !addressValid {
            self.sendEvent(["provisioningDelegate" : ["state": "capabilitiesReceived_addressInvalid", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
                }
            }
                
            case .complete:
                
                try self.bearer?.close()
               
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.provisioningSuccess = true
                    self.addAppkeyForNode()
                }
            
                self.sendEvent(["provisioningDelegate" :  ["state": "provisionSuccessful", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
                
            case .fail(_):
                self.sendEvent(["provisioningDelegate" :  ["state": "provisionFail", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
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
        self.sendEvent(["provisioningDelegate" :  ["state": "provisionProcessing", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
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
    
    func generateAppKeyForNewMeshNetwork () -> String {
        let appKey = Data.random128BitKey()
        _ = try? self.meshNetworkManager.meshNetwork?.add(applicationKey: appKey, name: "App Key")
    
        return appKey.base64EncodedString()
    }
}


extension SwiftNrfBleMeshPlugin : MeshNetworkDelegate {
    
    public func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        // Has the Node been reset remotely.
        guard !(message is ConfigNodeReset) else {

            return
        }
        
        
       
//        if message.opCode == 0xD20100 {
//            NSLog("%@", message.opCode.description)
//        }

        
        // Handle the message based on its type.
        switch message {
            
        case _ as ConfigAppKeyStatus:
            
            self.bearer?.close()
            self.sendEvent(["meshNetworkDelegate" : ["state": "addAppKeySuccessful", "unicashAddress" : self.provisioningManager.unicastAddress?.asString() ?? "", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
            self.selectedDevice = nil
            
        default:
            sendEvent(["receivedMessage" : ["address" : source.hex, "opcode": String(format: "%04X", message.opCode), "param" : message.parameters?.hex ?? ""]])
    
            break
        }
    }
    
    public func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
            
        if (message.opCode == 0x00 && provisioningSuccess && self.bearer != nil) {
            self.bearer?.close()
            self.sendEvent(["meshNetworkDelegate" : ["state": "addAppKeySuccessful", "unicashAddress" : self.provisioningManager.unicastAddress?.asString() ?? "", "uuid": self.selectedDevice?.uuid.uuidString ?? ""]])
            self.selectedDevice = nil
            self.provisioningSuccess = false
        }
    }
    
    
    func getMacFromUUID(_ uuid : String) -> String {
        
        if uuid.count > 16 {
            let start = uuid.index(uuid.startIndex, offsetBy: 4)
            let end = uuid.index(uuid.startIndex, offsetBy: 15)
            let range = start...end
            return String(uuid[range])
        }
        
        return ""
    }
    
    func getDeviceTypeUUID(_ uuid : String) -> UInt32 {
        
        if uuid.count > 20 {
            let start = uuid.index(uuid.startIndex, offsetBy: 16)
            let end = uuid.index(uuid.startIndex, offsetBy: 19)
            let range = start...end
            return UInt32(uuid[range], radix: 16) ?? 0
        }
        
        return 0
    }
    
    func getVersionFirmware(_ uuid : String) -> String {
        
        if uuid.count > 26 {
            let startFirst = uuid.index(uuid.startIndex, offsetBy: 20)
            let endFirst = uuid.index(uuid.startIndex, offsetBy: 23)
            let rangeFirst = startFirst...endFirst
            
            let verCodeFirst = UInt32(uuid[rangeFirst], radix: 16)
            
            let startSecond = uuid.index(uuid.startIndex, offsetBy: 24)
            let endSecond = uuid.index(uuid.startIndex, offsetBy: 27)
            let rangeSecond = startSecond...endSecond
            
            let verCodeSecond = UInt32(uuid[rangeSecond], radix: 16)
            
            let startThird = uuid.index(uuid.startIndex, offsetBy: 28)
            let endThird = uuid.index(uuid.startIndex, offsetBy: 31)
            let rangeThird = startThird...endThird
            
            let verCodeThird = UInt32(uuid[rangeThird], radix: 16)
            
            return "\(String(describing: verCodeFirst ?? 0)).\(String(describing: verCodeSecond ?? 0)).\(String(describing: verCodeThird ?? 0))"
        }
        
        return ""
    }
    
    func getMacFromDataManufacturer(_ manufacturer : String) -> String {
        if manufacturer.count > 16 {
            let start = manufacturer.index(manufacturer.startIndex, offsetBy: 4)
            let end = manufacturer.index(manufacturer.startIndex, offsetBy: 15)
            let range = start...end
            return String(manufacturer[range])
        }
        
        return ""
    }
    
    func getDeviceTypeFromManufacturer(_ manufacturer : String) -> UInt32 {
        
        if manufacturer.count > 42 {
            let start = manufacturer.index(manufacturer.startIndex, offsetBy: 38)
            let end = manufacturer.index(manufacturer.startIndex, offsetBy: 41)
            let range = start...end
            return UInt32(manufacturer[range], radix: 16) ?? 0
        }
        
        return 0
    }
    
    func getVendorIdFromManufacturer(_ manufacturer : String) -> UInt32 {
        
        if manufacturer.count > 4 {
            let start = manufacturer.index(manufacturer.startIndex, offsetBy: 0)
            let end = manufacturer.index(manufacturer.startIndex, offsetBy: 3)
            let range = start...end
            return UInt32(manufacturer[range], radix: 16) ?? 0
        }
        
        return 0
    }
    
    func resetAllProcess() {
        stopScanning()
        if bearer != nil {
            bearer?.close()
        }
        discoveredPeripherals.removeAll()
    
        capabilitiesReceived = false;
        
    }
    
}

struct RuntimeVendorMessage: VendorMessage {
    let opCode: UInt32
    let parameters: Data?
    
    var isSegmented: Bool = false
    var security: MeshMessageSecurity = .low
    
    init(opCode: UInt8, for model: Model, parameters: Data?) {
//        self.opCode = (UInt32(0xC0 | opCode) << 16) | UInt32(model.companyIdentifier!.bigEndian)
        self.opCode = (UInt32(0xC0 | opCode) << 16) | 0x0100
        self.parameters = parameters
    }
    
    init?(parameters: Data) {
        // This init will never be used, as it's used for incoming messages.
        return nil
    }
}

extension RuntimeVendorMessage: CustomDebugStringConvertible {

    var debugDescription: String {
        let hexOpCode = String(format: "%2X", opCode)
        return "RuntimeVendorMessage(opCode: \(hexOpCode), parameters: \(parameters!.hex), isSegmented: \(isSegmented), security: \(security))"
    }
    
}




