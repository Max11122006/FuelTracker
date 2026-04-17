import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var stationsVM: StationsViewModel
    @State private var showSavedBanner = false

    var body: some View {
        NavigationView {
            Form {
                // ── Car ────────────────────────────────────────────────────────
                Section {
                    LabeledContent("Fuel economy") {
                        HStack {
                            TextField("35", value: $settingsVM.carMPG, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("MPG")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Car")
                } footer: {
                    Text("Used to calculate the extra fuel cost of driving to a farther station.")
                }

                // ── Fuel Level ─────────────────────────────────────────────────
                Section {
                    FuelGaugeView(level: $settingsVM.fuelGaugeLevel)
                        .padding(.vertical, 4)
                } header: {
                    Text("Current Fuel Level")
                } footer: {
                    Text("2006 Honda Civic (50 L tank). Drag the gauge to your current level — the fill-up amount is calculated automatically.")
                }

                // ── Fuel Card ──────────────────────────────────────────────────
                Section {
                    LabeledContent("Esso discount") {
                        HStack {
                            TextField("10", value: $settingsVM.essoDiscountPence, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("p/litre")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Fuel Card")
                } footer: {
                    Text("Your Esso fuel card discount. Applied automatically to all Esso station prices.")
                }

                // ── Commute ────────────────────────────────────────────────────
                Section {
                    LabeledContent("Home postcode") {
                        TextField("e.g. EH17 8LW", text: $settingsVM.homePostcode)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }

                    LabeledContent("Destination") {
                        TextField("e.g. Heriot-Watt University",
                                  text: $settingsVM.uniLocation)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Commute Route (Widget)")
                } footer: {
                    Text("The home screen widget monitors stations along this route and shows a green/red verdict.")
                }

                // ── Fuel Finder API ────────────────────────────────────────────
                Section {
                    SecureField("Client ID", text: $settingsVM.fuelFinderClientID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Client Secret", text: $settingsVM.fuelFinderClientSecret)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if settingsVM.credentialsConfigured {
                        Label("Credentials stored in Keychain", systemImage: "checkmark.shield.fill")
                            .foregroundColor(Color("PinGreen"))
                            .font(.footnote)
                    }

                    if settingsVM.credentialsConfigured {
                        Button(role: .destructive) {
                            settingsVM.clearCredentials()
                        } label: {
                            Label("Clear Saved Credentials", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Fuel Finder API")
                } footer: {
                    Text("Register at developer.fuel-finder.service.gov.uk. Credentials are stored in the iOS Keychain, never in iCloud or source code.")
                }

                // ── Save ───────────────────────────────────────────────────────
                Section {
                    Button {
                        settingsVM.save()
                        withAnimation { showSavedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showSavedBanner = false }
                        }
                        Task { await stationsVM.refresh(settings: settingsVM.currentSettings) }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save & Refresh", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .tint(.green)
                }

                if showSavedBanner {
                    Section {
                        Label("Settings saved.", systemImage: "checkmark.circle")
                            .foregroundColor(Color("PinGreen"))
                            .listRowBackground(Color("CardBackground"))
                    }
                }

                // ── About ──────────────────────────────────────────────────────
                Section {
                    LabeledContent("Price & station data") {
                        Text("UK Gov Fuel Finder API")
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(StationsViewModel())
        .preferredColorScheme(.dark)
}
