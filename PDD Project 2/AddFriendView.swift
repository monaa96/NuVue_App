import SwiftUI

struct AddFriendView: View {
    // --- Inputs & Managers ---
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var followingIDsString: String // Comma-separated IDs you follow

    // --- State ---
    @State private var searchUsername: String = ""
    @Environment(\.dismiss) private var dismiss

    // --- Current User ---
    @AppStorage("username") private var currentUsername: String = ""

    // --- Computed Properties ---

    // ✅ Helper to get the set of IDs currently being followed
    private var followingIDsSet: Set<String> {
        Set(followingIDsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    // ✅ Filter the 'friends' list (all users) to exclude self AND already followed users
    private var usersToDiscover: [Friend] { // Renamed for clarity
        let followedSet = self.followingIDsSet // Capture the set once

        return firestoreManager.friends.filter { user in
            // Ensure user has a valid ID
            guard let userID = user.id, !userID.isEmpty else {
                return false // Cannot add users without IDs
            }

            // Trim whitespace AND compare lowercase for robustness
            let userNameTrimmedLower = user.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let currentUsernameTrimmedLower = currentUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Ensure user name is not empty after trimming
            guard !userNameTrimmedLower.isEmpty else { return false }

            // --- Conditions ---
            // 1. Is it the current user?
            let isCurrentUser = userNameTrimmedLower == currentUsernameTrimmedLower
            // 2. Is this user already being followed?
            let isAlreadyFollowed = followedSet.contains(userID)

            // --- Filtering Logic ---
            // Show the user IF they are NOT the current user AND they are NOT already followed
            let shouldShow = !isCurrentUser && !isAlreadyFollowed

            // Optional Debug Print:
            // print("Filtering User: \(user.name) (\(userID)) - isCurrentUser: \(isCurrentUser), isAlreadyFollowed: \(isAlreadyFollowed) -> Show: \(shouldShow)")

            return shouldShow
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                TextField("Search username to add", text: $searchUsername) // Slightly updated placeholder
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button("Add Friend") { addFriend() }
                    .buttonStyle(ActionButtonStyle(backgroundColor: searchUsername.isEmpty ? .gray.opacity(0.5) : .blue))
                    .padding(.horizontal)
                    .disabled(searchUsername.isEmpty)

                Divider().padding(.horizontal)

                // ✅ Renamed Section Title
                Text("Discover Users")
                    .font(.headline)
                    .padding(.top, 5)

                // ✅ Use the refined filtered list 'usersToDiscover'
                if firestoreManager.friends.isEmpty { // Still check if initial load is happening
                     ProgressView("Loading users...")
                         .padding()
                // ✅ Check the filtered list for the empty state message
                 } else if usersToDiscover.isEmpty {
                     Text("No new users to discover.") // Updated empty message
                         .foregroundColor(.secondary)
                         .padding()
                 } else {
                    // List the filtered users
                    List(usersToDiscover) { user in // Use the new computed property
                        Button(action: {
                            searchUsername = user.name // Populate search field on tap
                        }) {
                            HStack { // Add icon for clarity (optional)
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(.secondary)
                                Text(user.name)
                            }
                             .foregroundColor(.primary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                print("AddFriendView - Current Username: '\(currentUsername)'")
                print("AddFriendView - Currently Following IDs: \(followingIDsSet)") // Log followed set
                // Ensure listener is active
                // firestoreManager.startListening()
            }
        }
    }

    // addFriend Function remains the same - it already handles the "already followed" check correctly
    private func addFriend() {
        let trimmedUsername = searchUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentUsernameTrimmed = currentUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else { return }

        guard trimmedUsername.lowercased() != currentUsernameTrimmed.lowercased() else {
            print("⚠️ Cannot add yourself as a friend.")
            // Add alert here?
            return
        }

        print("Attempting to fetch user: \(trimmedUsername)")
        firestoreManager.fetchUser(username: trimmedUsername) { friend in
            if let friend = friend {
                DispatchQueue.main.async {
                    var currentIDsSet = self.followingIDsSet // Use computed property

                    if let friendID = friend.id, !friendID.isEmpty {
                        if currentIDsSet.contains(friendID) {
                             print("⚠️ Friend '\(friend.name)' (\(friendID)) already added.")
                             // Add alert here?
                        } else {
                            currentIDsSet.insert(friendID)
                            // Update the binding string
                            followingIDsString = currentIDsSet.sorted().joined(separator: ",")
                            print("✅ Friend '\(friend.name)' (\(friendID)) added successfully! New string: \(followingIDsString)")
                             dismiss()
                        }
                    } else {
                        print("❌ Fetched friend '\(friend.name)' is missing a valid ID.")
                    }
                }
            } else {
                print("❌ Friend '\(trimmedUsername)' not found")
            }
        }
    }
}
