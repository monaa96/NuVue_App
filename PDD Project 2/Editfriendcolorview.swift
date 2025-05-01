import SwiftUI

struct EditFriendColorView: View {
    var friendID: String
    @Binding var customColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Customize Color for \(friendID)")
                .font(.headline)

            ColorPicker("Pick a color:", selection: $customColor)
                .padding()

            Button("Save") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding()
    }
}

