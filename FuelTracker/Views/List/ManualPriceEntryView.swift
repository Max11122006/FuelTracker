import SwiftUI

struct ManualPriceEntryView: View {
    let station: FuelStation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var stationsVM: StationsViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var priceText = ""
    @State private var fuelType  = "unleaded"
    @State private var showError = false

    private let fuelTypes = ["unleaded", "diesel", "premium"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.headline)
                        if let addr = station.address {
                            Text(addr)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Station")
                }

                Section {
                    Picker("Fuel type", selection: $fuelType) {
                        ForEach(fuelTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        TextField("e.g. 148.9", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text("p/litre")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Price")
                } footer: {
                    Text("Enter the pump price in pence per litre (e.g. 148.9 for £1.489/L).")
                }

                if showError {
                    Section {
                        Label("Please enter a valid price between 50 and 300p.", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let price = Double(priceText), price > 50, price < 300 else {
            showError = true
            return
        }
        stationsVM.saveManualPrice(for: station, price: price)
        dismiss()
        Task {
            await stationsVM.refresh(settings: settingsVM.currentSettings)
        }
    }
}
