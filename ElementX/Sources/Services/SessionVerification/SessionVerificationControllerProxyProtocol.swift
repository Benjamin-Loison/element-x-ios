//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import Foundation

enum SessionVerificationControllerProxyError: Error {
    case failedCheckingVerificationState
    case failedRequestingVerification
    case failedStartingSasVerification
    case failedApprovingVerification
    case failedDecliningVerification
    case failedCancellingVerification
}

enum SessionVerificationControllerProxyCallback {
    case acceptedVerificationRequest
    case startedSasVerification
    case receivedVerificationData([SessionVerificationEmoji])
    case finished
    case cancelled
    case failed
}

struct SessionVerificationEmoji: Hashable {
    let symbol: String
    let description: String
}

// sourcery: AutoMockable
protocol SessionVerificationControllerProxyProtocol {
    var callbacks: PassthroughSubject<SessionVerificationControllerProxyCallback, Never> { get }
    
    func isVerified() async -> Result<Bool, SessionVerificationControllerProxyError>
        
    func requestVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    
    func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    
    func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    
    func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    
    func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError>
}
