import SwiftUI

struct RemoveFriendView: View {
    @Binding var followingIDsString: String
    @Environment(\.dismiss) private var dismiss

    private var followingIDs: [String] {
        followingIDsString.split(separator: ",").map { String($0) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(followingIDs, id: \.self) { id in
                    HStack {
                        Text(id)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            removeFriend(id: id)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .navigationTitle("Remove Friends")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func removeFriend(id: String) {
        var currentIDs = followingIDsString.split(separator: ",").map { String($0) }
        currentIDs.removeAll { $0 == id }
        followingIDsString = currentIDs.joined(separator: ",")
    }
}
