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
import Compound
import SwiftUI

struct HomeScreenRoomCell: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.redactionReasons) private var redactionReasons
    
    let room: HomeScreenRoom
    let context: HomeScreenViewModel.Context
    let isSelected: Bool
    
    private let verticalInsets = 12.0
    private let horizontalInsets = 16.0
    
    var body: some View {
        Button {
            if let roomId = room.roomId {
                context.send(viewAction: .selectRoom(roomIdentifier: roomId))
            }
        } label: {
            HStack(spacing: 16.0) {
                avatar
                
                content
                    .padding(.vertical, verticalInsets)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.compound.borderDisabled)
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.trailing, -horizontalInsets)
                    }
            }
            .padding(.horizontal, horizontalInsets)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(HomeScreenRoomCellButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.roomName(room.name))
    }
    
    @ViewBuilder @MainActor
    private var avatar: some View {
        if dynamicTypeSize < .accessibility3 {
            LoadableAvatarImage(url: room.avatarURL,
                                name: room.name,
                                contentID: room.roomId,
                                avatarSize: .room(on: .home),
                                imageProvider: context.imageProvider)
                .dynamicTypeSize(dynamicTypeSize < .accessibility1 ? dynamicTypeSize : .accessibility1)
                .accessibilityHidden(true)
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            footer
        }
        // Hide the normal content for Skeletons and overlay centre aligned placeholders.
        .opacity(redactionReasons.contains(.placeholder) ? 0 : 1)
        .overlay {
            if redactionReasons.contains(.placeholder) {
                VStack(alignment: .leading, spacing: 2) {
                    header
                    lastMessage
                }
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(room.name)
                .font(.compound.bodyLGSemibold)
                .foregroundColor(.compound.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let timestamp = room.timestamp {
                Text(timestamp)
                    .font(isHighlighted ? .compound.bodySMSemibold : .compound.bodySM)
                    .foregroundColor(isHighlighted ? .compound.textActionAccent : .compound.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Hidden text with 2 lines to maintain consistent height, scaling with dynamic text.
                Text(" \n ")
                    .lastMessageFormatting()
                    .hidden()
                    .environment(\.redactionReasons, []) // Always maintain consistent height
                
                lastMessage
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if room.hasOngoingCall {
                    CompoundIcon(\.videoCallSolid, size: .xSmall, relativeTo: .compound.bodySM)
                        .foregroundColor(isHighlighted ? .compound.iconAccentTertiary : .compound.iconQuaternary)
                }
                 
                if room.notificationMode == .mute {
                    CompoundIcon(\.notificationsSolidOff, size: .custom(15), relativeTo: .compound.bodyMD)
                        .accessibilityLabel(L10n.a11yNotificationsMuted)
                        .foregroundColor(.compound.iconQuaternary)
                }
                
                if room.hasMentions, room.notificationMode != .mute {
                    mentionIcon
                        .foregroundColor(.compound.iconAccentTertiary)
                }
                
                if hasNewContent {
                    Circle()
                        .frame(width: 12, height: 12)
                        .foregroundColor(isHighlighted ? .compound.iconAccentTertiary : .compound.iconQuaternary)
                }
            }
        }
    }
    
    private var hasNewContent: Bool {
        room.hasUnreads || room.hasMentions
    }
    
    private var isHighlighted: Bool {
        guard !room.isPlaceholder else {
            return false
        }
        return (isNotificationModeUnrestricted && hasNewContent) ||
            (room.notificationMode == .mentionsAndKeywordsOnly && room.hasMentions)
    }
    
    private var isNotificationModeUnrestricted: Bool {
        room.notificationMode == nil || room.notificationMode == .allMessages
    }
        
    private var mentionIcon: some View {
        CompoundIcon(\.mention, size: .custom(15), relativeTo: .compound.bodyMD)
            .accessibilityLabel(L10n.a11yNotificationsMentionsOnly)
    }
    
    @ViewBuilder
    private var lastMessage: some View {
        if let lastMessage = room.lastMessage {
            Text(lastMessage)
                .lastMessageFormatting()
        }
    }
}

struct HomeScreenRoomCellButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isSelected ? Color.compound.bgSubtleSecondary : Color.compound.bgCanvasDefault)
            .contentShape(Rectangle())
            .animation(isSelected ? .none : .easeOut(duration: 0.1).disabledDuringTests(), value: isSelected)
    }
}

private extension View {
    func lastMessageFormatting() -> some View {
        font(.compound.bodyMD)
            .foregroundColor(.compound.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

struct HomeScreenRoomCell_Previews: PreviewProvider, TestablePreview {
    static let summaryProviderGeneric = MockRoomSummaryProvider(state: .loaded(.mockRooms))
    static let viewModelGeneric = {
        let userSession = MockUserSession(clientProxy: MockClientProxy(userID: "John Doe", roomSummaryProvider: summaryProviderGeneric),
                                          mediaProvider: MockMediaProvider(),
                                          voiceMessageMediaManager: VoiceMessageMediaManagerMock())

        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: ServiceLocator.shared.settings,
                                   userIndicatorController: ServiceLocator.shared.userIndicatorController)
    }()
    
    static let summaryProviderForNotificationsState = MockRoomSummaryProvider(state: .loaded(.mockRoomsWithNotificationsState))
    static let viewModelForNotificationsState = {
        let userSession = MockUserSession(clientProxy: MockClientProxy(userID: "John Doe", roomSummaryProvider: summaryProviderForNotificationsState),
                                          mediaProvider: MockMediaProvider(),
                                          voiceMessageMediaManager: VoiceMessageMediaManagerMock())

        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: ServiceLocator.shared.settings,
                                   userIndicatorController: ServiceLocator.shared.userIndicatorController)
    }()
    
    static func mockRoom(summary: RoomSummary) -> HomeScreenRoom? {
        switch summary {
        case .empty:
            return nil
        case .invalidated(let details), .filled(let details):
            return HomeScreenRoom(id: UUID().uuidString,
                                  roomId: details.id,
                                  name: details.name,
                                  hasUnreads: details.unreadMessagesCount > 0, hasMentions: details.unreadMentionsCount > 0,
                                  hasOngoingCall: details.hasOngoingCall,
                                  timestamp: Date(timeIntervalSinceReferenceDate: 0).formattedMinimal(),
                                  lastMessage: details.lastMessage,
                                  notificationMode: details.notificationMode)
        }
    }
    
    static var previews: some View {
        let genericRooms: [HomeScreenRoom] = summaryProviderGeneric.roomListPublisher.value.compactMap(mockRoom)
        
        let notificationsStateRooms: [HomeScreenRoom] = summaryProviderForNotificationsState.roomListPublisher.value.compactMap(mockRoom)

        VStack(spacing: 0) {
            ForEach(genericRooms) { room in
                HomeScreenRoomCell(room: room, context: viewModelGeneric.context, isSelected: false)
            }
            
            HomeScreenRoomCell(room: .placeholder(), context: viewModelGeneric.context, isSelected: false)
                .redacted(reason: .placeholder)
        }
        .previewDisplayName("Generic")
        
        VStack(spacing: 0) {
            ForEach(notificationsStateRooms) { room in
                HomeScreenRoomCell(room: room, context: viewModelForNotificationsState.context, isSelected: false)
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Notifications State")
    }
}
