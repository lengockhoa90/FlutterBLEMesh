/*
* Copyright (c) 2019, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation
import nRFMeshProvision

extension UInt16 {
    
    // Bluetooth SIG Models
    static let configurationServerModelId: UInt16 = 0x0000
    static let configurationClientModelId: UInt16 = 0x0001
    
    static let genericOnOffServerModelId: UInt16 = 0x1000
    static let genericOnOffClientModelId: UInt16 = 0x1001
    static let genericLevelServerModelId: UInt16 = 0x1002
    static let genericLevelClientModelId: UInt16 = 0x1003
    
    static let genericDefaultTransitionTimeServerModelId: UInt16 = 0x1004
    static let genericDefaultTransitionTimeClientModelId: UInt16 = 0x1005
    
    static let sceneServerModelId: UInt16 = 0x1203
    static let sceneSetupServerModelId: UInt16 = 0x1204
    static let sceneClientModelId: UInt16 = 0x1205
    
    static let sensorServerModelId: UInt16 = 0x1100
    static let sensorServerSetupModelId: UInt16 = 0x1101
    static let sensorClientModelId: UInt16 = 0x1102
    
    // Supported vendor models
    static let simpleOnOffModelId: UInt16 = 0x0001
    static let nordicSemiconductorCompanyId: UInt16 = 0x0059
    
}
