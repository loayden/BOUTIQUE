import MapKit
import SwiftUI

struct CheckoutView: View {
    @Environment(AurelienStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var step: CheckoutStep = .shipping
    @State private var selectedAddressID: String?
    @State private var selectedDeliveryMethodID = CheckoutDeliveryMethod.standard.id
    @State private var selectedPaymentOption: CheckoutPaymentOption = .cashOnDelivery
    @State private var vodafoneCashNumber = ""
    @State private var promoCode = ""
    @State private var appliedPromoCode: String?
    @State private var promoValidation: PromoValidationResult?
    @State private var promoMessage: String?
    @State private var isApplyingPromo = false
    @State private var isProcessing = false
    @State private var placedOrder: Order?
    @State private var showAddressSheet = false
    @State private var showCODPicker = false
    @State private var selectedDeliveryGovernorate: EgyptGovernorate?
    @State private var codFee = 20.0
    @State private var codEligibilityOverride: Bool?
    @State private var placementErrorMessage: String?
    @State private var checkoutMessage: String?

    private var selectedAddress: SavedAddress? {
        store.savedAddresses.first(where: { $0.id == selectedAddressID }) ?? store.primaryAddress ?? store.savedAddresses.first
    }

    private var selectedDeliveryMethod: CheckoutDeliveryMethod {
        CheckoutDeliveryMethod.allCases.first(where: { $0.id == selectedDeliveryMethodID }) ?? .standard
    }

    private var shippingCost: Double {
        guard selectedAddress != nil else { return 0 }
        return selectedDeliveryMethod.price
    }

    private var promoDiscount: Double {
        guard promoValidation?.isValid == true else { return 0 }
        return promoValidation?.discount ?? 0
    }

    private var total: Double {
        max(store.subtotal + shippingCost + activeCODFee - promoDiscount, 0)
    }

    private var isCODSelected: Bool {
        selectedPaymentOption == .cashOnDelivery
    }

    private var isCODEligible: Bool {
        guard let gov = selectedDeliveryGovernorate else { return false }
        return codEligibilityOverride ?? gov.isCODEligible
    }

    private var activeCODFee: Double {
        isCODSelected && isCODEligible ? codFee : 0
    }

    private var canUseCashOnDelivery: Bool {
        isCODEligible
    }

    private var isPaymentStepValid: Bool {
        switch selectedPaymentOption {
        case .cashOnDelivery:
            return isCODEligible
        case .vodafoneCash:
            return vodafoneCashNumber.isValidVodafoneCashNumber
        }
    }

    private var resolvedPaymentMethod: PaymentMethod? {
        switch selectedPaymentOption {
        case .cashOnDelivery:
            return PaymentMethod(type: "cod", displayName: "Cash on Delivery")
        case .vodafoneCash:
            let digits = vodafoneCashNumber.phoneDigits
            let suffix = digits.suffix(4)
            return PaymentMethod(type: "vodafone_cash", displayName: "Vodafone Cash •••• \(suffix)")
        }
    }

    var body: some View {
        bodyContent
        .background(AmbientBackdrop())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if showsCheckoutChrome {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == .shipping ? "Bag" : "Back") {
                        goBack()
                    }
                    .foregroundStyle(BrandPalette.gold)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showsCheckoutChrome {
                checkoutFooter
            }
        }
        .sheet(isPresented: $showAddressSheet) {
            CheckoutAddressSheet(
                currentUser: store.currentUser,
                defaultRecipient: store.currentUser?.name ?? store.profile.name
            ) { draft in
                let address = store.addAddress(
                    label: draft.label,
                    recipient: draft.recipient,
                    line1: draft.line1,
                    apartment: draft.apartment,
                    city: draft.city.rawValue,
                    phone: draft.normalizedPhone,
                    isPrimary: draft.isPrimary
                )
                selectedAddressID = address.id
                selectedDeliveryGovernorate = address.city
                checkoutMessage = nil
                syncDeliveryAndPaymentRestrictions()
            }
        }
        .sheet(isPresented: $showCODPicker) {
            CODGovernoratePickerView(
                selectedGovernorate: $selectedDeliveryGovernorate,
                isPresented: $showCODPicker
            )
        }
        .task {
            initializeSelectionsIfNeeded()
            await refreshCODEligibility()
        }
        .onChange(of: selectedAddressID) { _, _ in
            selectedDeliveryGovernorate = selectedAddress?.city
            syncDeliveryAndPaymentRestrictions()
            Task { await refreshCODEligibility() }
        }
        .onChange(of: selectedDeliveryGovernorate) { _, _ in
            syncDeliveryAndPaymentRestrictions()
            Task { await refreshCODEligibility() }
        }
        .onChange(of: promoCode) { _, newValue in
            if appliedPromoCode != newValue {
                promoValidation = nil
            }
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let placedOrder {
            OrderConfirmationView(order: placedOrder)
        } else {
            checkoutScrollContent
        }
    }

    private var checkoutScrollContent: some View {
        PhoneScrollScreen { viewport in
            LazyVStack(alignment: .leading, spacing: BrandSpacing.lg) {
                CheckoutProgressHeader(currentStep: step)
                checkoutMessagePanel
                placementErrorPanel
                content(for: step)
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.vertical, viewport.horizontalPadding)
            .padding(.bottom, max(viewport.bottomPadding, 140))
        }
    }

    @ViewBuilder
    private var checkoutMessagePanel: some View {
        if let checkoutMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(BrandPalette.gold)

                Text(checkoutMessage)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
        }
    }

