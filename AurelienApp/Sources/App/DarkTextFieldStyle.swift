import SwiftUI

public struct DarkTextFieldStyle: TextFieldStyle {
    public init() {}
    public func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .font(BrandFont.mobileBody())
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandPalette.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BrandPalette.hairline, lineWidth: 1)
                    )
            )
            .foregroundStyle(BrandPalette.textPrimary)
    }
}
