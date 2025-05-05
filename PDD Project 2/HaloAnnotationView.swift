import SwiftUI

struct HaloAnnotationView: View {
    // --- Properties ---
    let color: Color
    let dotSize: CGFloat
    let haloSizeMultiplier: CGFloat
    let borderLineWidth: CGFloat
    let blurRadius: CGFloat
    let gradientStartPoint: CGFloat
    let gradientFadeStartPoint: CGFloat

    // --- Computed ---
    private var haloSize: CGFloat { dotSize * haloSizeMultiplier }

    // --- ✅ Explicit Initializer with Defaults ---
    init(color: Color,
         dotSize: CGFloat = 20, // Default value
         haloSizeMultiplier: CGFloat = 2.5, // Default value
         borderLineWidth: CGFloat = 1.5, // Default value
         blurRadius: CGFloat = 8, // Default value
         gradientStartPoint: CGFloat = 0.2, // Default value
         gradientFadeStartPoint: CGFloat = 0.7)
    { // Default value
        // Assign values
        self.color = color
        self.dotSize = dotSize
        self.haloSizeMultiplier = haloSizeMultiplier
        self.borderLineWidth = borderLineWidth
        self.blurRadius = blurRadius
        self.gradientStartPoint = gradientStartPoint
        self.gradientFadeStartPoint = gradientFadeStartPoint
    }

    // --- Body ---
    var body: some View {
        ZStack {
            // 1. The Outer Halo (Gradient + Blur)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.6), location: 0.0),
                            .init(color: color.opacity(1), location: gradientStartPoint),
                            .init(color: color.opacity(0.85), location: gradientFadeStartPoint),
                            .init(color: color.opacity(0), location: 1.0),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: haloSize / 2
                    )
                )
                .frame(width: haloSize, height: haloSize)
                .blur(radius: blurRadius)

            // 2. The Central Dot + Border
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: borderLineWidth)
                )
            // Optional Shadow
            // .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
    }
}

// --- Preview (Should now work correctly) ---
#Preview {
    ZStack {
        Color.gray // Background for preview
        VStack(spacing: 30) {
            // Uses defaults for size/blur etc.
            HaloAnnotationView(color: .blue)

            // Uses specific overridden values
            HaloAnnotationView(color: .pink, dotSize: 25, haloSizeMultiplier: 3.0, blurRadius: 10)

            // Uses defaults again
            HaloAnnotationView(color: .green)
        }
        .padding() // Add padding to see edges better
    }
}
