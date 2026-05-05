import MapKit
import SwiftUI

struct CODGovernoratePickerView: View {
    @Binding var selectedGovernorate: EgyptGovernorate?
    @Binding var isPresented: Bool

    @State private var pendingGovernorate: EgyptGovernorate?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 26.8206, longitude: 30.8025),
            span: MKCoordinateSpan(latitudeDelta: 11.5, longitudeDelta: 10.5)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $position) {
                    ForEach(EgyptGovernorate.allCases) { governorate in
                        Annotation(
                            governorate.rawValue,
                            coordinate: CLLocationCoordinate2D(
                                latitude: governorate.coordinate.latitude,
                                longitude: governorate.coordinate.longitude
                            ),
                            anchor: .bottom
                        ) {
                            Button {
                                select(governorate)
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(
                                        pendingGovernorate == governorate ? BrandPalette.gold : BrandPalette.sand
                                    )
                                    .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("Select Governorate")
                        .font(BrandFont.mobileTitle3())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(pendingGovernorate?.rawValue ?? "Tap a governorate marker to continue.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                }
                .padding(BrandSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                        .fill(BrandPalette.overlay.opacity(0.9))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandRadius.card, style: .continuous)
                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                )
                .padding(.horizontal, BrandSpacing.md)
                .padding(.top, BrandSpacing.md)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: BrandSpacing.sm) {
                    if let pendingGovernorate {
                        HStack(spacing: BrandSpacing.sm) {
                            Image(systemName: pendingGovernorate.isCODEligible ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(pendingGovernorate.isCODEligible ? BrandPalette.gold : .red)

                            Text(pendingGovernorate.isCODEligible ? "Cash on delivery is available here." : "Cash on delivery is not available here.")
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textPrimary)

                            Spacer(minLength: 0)
                        }
                        .padding(BrandSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
                    }

                    HStack(spacing: BrandSpacing.sm) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))

                        Button("Confirm") {
                            selectedGovernorate = pendingGovernorate
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                        .disabled(pendingGovernorate == nil)
                    }
                }
                .padding(.horizontal, BrandSpacing.md)
                .padding(.top, BrandSpacing.sm)
                .padding(.bottom, BrandSpacing.sm)
                .background(
                    BrandPalette.background.opacity(0.94)
                        .background(.ultraThinMaterial)
                )
            }
            .presentationCompactAdaptation(.fullScreenCover)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                pendingGovernorate = selectedGovernorate
                if let selectedGovernorate {
                    position = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: selectedGovernorate.coordinate.latitude,
                                longitude: selectedGovernorate.coordinate.longitude
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
                        )
                    )
                }
            }
        }
    }

    private func select(_ governorate: EgyptGovernorate) {
        pendingGovernorate = governorate
        withAnimation(.easeInOut(duration: 0.25)) {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: governorate.coordinate.latitude,
                        longitude: governorate.coordinate.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
                )
            )
        }
    }
}

#Preview {
    CODGovernoratePickerView(
        selectedGovernorate: .constant(.cairo),
        isPresented: .constant(true)
    )
}