    @ViewBuilder
    private var placementErrorPanel: some View {
        if let placementErrorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text("Unable to place order")
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(placementErrorMessage)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)

                Button("Dismiss") {
                    self.placementErrorMessage = nil
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
                .frame(minHeight: 44)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
        }
    }

    private var navigationTitle: String {
        showsCheckoutChrome ? step.navigationTitle : "Order Confirmed"
    }

    private var showsCheckoutChrome: Bool {
        placedOrder == nil
    }

    @ViewBuilder
    private func content(for step: CheckoutStep) -> some View {
        switch step {
        case .shipping:
            shippingStepContent
        case .payment:
            paymentStepContent
        case .review:
            reviewStepContent
        case .bag:
            EmptyView()
        }
    }

    private var shippingStepContent: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.lg) {
            BrandSectionHeader(
                eyebrow: "Shipping",
                title: "Choose your address and delivery method.",
                copy: "Shipping and same-day availability are shown the moment you select a governorate."
            )

            CheckoutSectionCard(title: "Saved Addresses", subtitle: "Select a delivery address or add a new one.") {
                VStack(spacing: BrandSpacing.sm) {
                    if store.savedAddresses.isEmpty {
                        EmptyStatePanel(
                            title: "No saved addresses yet",
                            copy: "Add a delivery address to continue to payment.",
                            buttonTitle: "Add Delivery Address"
                        ) {
                            showAddressSheet = true
                        }
                    } else {
                        ForEach(store.savedAddresses) { address in
                            CheckoutSelectableCard(
                                isSelected: selectedAddressID == address.id,
                                title: address.label,
                                subtitle: "\(address.recipient) • \(address.city.rawValue)",
                                detail: address.summary
                            ) {
                                selectedAddressID = address.id
                                checkoutMessage = nil
                            }
                        }
                    }

                    Button("Add New Address") {
                        showAddressSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(BrandCapsuleButtonStyle(tone: .chrome))
                }
            }

            CheckoutSectionCard(title: "Governorate", subtitle: "Select for COD eligibility") {
                Button {
                    showCODPicker = true
                } label: {
                    HStack(spacing: BrandSpacing.sm) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(BrandPalette.gold)

                        VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                            Text(selectedDeliveryGovernorate?.rawValue ?? "Select governorate")
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.textPrimary)

                            Text(isCODEligible ? "✓ COD available" : "✗ COD not available")
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(isCODEligible ? BrandPalette.gold : .red)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandPalette.textMuted)
                    }
                    .padding(BrandSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                            .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            CheckoutSectionCard(title: "Delivery Method", subtitle: deliverySubtitle) {
                VStack(spacing: BrandSpacing.sm) {
                    ForEach(CheckoutDeliveryMethod.allCases) { method in
                        let isAvailable = method.isAvailable(in: selectedAddress?.city.rawValue)
                        CheckoutDeliveryMethodCard(
                            method: method,
                            isSelected: selectedDeliveryMethodID == method.id,
                            isAvailable: isAvailable
                        ) {
                            guard isAvailable else { return }
                            selectedDeliveryMethodID = method.id
                        }
                    }
                }
            }

            CheckoutSectionCard(title: "Price Transparency", subtitle: "No surprise fees at the final step.") {
                VStack(spacing: BrandSpacing.sm) {
                    CheckoutSummaryRow(title: "Bag Subtotal", value: BrandFormatter.price(store.subtotal))
                    CheckoutSummaryRow(
                        title: "Shipping",
                        value: selectedAddress == nil ? "Select address" : BrandFormatter.price(shippingCost),
                        valueAccent: selectedAddress == nil ? BrandPalette.textSecondary : BrandPalette.textPrimary
                    )

                    if selectedDeliveryMethod == .sameDay {
                        CheckoutSummaryRow(
                            title: "Same Day Restriction",
                            value: "Cairo / Giza only",
                            valueAccent: BrandPalette.textSecondary
                        )
                    }

                    DividerGlow()
                    CheckoutSummaryRow(title: "Running Total", value: BrandFormatter.price(store.subtotal + shippingCost + activeCODFee), emphasize: true)
                }
            }
        }
    }

    private var paymentStepContent: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.lg) {
            BrandSectionHeader(
                eyebrow: "Payment",
                title: "Choose how you want to pay.",
                copy: "Only payment methods that can create a real order in this build are shown. Card and Apple Pay options are hidden until a payment provider is connected."
            )

            CheckoutSectionCard(title: "Payment Options", subtitle: paymentSubtitle) {
                VStack(alignment: .leading, spacing: BrandSpacing.md) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CheckoutPaymentMethodChip(
                                title: "Cash on Delivery",
                                icon: "banknote.fill",
                                isSelected: selectedPaymentOption == .cashOnDelivery
                            ) {
                                selectedPaymentOption = .cashOnDelivery
                            }

                            CheckoutPaymentMethodChip(
                                title: "Vodafone Cash",
                                icon: "iphone.gen3.radiowaves.left.and.right",
                                isSelected: selectedPaymentOption == .vodafoneCash
                            ) {
                                selectedPaymentOption = .vodafoneCash
                            }
                        }
                    }

                    if isCODSelected {
                        VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                                Image(systemName: "banknote.fill")
                                    .foregroundStyle(BrandPalette.gold)

                                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                                    Text("Pay on Delivery")
                                        .font(BrandFont.mobileBody())
                                        .foregroundStyle(BrandPalette.textPrimary)

                                    Text("Cash is collected when the driver arrives with your order.")
                                        .font(BrandFont.mobileCaption())
                                        .foregroundStyle(BrandPalette.textSecondary)

                                    Text("+ \(BrandFormatter.price(codFee)) COD Fee")
                                        .font(BrandFont.mobileCaption())
                                        .foregroundStyle(BrandPalette.gold)
                                }

                                Spacer(minLength: 0)
                            }

                            Button {
                                showCODPicker = true
                            } label: {
                                HStack(spacing: BrandSpacing.sm) {
                                    VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                                        Text("Delivery Governorate")
                                            .font(BrandFont.mobileCaption())
                                            .foregroundStyle(BrandPalette.textSecondary)

                                        Text(selectedDeliveryGovernorate?.rawValue ?? "Choose on map")
                                            .font(BrandFont.mobileBody())
                                            .foregroundStyle(BrandPalette.textPrimary)
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "location.fill")
                                        .foregroundStyle(BrandPalette.gold)
                                }
                                .padding(BrandSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(BrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                                        .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)

                            if isCODSelected && isCODEligible {
                                HStack(spacing: BrandSpacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BrandPalette.gold)
                                    Text("✓ available")
                                        .font(BrandFont.mobileBody())
                                        .foregroundStyle(BrandPalette.gold)
                                    Spacer(minLength: 0)
                                }

                                CheckoutSummaryRow(title: "Delivery Window", value: "1–3 business days")
                                CheckoutSummaryRow(title: "Arrival Update", value: "Driver will call before arrival")
                            }

                            if isCODSelected && !isCODEligible {
                                HStack(spacing: BrandSpacing.sm) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text("✗ not available")
                                        .font(BrandFont.mobileBody())
                                        .foregroundStyle(.red)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(BrandSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
                    }

                    if selectedPaymentOption == .vodafoneCash {
                        VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                            CheckoutSelectableCard(
                                isSelected: true,
                                title: "Vodafone Cash",
                                subtitle: "Pay from an 01X mobile wallet number",
                                detail: "01XXXXXXXXX"
                            ) {}
                            .disabled(true)

                            BrandField(
                                title: "Vodafone Cash Number",
                                text: $vodafoneCashNumber,
                                keyboardType: .phonePad,
                                textContentType: .telephoneNumber,
                                submitLabel: .done,
                                autocapitalization: .never
                            )

                            if !vodafoneCashNumber.isEmpty && !vodafoneCashNumber.isValidVodafoneCashNumber {
                                Text("Use an Egyptian mobile number in the 01X format.")
                                    .font(BrandFont.mobileCaption())
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            CheckoutSectionCard(title: "Promo Code", subtitle: "Validate discounts before the review step.") {
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    HStack(spacing: BrandSpacing.sm) {
                        BrandField(
                            title: "Promo Code",
                            text: $promoCode,
                            keyboardType: .asciiCapable,
                            submitLabel: .done,
                            autocapitalization: .characters
                        )

                        Button {
                            Task { await applyPromo() }
                        } label: {
                            if isApplyingPromo {
                                ProgressView()
                                    .tint(BrandPalette.textPrimary)
                            } else {
                                Text("Apply")
                            }
                        }
                        .frame(width: 96)
                        .buttonStyle(BrandCapsuleButtonStyle(tone: .gold, horizontalPadding: BrandSpacing.md))
                        .disabled(promoCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isApplyingPromo)
                    }

                    if let promoValidation, promoValidation.isValid {
                        Text(promoValidation.message ?? "Discount applied: \(BrandFormatter.discount(promoValidation.discount))")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.gold)
                    } else if let promoMessage {
                        Text(promoMessage)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(.red)
                    }

                    DividerGlow()
                    CheckoutSummaryRow(title: "Current Total", value: BrandFormatter.price(total), emphasize: true)
                }
            }
        }
    }

    private var reviewStepContent: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.lg) {
            BrandSectionHeader(
                eyebrow: "Review",
                title: "Confirm every detail before you place the order.",
                copy: "Bag, shipping, payment, promo, and fees stay visible with direct edit links."
            )

            CheckoutSectionCard(title: "Bag", subtitle: "\(store.bagCount) items ready to place") {
                VStack(spacing: BrandSpacing.sm) {
                    HStack {
                        Button("Edit Bag") {
                            dismiss()
                        }
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.gold)

                        Spacer()

                        Text(BrandFormatter.price(store.subtotal))
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)
                    }

                    ForEach(store.bag) { line in
                        HStack(spacing: BrandSpacing.sm) {
                            MediaImage(name: line.product.heroImageName)
                                .scaledToFill()
                                .frame(width: 56, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.product.name)
                                    .font(BrandFont.mobileBody())
                                    .foregroundStyle(BrandPalette.textPrimary)

                                Text("\(line.quantity)x • \(line.size) • \(line.color.name)")
                                    .font(BrandFont.mobileCaption())
                                    .foregroundStyle(BrandPalette.textSecondary)
                            }

                            Spacer()

                            Text(BrandFormatter.price(line.subtotal))
                                .font(BrandFont.mobileBody())
                                .foregroundStyle(BrandPalette.gold)
                        }
                    }

                    if let issue = store.firstBagAvailabilityIssue {
                        Text(issue)
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            CheckoutSectionCard(title: "Shipping", subtitle: selectedDeliveryMethod.title) {
                VStack(spacing: BrandSpacing.sm) {
                    HStack {
                        Button("Edit Shipping") {
                            step = .shipping
                        }
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.gold)

                        Spacer()

                        Text(BrandFormatter.price(shippingCost))
                            .font(BrandFont.mobileTitle3())
                            .foregroundStyle(BrandPalette.textPrimary)
                    }

                    if let selectedAddress {
                        CheckoutSummaryRow(
                            title: selectedAddress.label,
                            value: (selectedDeliveryGovernorate ?? selectedAddress.city).rawValue,
                            valueAccent: BrandPalette.textPrimary
                        )
                        CheckoutSummaryRow(title: "Address", value: selectedAddress.summary, valueAccent: BrandPalette.textSecondary)
                        CheckoutSummaryRow(title: "Delivery", value: "\(selectedDeliveryMethod.timeline) • \(BrandFormatter.price(selectedDeliveryMethod.price))")
                    }
                }
            }

            CheckoutSectionCard(title: "Payment", subtitle: resolvedPaymentMethod?.displayName ?? "Choose payment") {
                VStack(spacing: BrandSpacing.sm) {
                    HStack {
                        Button("Edit Payment") {
                            step = .payment
                        }
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.gold)

                        Spacer()
                    }

                    CheckoutSummaryRow(title: "Method", value: resolvedPaymentMethod?.displayName ?? "Pending", valueAccent: BrandPalette.textPrimary)

                    if activeCODFee > 0 {
                        CheckoutSummaryRow(title: "Cash on Delivery Fee", value: BrandFormatter.price(activeCODFee))
                        CheckoutSummaryRow(title: "COD Confirmation", value: "Cash is collected when the driver arrives.", valueAccent: BrandPalette.textSecondary)
                    }

                    if promoDiscount > 0 {
                        CheckoutSummaryRow(title: "Promo Discount", value: BrandFormatter.discount(promoDiscount), valueAccent: BrandPalette.gold)
                    }
                }
            }

            CheckoutSectionCard(title: "Total", subtitle: "Final charge before placement") {
                VStack(spacing: BrandSpacing.sm) {
                    CheckoutSummaryRow(title: "Subtotal", value: BrandFormatter.price(store.subtotal))
                    CheckoutSummaryRow(title: "Shipping", value: BrandFormatter.price(shippingCost))

                    if activeCODFee > 0 {
                        CheckoutSummaryRow(title: "COD Fee", value: BrandFormatter.price(activeCODFee))
                    }

                    if promoDiscount > 0 {
                        CheckoutSummaryRow(title: "Promo Discount", value: BrandFormatter.discount(promoDiscount), valueAccent: BrandPalette.gold)
                    }

                    DividerGlow()
                    CheckoutSummaryRow(title: "Place Order", value: BrandFormatter.price(total), emphasize: true)
                }
            }
        }
    }

    private var checkoutFooter: some View {
        VStack(spacing: BrandSpacing.sm) {
            DividerGlow()
                .padding(.horizontal, BrandSpacing.lg)

            Button(action: footerAction) {
                HStack(spacing: BrandSpacing.sm) {
                    if isProcessing {
                        ProgressView()
                            .tint(BrandPalette.textPrimary)
                    } else {
                        Text(step.ctaTitle)
                            .font(BrandFont.mobileBody())
                        Spacer()
                        Text(BrandFormatter.price(step == .review ? total : store.subtotal + shippingCost + activeCODFee))
                            .font(BrandFont.mobileTitle3())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            .contentShape(Rectangle())
            .padding(.horizontal, BrandSpacing.lg)
            .padding(.bottom, BrandSpacing.sm)
            .background(
                BrandPalette.background.opacity(0.95)
                    .background(.ultraThinMaterial)
            )
            .disabled(footerDisabled)
        }
    }

    private var footerDisabled: Bool {
        switch step {
        case .shipping:
            return false
        case .payment:
            return !isPaymentStepValid
        case .review:
            return isProcessing || store.firstBagAvailabilityIssue != nil
        case .bag:
            return true
        }
    }

    private var deliverySubtitle: String {
        guard let gov = selectedDeliveryGovernorate else {
            return "Select governorate to reveal shipping prices."
        }
        let name = gov.rawValue
        if selectedDeliveryMethod.metroOnly && !gov.isMetroGovernorate {
            return "Same day unavailable outside Cairo/Giza."
        }
        return "Standard, express available in \(name)."
    }

    private var paymentSubtitle: String {
        guard selectedDeliveryGovernorate != nil else {
            return "Select a governorate to verify COD availability."
        }

        if isCODEligible {
            return "Cash on delivery available (\(BrandFormatter.price(codFee)) fee)."
        }
        return "COD unavailable here. Use Vodafone Cash."
    }

    private func initializeSelectionsIfNeeded() {
        if selectedAddressID == nil {
            selectedAddressID = store.primaryAddress?.id ?? store.savedAddresses.first?.id
        }

        if selectedDeliveryGovernorate == nil {
            selectedDeliveryGovernorate = selectedAddress?.city
        }

        if canUseCashOnDelivery {
            selectedPaymentOption = .cashOnDelivery
        } else {
            selectedPaymentOption = .vodafoneCash
        }

        syncDeliveryAndPaymentRestrictions()
    }

    private func syncDeliveryAndPaymentRestrictions() {
        if selectedAddressID == nil {
            selectedAddressID = store.primaryAddress?.id ?? store.savedAddresses.first?.id
        }

        if selectedDeliveryGovernorate == nil {
            selectedDeliveryGovernorate = selectedAddress?.city
        }

        if !selectedDeliveryMethod.isAvailable(in: selectedDeliveryGovernorate?.rawValue) {
            selectedDeliveryMethodID = CheckoutDeliveryMethod.standard.id
        }

        if isCODSelected && !isCODEligible {
            selectedPaymentOption = .vodafoneCash
        }
    }

    private func refreshCODEligibility() async {
        guard let selectedDeliveryGovernorate else {
            codEligibilityOverride = nil
            codFee = 20.0
            return
        }

        do {
            let result = try await APIService.shared.validateCOD(governorate: selectedDeliveryGovernorate)
            codEligibilityOverride = result.eligible
            codFee = result.codFee
        } catch {
            codEligibilityOverride = selectedDeliveryGovernorate.isCODEligible
            codFee = selectedDeliveryGovernorate.isCODEligible ? 20.0 : 0
        }
    }

    private func goBack() {
        switch step {
        case .shipping:
            dismiss()
        case .payment:
            step = .shipping
        case .review:
            step = .payment
        case .bag:
            dismiss()
        }
    }

    private func footerAction() {
        switch step {
        case .shipping:
            proceedFromShipping()
        case .payment:
            step = .review
        case .review:
            Task { await placeOrder() }
        case .bag:
            break
        }
    }

    private func proceedFromShipping() {
        checkoutMessage = nil

        if selectedAddressID == nil {
            selectedAddressID = store.primaryAddress?.id ?? store.savedAddresses.first?.id
        }

        if selectedDeliveryGovernorate == nil {
            selectedDeliveryGovernorate = selectedAddress?.city
        }

        syncDeliveryAndPaymentRestrictions()

        guard selectedAddress != nil else {
            checkoutMessage = "Add a delivery address first to continue into payment."
            showAddressSheet = true
            BrandHaptics.notificationWarning()
            return
        }

        if let selectedAddress,
           let validationMessage = checkoutValidationMessage(for: selectedAddress) {
            checkoutMessage = validationMessage
            BrandHaptics.notificationWarning()
            return
        }

        if let issue = store.firstBagAvailabilityIssue {
            checkoutMessage = issue
            BrandHaptics.notificationWarning()
            return
        }

        step = .payment
        BrandHaptics.selection()
    }

    private func applyPromo() async {
        let trimmedCode = promoCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }

        isApplyingPromo = true
        promoMessage = nil
        defer { isApplyingPromo = false }

        do {
            let result = try await APIService.shared.validatePromo(code: trimmedCode)

            if result.isValid {
                promoValidation = result
                appliedPromoCode = trimmedCode
                promoMessage = nil
                BrandHaptics.notificationSuccess()
            } else {
                promoValidation = nil
                appliedPromoCode = nil
                promoMessage = result.message ?? "That promo code is not valid right now."
                BrandHaptics.notificationWarning()
            }
        } catch {
            promoValidation = nil
            appliedPromoCode = nil
            promoMessage = "Promo validation is unavailable right now."
            BrandHaptics.notificationError()
        }
    }

    private func placeOrder() async {
        guard let selectedAddress else {
            step = .shipping
            return
        }

        if let validationMessage = checkoutValidationMessage(for: selectedAddress) {
            placementErrorMessage = validationMessage
            step = .shipping
            BrandHaptics.notificationWarning()
            return
        }

        if let issue = store.firstBagAvailabilityIssue {
            placementErrorMessage = issue
            step = .review
            BrandHaptics.notificationWarning()
            return
        }

        guard let paymentMethod = resolvedPaymentMethod else {
            step = .payment
            return
        }

        isProcessing = true
        placementErrorMessage = nil
        defer { isProcessing = false }

        store.setPrimaryAddress(id: selectedAddress.id)
        let nameParts = selectedAddress.recipient.components(separatedBy: " ")

        let deliveryGovernorate = selectedDeliveryGovernorate ?? selectedAddress.city

        let form = CheckoutForm(
            firstName: nameParts.first ?? selectedAddress.recipient,
            lastName: nameParts.dropFirst().joined(separator: " "),
            email: store.currentUser?.email ?? store.profile.email,
            phone: selectedAddress.phone,
            city: deliveryGovernorate.rawValue,
            address: selectedAddress.line1,
            apartment: selectedAddress.apartment ?? "",
            shippingMethod: selectedDeliveryMethod.title
        )

        let draftOrder = store.buildOrder(
            from: form,
            paymentMethod: paymentMethod,
            shippingCost: shippingCost,
            discount: promoDiscount,
            shippingMethodName: selectedDeliveryMethod.title,
            total: total
        )

        do {
            let syncedOrder = try await APIService.shared.createOrder(
                draftOrder,
                deliveryLocation: deliveryGovernorate.rawValue,
                codFee: activeCODFee,
                paymentMethodID: paymentMethod.type,
                promoCode: appliedPromoCode,
                userId: store.currentUser?.id
            )

            let finalOrder = store.commitPlacedOrder(syncedOrder)
            store.latestCheckoutOrder = finalOrder
            placedOrder = finalOrder
            await store.refreshCatalogFromBackend(forceRefresh: true)
            BrandHaptics.notificationSuccess()
        } catch {
            placementErrorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            BrandHaptics.notificationError()
        }
    }

    private func checkoutValidationMessage(for address: SavedAddress) -> String? {
        if address.recipient.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Add the recipient name before payment."
        }

        let email = (store.currentUser?.email ?? store.profile.email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isValidEmailAddress {
            return "Add a valid email address before payment."
        }

        if address.line1.trimmingCharacters(in: .whitespacesAndNewlines).count < 8 {
            return "Add a complete delivery address before payment."
        }

        if !address.phone.isValidEgyptianMobile {
            return "Use an 11-digit Egyptian mobile number starting with 01."
        }

        guard let selectedDeliveryGovernorate else {
            return "Select a delivery governorate before payment."
        }

        if !selectedDeliveryMethod.isAvailable(in: selectedDeliveryGovernorate.rawValue) {
            return "\(selectedDeliveryMethod.title) is unavailable in \(selectedDeliveryGovernorate.rawValue)."
        }

        if !isPaymentStepValid {
            return selectedPaymentOption == .vodafoneCash
                ? "Enter a valid Vodafone Cash number."
                : "Cash on delivery is unavailable for this governorate."
        }

        return nil
    }

}

private enum CheckoutStep: Int, CaseIterable, Identifiable {
    case bag
    case shipping
    case payment
    case review

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bag: return "Bag"
        case .shipping: return "Shipping"
        case .payment: return "Payment"
        case .review: return "Review"
        }
    }

    var navigationTitle: String {
        switch self {
        case .bag: return "Checkout Bag"
        case .shipping: return "Shipping"
        case .payment: return "Payment"
        case .review: return "Review Order"
        }
    }

    var ctaTitle: String {
        switch self {
        case .bag: return "Continue to Shipping"
        case .shipping: return "Continue to Payment"
        case .payment: return "Review Order"
        case .review: return "Place Order"
        }
    }
}

