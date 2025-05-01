import SwiftUI

struct AddFriendView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var followingIDsString: String

    @State private var searchUsername: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Search friend's username", text: $searchUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Add Friend") {
                    addFriend()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(searchUsername.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(searchUsername.isEmpty)

                Divider()
                    .padding()

                Text("Existing Users")
                    .font(.headline)

                List(firestoreManager.friends) { friend in
                    Button(action: {
                        searchUsername = friend.name
                    }) {
                        Text(friend.name)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .padding()
            .onAppear {
                firestoreManager.startListening()
            }
        }
    }

    private func addFriend() {
        firestoreManager.fetchUser(username: searchUsername) { friend in
            if let friend = friend {
                DispatchQueue.main.async {
                    var currentIDs = followingIDsString.split(separator: ",").map { String($0) }
                    if let friendID = friend.id, !currentIDs.contains(friendID) {
                        currentIDs.append(friendID)
                        followingIDsString = currentIDs.joined(separator: ",")
                        print("✅ Friend added successfully!")
                    } else {
                        print("⚠️ Friend already added.")
                    }
                    dismiss()
                }
            } else {
                print("❌ Friend not found")
                dismiss()
            }
        }
    }

}
