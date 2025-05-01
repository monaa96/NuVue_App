import SwiftUI

struct FriendID: Identifiable {
    var id: String { friendID }
    let friendID: String
}

struct FriendColorListView: View {
    // --- Inputs ---
    var followingIDs: [String]
    @Binding var friendColorOverrides: [String: Color]
    @ObservedObject var firestoreManager: FirestoreManager

    // --- State ---
    @State private var selectedFriendItem: FriendID? = nil
    @State private var editingFriendID: String? = nil
    @State private var tempColor: Color = .gray

    @Environment(\.dismiss) private var dismissParentSheet

    // --- Computed Properties ---
    private var friendsDict: [String: Friend] {
        // Ensure this is computed correctly based on firestoreManager.friends
        // Add a print here if you suspect friends data issues
         // let _ = print("FriendColorListView: Computing friendsDict. Firestore friends count: \(firestoreManager.friends.count)")
        return Dictionary(uniqueKeysWithValues: firestoreManager.friends.compactMap { friend in
            guard let id = friend.id else { return nil }
            return (id, friend)
        })
    }

    // Helper to get the display color (override > default > fallback)
    private func displayColor(for friendID: String) -> Color {
        if let overrideColor = friendColorOverrides[friendID] {
             // print("DisplayColor for \(friendID): Using override \(overrideColor)")
            return overrideColor
        }
        if let friend = friendsDict[friendID] {
             // print("DisplayColor for \(friendID): Using default from Friend struct")
            return Color(red: friend.r, green: friend.g, blue: friend.b)
        }
         // print("DisplayColor for \(friendID): Using fallback gray")
        return .gray // Fallback
    }

    var body: some View {
         // Add print to check when body renders and the state
         // let _ = print("FriendColorListView Body Rendered. Following IDs: \(followingIDs.count), Overrides: \(friendColorOverrides.count)")

        NavigationView {
            List {
                if followingIDs.isEmpty {
                    Text("You are not following anyone.")
                        .foregroundColor(.secondary)
                        .padding() // Add padding for better spacing
                } else {
                    // --- Iterate over following IDs ---
                    ForEach(followingIDs, id: \.self) { friendID in
                        // Use a Button whose action sets state
                        Button {
                            editingFriendID = friendID
                            tempColor = displayColor(for: friendID) // Initialize with current display color
                            selectedFriendItem = FriendID(friendID: friendID)
                            print("FriendColorListView: Tapped button for \(friendID)")
                        } label: {
                             // --- Button Label Content ---
                             // Use an HStack directly as the label
                             HStack {
                                 Circle()
                                     .fill(displayColor(for: friendID)) // Use helper
                                     .frame(width: 20, height: 20)
                                     .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)) // Subtle border

                                 // Attempt to get name, fallback to ID
                                 // Add print here if name lookup fails
                                 let displayName = friendsDict[friendID]?.name ?? friendID
                                 // let _ = print("Friend ID \(friendID), Display Name: \(displayName)")

                                 Text(displayName)
                                     .foregroundColor(.primary) // Explicitly set text color
                                     .lineLimit(1) // Prevent long names wrapping weirdly

                                 Spacer() // Push content to the left
                             }
                             // Add padding within the HStack if needed
                             // .padding(.vertical, 4)
                        }
                        // Ensure the button itself doesn't have a style that hides content
                        // .buttonStyle(.plain) // Try plain style if default is causing issues
                    }
                }
            }
            // Apply list style if desired
            // .listStyle(.plain)
            .navigationTitle("Edit Friend Colors")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismissParentSheet() }
                }
            }
            .sheet(item: $selectedFriendItem) { /* ... onDismiss logic as before ... */
                 guard let idToUpdate = editingFriendID else { return }
                 if friendColorOverrides[idToUpdate] != tempColor {
                      friendColorOverrides[idToUpdate] = tempColor
                 }
                 editingFriendID = nil
            } content: { friendItem in
                 EditFriendColorView(friendID: friendItem.friendID, customColor: $tempColor)
            }
            // Add an onAppear for debugging data state when view first appears
            // .onAppear {
            //     print("FriendColorListView Appeared. Following: \(followingIDs)")
            //     print("Overrides: \(friendColorOverrides)")
            //     print("Firestore Friends (used for names/defaults): \(firestoreManager.friends.map { $0.name })")
            // }
        }
    }
}