private enum CheckoutPaymentOption: Hashable {
    case cashOnDelivery
    case vodafoneCash
}

private struct CheckoutDeliveryMethod: Identifiable, Equatable {
    let id: String
    let title: String
    let timeline: String
    let price: Double
    let metroOnly: Bool

    static let standard = CheckoutDeliveryMethod(id: "standard", title: "Standard", timeline: "3-5 days", price: 50, metroOnly: false)
    static let express = CheckoutDeliveryMethod(id: "express", title: "Express", timeline: "1-2 days", price: 120, metroOnly: false)
    static let sameDay = CheckoutDeliveryMethod(id: "same-day", title: "Same Day", timeline: "Today", price: 200, metroOnly: true)

    static let allCases = [standard, express, sameDay]

    func isAvailable(in city: String?) -> Bool {
        guard metroOnly else { return true }
        return city?.isMetroGovernorate == true
    }
}

private struct CheckoutProgressHeader: View {
    let currentStep: CheckoutStep

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.sm) {
            Text("Checkout")
                .font(BrandFont.mobileTitle())
                .foregroundStyle(BrandPalette.textPrimary)

            HStack(spacing: BrandSpacing.xs) {
                ForEach(CheckoutStep.allCases) { step in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("\(step.rawValue + 1)")
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(step.rawValue <= currentStep.rawValue ? BrandPalette.accentForeground : BrandPalette.textSecondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(step.rawValue <= currentStep.rawValue ? BrandPalette.gold : BrandPalette.surfaceRaised)
                                )

                            Text(step.title)
                                .font(BrandFont.mobileCaption())
                                .foregroundStyle(step == currentStep ? BrandPalette.textPrimary : BrandPalette.textSecondary)
                        }

                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? BrandPalette.gold : BrandPalette.hairlineStrong)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(BrandSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .chrome, material: true)
    }
}

