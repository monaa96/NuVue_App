import SwiftUI

struct EditFriendColorView: View {
    var friendID: String
    @Binding var customColor: Color // Binds to tempColor in FriendColorListView
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Use NavigationView for consistent Title/Toolbar within the sheet
        NavigationView {
            VStack(spacing: 30) {
                Circle()
                    .fill(customColor)
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    .padding(.top)

                ColorPicker("Select Color:", selection: $customColor, supportsOpacity: false)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle(friendID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss() // Close sheet without saving change
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // ✅ Ensure Save button ONLY calls dismiss()
                    Button("Save") {
                        // The actual update happens in FriendColorListView's .sheet onDismiss
                        // This button just closes the sheet, which triggers that onDismiss.
                        dismiss()
                    }
                }
            }
        }
    }
}
