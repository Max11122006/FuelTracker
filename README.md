# FuelTracker

An iOS app that finds nearby fuel stations, applies your Esso fuel card discount, and tells you whether it's worth driving further to a cheaper station — accounting for the extra fuel you'd burn getting there.

Includes a home-screen **WidgetKit widget** that monitors your commute route (EH17 8LW → Heriot-Watt Edinburgh) and shows a green/red verdict for your morning run.

---

## Setup

### Prerequisites

| Tool | Install |
|---|---|
| Xcode 15+ | Mac App Store |
| XcodeGen | `brew install xcodegen` |
| Apple Developer account | Required for device builds (simulator works without it) |

### 1. Generate the Xcode project

```bash
cd /path/to/FuelTracker
xcodegen generate
open FuelTracker.xcodeproj
```

### 2. Add your Google Places API key

The app uses **Google Places Nearby Search** to find petrol stations near you. Without a key, the app falls back to manually-entered prices only.

1. Get a key at [console.cloud.google.com](https://console.cloud.google.com/)
2. Enable **Places API (New)** under APIs & Services → Library
3. Copy the template file and add your key:

```bash
cp FuelTracker/Configuration/Secrets.xcconfig.template \
   FuelTracker/Configuration/Secrets.xcconfig
```

4. Edit `FuelTracker/Configuration/Secrets.xcconfig` and replace the placeholder:

```
GOOGLE_PLACES_API_KEY = AIzaSy...your-real-key-here...
```

`Secrets.xcconfig` is git-ignored and never committed.

### 3. Register the App Group (device builds only)

The app and widget share data via an **App Group** (`group.com.maxd.FuelTracker`).

1. Sign in to [developer.apple.com](https://developer.apple.com)
2. Go to **Certificates, IDs & Profiles → Identifiers**
3. Create (or edit) the App ID `com.maxd.FuelTracker` and enable **App Groups**
4. Add group `group.com.maxd.FuelTracker`
5. Repeat for the widget extension ID `com.maxd.FuelTracker.widget`

In Xcode, set your **Team** under each target's Signing & Capabilities.

### 4. Build & Run

- Select the **FuelTracker** scheme and a simulator or device
- `Cmd+R` to build and run

---

## Architecture

```
FuelTracker/
├── Shared/                  # Compiled into both app + widget
│   └── AppGroupStore.swift  # UserDefaults bridge for widget data
│
├── FuelTracker/             # Main app target
│   ├── Configuration/       # xcconfig, API key injection
│   ├── CoreData/            # Persistent store + NSManagedObject subclasses
│   ├── Models/              # Plain Swift value types (FuelStation, WorthItResult, UserSettings)
│   ├── Services/
│   │   ├── WorthItCalculator.swift   # Pure calculation logic
│   │   ├── LocationService.swift     # CLLocationManager wrapper
│   │   ├── GooglePlacesService.swift # Station discovery
│   │   ├── EssoFeedService.swift     # CMA live price feed (no key needed)
│   │   └── FuelPriceService.swift    # Orchestration layer
│   ├── ViewModels/          # @MainActor ObservableObjects
│   └── Views/               # SwiftUI views (Map, List, Settings, Components)
│
└── FuelTrackerWidget/       # Widget extension target
    ├── WidgetModels.swift        # CommuteEntry: TimelineEntry
    ├── CommuteWidget.swift       # TimelineProvider + Widget configuration
    └── CommuteWidgetEntryView.swift  # Small + medium widget views
```

**Pattern:** MVVM. ViewModels own `@Published` state and drive views. Services are injected via `static shared` singletons. Plain Swift structs flow between layers — `NSManagedObject` subclasses never leave the persistence layer.

---

## Data Sources

| Source | What it provides | Key required? |
|---|---|---|
| [CMA Esso feed](https://fuelprices.esso.co.uk/fuel_prices_data.json) | Live Esso pump prices (pence/litre) | No — free, mandatory |
| Google Places Nearby Search | Station names + coordinates | Yes — see setup above |
| CoreData (local) | Manually-entered prices + history | — |

**Esso prices** come from the CMA-mandated live feed published directly by Esso UK — no key needed, updates throughout the day.

**Other stations** are located via Google Places. Prices must be entered manually (swipe left on any row → Update Price). Once entered, prices are stored locally with a timestamp and the staleness indicator shows how old they are.

---

## Worth-It Calculation

For each non-Esso station, the app calculates:

```
essoEffectivePrice   = essoPumpPrice − cardDiscount (default 10p)
extraDistance        = max(0, distanceToAlt − distanceToEsso)  [miles]
extraFuelLitres      = extraDistance × 2 × (4.546 / mpg)       [round-trip detour]
extraFuelCost        = extraFuelLitres × essoEffectivePrice     [pence]
grossSaving          = (essoEffectivePrice − altPrice) × fillLitres
netSaving            = grossSaving − extraFuelCost

WORTH IT  ←→  netSaving > 0
```

The **effective price per litre** (`altPrice + extraFuelCost / fillLitres`) is used for sorting the list and colour-coding map pins.

---

## Widget

The **Commute Fuel Check** widget:
- Reads pre-computed results written to App Group `UserDefaults` by the main app
- Makes **no network calls** (WidgetKit constraint)
- Refreshes at 07:00, 12:00, 17:00; also reloads whenever the main app refreshes prices
- Shows a **green** verdict if any station along your commute undercuts the discounted Esso price after accounting for detour cost; **red** otherwise

To test the widget update cycle in the simulator:
1. Run the main app and let it fetch prices
2. Add the widget to the home screen
3. The widget reads from the shared `UserDefaults` immediately

---

## Settings

| Setting | Default | Notes |
|---|---|---|
| Car MPG | 35 | Used in detour cost calculation |
| Fill-up litres | 40 L | Used for gross saving calculation |
| Esso discount | 10p/litre | Applied to all Esso prices automatically |
| Home postcode | EH17 8LW | Widget route start |
| Destination | Heriot-Watt University | Widget route end |

---

## Notes

- **Simulator**: Location permission works in simulator. Use **Features → Location → Custom Location** to set a fake position in Edinburgh (e.g. 55.906, −3.128).
- **App Groups on simulator**: App Groups work in the simulator without Developer portal registration. You only need portal setup for real device builds.
- **Background refresh**: Registers a `BGAppRefreshTask` that fires ~every 4 hours when the app has been used recently. iOS throttles background tasks aggressively — this is expected behaviour.