private struct CheckoutSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text(title)
                    .font(BrandFont.mobileTitle3())
                    .foregroundStyle(BrandPalette.textPrimary)

                Text(subtitle)
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(BrandPalette.textSecondary)
                    .lineSpacing(4)
            }

            content()
        }
        .padding(BrandSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandPanel(cornerRadius: BrandRadius.card, tone: .shadow, material: true)
    }
}

private struct CheckoutPaymentMethodChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BrandSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(BrandFont.mobileCaption())
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? BrandPalette.accentForeground : BrandPalette.textPrimary)
            .padding(.horizontal, BrandSpacing.md)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                    .fill(isSelected ? BrandPalette.gold : BrandPalette.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.soft, style: .continuous)
                    .stroke(BrandPalette.hairlineStrong, lineWidth: isSelected ? 0 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }
}

private struct CheckoutSelectableCard: View {
    let isSelected: Bool
    let title: String
    let subtitle: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textMuted)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    Text(title)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(subtitle)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)

                    Text(detail)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textMuted)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }
            .padding(BrandSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.soft, tone: isSelected ? .gold : .chrome, material: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct CheckoutDeliveryMethodCard: View {
    let method: CheckoutDeliveryMethod
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? BrandPalette.gold : BrandPalette.textMuted)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    Text(method.title)
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text(method.timeline)
                        .font(BrandFont.mobileCaption())
                        .foregroundStyle(BrandPalette.textSecondary)

                    if method.metroOnly {
                        Text("Cairo / Giza only")
                            .font(BrandFont.mobileCaption())
                            .foregroundStyle(BrandPalette.textMuted)
                    }
                }

                Spacer()

                Text(BrandFormatter.price(method.price))
                    .font(BrandFont.mobileBody())
                    .foregroundStyle(isAvailable ? BrandPalette.gold : BrandPalette.textMuted)
            }
            .padding(BrandSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandPanel(cornerRadius: BrandRadius.soft, tone: isSelected ? .gold : .chrome, material: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
    }
}

