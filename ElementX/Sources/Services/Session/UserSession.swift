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

class UserSession: UserSessionProtocol {
    private var cancellables = Set<AnyCancellable>()
    private var checkForSessionVerificationControllerCancellable: AnyCancellable?
    private var authErrorCancellable: AnyCancellable?
    
    var userID: String { clientProxy.userID }
    var deviceID: String? { clientProxy.deviceID }
    var homeserver: String { clientProxy.homeserver }

    let clientProxy: ClientProxyProtocol
    let mediaProvider: MediaProviderProtocol
    let voiceMessageMediaManager: VoiceMessageMediaManagerProtocol
    
    let callbacks = PassthroughSubject<UserSessionCallback, Never>()
    
    private(set) var sessionVerificationController: SessionVerificationControllerProxyProtocol?
    
    private var sessionVerificationStateSubject: CurrentValueSubject<Bool?, Never> = .init(nil)
    var sessionVerificationState: CurrentValuePublisher<Bool?, Never> {
        sessionVerificationStateSubject.asCurrentValuePublisher()
    }
    
    init(clientProxy: ClientProxyProtocol, mediaProvider: MediaProviderProtocol, voiceMessageMediaManager: VoiceMessageMediaManagerProtocol) {
        self.clientProxy = clientProxy
        self.mediaProvider = mediaProvider
        self.voiceMessageMediaManager = voiceMessageMediaManager
        
        setupSessionVerificationWatchdog()
        setupAuthErrorWatchdog()
    }
    
    // MARK: - Private
    
    private func setupSessionVerificationWatchdog() {
        checkForSessionVerificationControllerCancellable = clientProxy.callbacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] callback in
                if case .receivedSyncUpdate = callback {
                    self?.attemptSessionVerification()
                }
            }
    }
    
    private func attemptSessionVerification() {
        Task {
            switch await clientProxy.sessionVerificationControllerProxy() {
            case .success(let sessionVerificationController):
                guard case let .success(isVerified) = await sessionVerificationController.isVerified() else {
                    MXLog.error("Failed checking verification state. Will retry on the next sync update.")
                    return
                }
                
                tearDownSessionVerificationControllerWatchdog()
                
                self.sessionVerificationController = sessionVerificationController
                
                sessionVerificationStateSubject.send(isVerified)
                
                sessionVerificationController.callbacks.sink { [weak self] callback in
                    switch callback {
                    case .finished:
                        self?.sessionVerificationStateSubject.send(true)
                    default:
                        break
                    }
                }
                .store(in: &cancellables)
                
            case .failure(let error):
                MXLog.info("Failed getting session verification controller with error: \(error). Will retry on the next sync update.")
            }
        }
    }
    
    private func tearDownSessionVerificationControllerWatchdog() {
        checkForSessionVerificationControllerCancellable = nil
    }

    // MARK: Auth Error Watchdog

    private func setupAuthErrorWatchdog() {
        authErrorCancellable = clientProxy.callbacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] callback in
                guard let self else { return }
                switch callback {
                case .receivedAuthError(let isSoftLogout):
                    callbacks.send(.didReceiveAuthError(isSoftLogout: isSoftLogout))
                    tearDownAuthErrorWatchdog()
                default:
                    break
                }
            }
    }

    private func tearDownAuthErrorWatchdog() {
        authErrorCancellable = nil
    }
}
