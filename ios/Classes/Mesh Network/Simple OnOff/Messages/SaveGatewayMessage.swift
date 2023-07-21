//
//  SaveGatewayMessage.swift
//  nrf_ble_mesh_plugin
//
//  Created by Macbook on 7/19/23.
//

import Foundation
import nRFMeshProvision

public struct SaveGatewayMessage: MeshMessage {
    public init?(parameters: Data) {
        return nil
    }
    
    // The opcode is set when the message is received. Initially it is set
    // to 0, as the constructor takes only parameters.
    public internal(set) var opCode: UInt32 = 0xE01102
//    public internal(set) var opCode: UInt32 = 0xD402E5
    
//    public let opCode: UInt32
    public let parameters: Data?
    
    public init?(opCode: UInt32, parameters: Data?) {
//        self.opCode = (UInt32(0xC0 | opCode) << 16) | UInt32(model.companyIdentifier!.bigEndian)
        self.opCode = 0xE01102
//        self.opCode = (UInt32(0xC0 | opCode) << 16) | 0x02E5
        self.parameters = parameters
    }
    
    
}

extension SaveGatewayMessage: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let opCodeHex = opCode
        let parametersHex = parameters?.hex ?? "nil"
        return "SaveGatewayMessage(opCode: 0x\(opCodeHex), parameters: \(parametersHex))"
    }
    
}