private struct CheckoutSummaryRow: View {
    let title: String
    let value: String
    var valueAccent: Color = BrandPalette.textPrimary
    var emphasize = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.textPrimary : BrandPalette.textSecondary)

            Spacer()

            Text(value)
                .font(emphasize ? BrandFont.mobileTitle3() : BrandFont.mobileBody())
                .foregroundStyle(emphasize ? BrandPalette.gold : valueAccent)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct OrderConfirmationView: View {
    let order: Order

    @State private var animateCheckmark = false

    var body: some View {
        PhoneScrollScreen { viewport in
            VStack(spacing: BrandSpacing.xl) {
                ZStack {
                    Circle()
                        .fill(BrandPalette.goldDim)
                        .frame(width: 112, height: 112)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80, weight: .regular))
                        .foregroundStyle(BrandPalette.gold)
                        .scaleEffect(animateCheckmark ? 1 : 0.8)
                        .opacity(animateCheckmark ? 1 : 0.2)
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: animateCheckmark)

                VStack(spacing: BrandSpacing.sm) {
                    Text("Order Confirmed")
                        .font(BrandFont.mobileTitle())
                        .foregroundStyle(BrandPalette.textPrimary)

                    Text("Order \(order.id) has been placed and is now available in your history immediately.")
                        .font(BrandFont.mobileBody())
                        .foregroundStyle(BrandPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }

                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    CheckoutSummaryRow(title: "Order Number", value: order.id)
                    CheckoutSummaryRow(title: "Total", value: BrandFormatter.price(order.total), valueAccent: BrandPalette.gold)
                    CheckoutSummaryRow(title: "Items", value: "\(order.lines.count) pieces")
                    CheckoutSummaryRow(title: "Status", value: order.status.title)
                }
                .padding(BrandSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandPanel(cornerRadius: BrandRadius.card, tone: .gold, material: true)

                NavigationLink {
                    OrderDetailView(order: order)
                } label: {
                    Text("Track Order")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandCapsuleButtonStyle(tone: .gold))
            }
            .padding(.horizontal, viewport.horizontalPadding)
            .padding(.top, viewport.horizontalPadding)
            .padding(.bottom, viewport.bottomPadding)
        }
        .onAppear {
            animateCheckmark = true
        }
    }
}

