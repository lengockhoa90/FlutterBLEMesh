//
//  VcnGetDataMessage.swift
//  Pods
//
//  Created by Macbook on 5/23/22.
//

import Foundation
import nRFMeshProvision

public struct VcnGetDataMessage: MeshMessage {
    // The opcode is set when the message is received. Initially it is set
    // to 0, as the constructor takes only parameters.
    public internal(set) var opCode: UInt32 = 0xD20100
    
    public let parameters: Data?
    
    public init?(parameters: Data) {
        self.parameters = parameters
    }
    
}

extension VcnGetDataMessage: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let opCodeHex = opCode
        let parametersHex = parameters?.hex ?? "nil"
        return "UnknownMessage(opCode: 0x\(opCodeHex), parameters: \(parametersHex))"
    }
    
}
