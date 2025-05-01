import SwiftUI

struct FriendID: Identifiable {
    var id: String { friendID }
    let friendID: String
}

struct FriendColorListView: View {
    var followingIDs: [String]
    @Binding var friendColorOverrides: [String: Color]
    
    @State private var selectedFriend: FriendID? = nil
    @State private var tempColor: Color = .blue
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(followingIDs, id: \.self) { friendID in
                Button(action: {
                    selectedFriend = FriendID(friendID: friendID)
                    tempColor = friendColorOverrides[friendID] ?? .blue
                }) {
                    HStack {
                        Circle()
                            .fill(friendColorOverrides[friendID] ?? .gray)
                            .frame(width: 20, height: 20)
                        Text(friendID)
                    }
                }
            }
            .navigationTitle("Edit Friend Colors")
            .sheet(item: $selectedFriend, onDismiss: {
                if let id = selectedFriend?.friendID {
                    friendColorOverrides[id] = tempColor
                }
            }) { friend in
                EditFriendColorView(friendID: friend.friendID, customColor: $tempColor)
            }
        }
    }
}