struct CheckoutAddressDraft {
    var label = "Home"
    var recipient = ""
    var line1 = ""
    var apartment = ""
    var city = EgyptGovernorate.cairo
    var phone = ""
    var isPrimary = true

    var normalizedPhone: String {
        String(phone.phoneDigits.prefix(11))
    }

    var recipientError: String? {
        recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter the recipient name." : nil
    }

    var addressError: String? {
        line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter the street address." : nil
    }

    var phoneError: String? {
        let digits = normalizedPhone
        guard !digits.isEmpty else { return "Enter an Egyptian mobile number." }
        return digits.isValidEgyptianMobile ? nil : "Use an 11-digit Egyptian mobile number starting with 01."
    }

    var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        recipientError == nil &&
        addressError == nil &&
        phoneError == nil
    }
}

struct CheckoutAddressSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentUser: User?
    let defaultRecipient: String
    let onSave: (CheckoutAddressDraft) -> Void

    @State private var draft = CheckoutAddressDraft()
    @FocusState private var focusedField: AddressField?
    @State private var attemptedSave = false

    var body: some View {
        NavigationStack {
            PhoneScrollScreen { viewport in
                VStack(alignment: .leading, spacing: BrandSpacing.lg) {
                    BrandSectionHeader(
                        eyebrow: "New Address",
                        title: "Add a delivery address for checkout.",
                        copy: "All 27 Egyptian governorates are available, and the shipping step updates immediately after save."
                    )

                    BrandField(
                        title: "Label",
                        text: $draft.label,
                        textContentType: .nickname
                    )
                    .focused($focusedField, equals: .label)

                    BrandField(
                        title: "Recipient",
                        text: $draft.recipient,
                        textContentType: .name
                    )
                    .focused($focusedField, equals: .recipient)

                    if attemptedSave, let recipientError = draft.recipientError {
                        validationText(recipientError)
                    }

                    BrandField(
                        title: "Street Address",
                        text: $draft.line1,
                        textContentType: .streetAddressLine1
                    )
                    .focused($focusedField, equals: .line1)

                    if attemptedSave, let addressError = draft.addressError {
                        validationText(addressError)
                    }

                    BrandField(
                        title: "Apartment / Suite",
                        text: $draft.apartment,
                        textContentType: .streetAddressLine2
                    )
                    .focused($focusedField, equals: .apartment)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("GOVERNORATE")
                            .font(BrandFont.mobileCaption())
                            .tracking(3)
                            .foregroundStyle(BrandPalette.textMuted)

                        Picker("Governorate", selection: $draft.city) {
                            ForEach(EgyptGovernorate.allCases) { governorate in
                                Text(governorate.rawValue).tag(governorate)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BrandPalette.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BrandPalette.hairlineStrong, lineWidth: 0.5)
                        )
                    }

                    BrandField(
                        title: "Phone",
                        text: $draft.phone,
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber,
                        submitLabel: .done,
                        autocapitalization: .never
                    )
                    .focused($focusedField, equals: .phone)

                    if attemptedSave, let phoneError = draft.phoneError {
                        validationText(phoneError)
                    }

                    Toggle(isOn: $draft.isPrimary) {
                        Text("Save as primary address")
                            .font(BrandFont.mobileBody())
                            .foregroundStyle(BrandPalette.textPrimary)
                    }
                    .tint(BrandPalette.gold)
                    .padding(BrandSpacing.md)
                    .brandPanel(cornerRadius: BrandRadius.soft, tone: .shadow, material: true)
                }
                .padding(.horizontal, viewport.horizontalPadding)
                .padding(.vertical, viewport.horizontalPadding)
                .padding(.bottom, viewport.bottomPadding)
            }
            .navigationTitle("Add Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        attemptedSave = true
                        guard draft.isValid else {
                            BrandHaptics.notificationWarning()
                            return
                        }
                        onSave(draft)
                        dismiss()
                    }
                    .foregroundStyle(BrandPalette.gold)
                    .opacity(draft.isValid ? 1 : 0.7)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Button("Next", action: focusNextField)
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                if draft.recipient.isEmpty {
                    draft.recipient = currentUser?.name ?? defaultRecipient
                }

                if draft.phone.isEmpty {
                    draft.phone = currentUser?.phone ?? ""
                }
            }
            .onChange(of: draft.phone) { _, newValue in
                let normalized = String(newValue.phoneDigits.prefix(11))
                if normalized != newValue {
                    draft.phone = normalized
                }
            }
        }
    }

    private func validationText(_ message: String) -> some View {
        Text(message)
            .font(BrandFont.mobileCaption())
            .foregroundStyle(.red)
    }

    private func focusNextField() {
        switch focusedField {
        case .label:
            focusedField = .recipient
        case .recipient:
            focusedField = .line1
        case .line1:
            focusedField = .apartment
        case .apartment:
            focusedField = .phone
        case .phone, .none:
            focusedField = nil
        }
    }

    private enum AddressField {
        case label
        case recipient
        case line1
        case apartment
        case phone
    }
}

extension String {
    var phoneDigits: String {
        filter(\.isNumber)
    }

    var isValidEgyptianMobile: Bool {
        phoneDigits.count == 11 && phoneDigits.hasPrefix("01")
    }

    var isValidEmailAddress: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    var isValidVodafoneCashNumber: Bool {
        let digits = phoneDigits
        guard digits.isValidEgyptianMobile else {
            return false
        }

        return digits.dropFirst(2).first != nil
    }

    var isMetroGovernorate: Bool {
        caseInsensitiveCompare("Cairo") == .orderedSame || caseInsensitiveCompare("Giza") == .orderedSame
    }
}
