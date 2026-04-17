<div align="center">

<img src="Shared/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="FuelTracker icon" />

# FuelTracker

**Stop overpaying for petrol. Know before you go.**

[![iOS 16+](https://img.shields.io/badge/iOS-16%2B-black?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-required-blue)](https://github.com/yonaskolb/XcodeGen)
[![UK Gov Fuel Finder API](https://img.shields.io/badge/Data-UK%20Gov%20Fuel%20Finder%20API-005EA5)](https://www.gov.uk/guidance/access-the-latest-fuel-prices-and-forecourt-data-via-api-or-email)

</div>

---

FuelTracker pulls **live UK petrol prices** from the government-mandated Fuel Finder API, applies your **Esso fuel card discount**, then does the maths — is it actually cheaper to drive past your local Esso to that slightly cheaper Shell down the road, once you factor in the extra fuel you'll burn getting there?

The answer, with a £ figure, every time you open the app.

---

## Features

- **Live prices** for every petrol station in your area via the [UK Government Fuel Finder API](https://www.gov.uk/guidance/access-the-latest-fuel-prices-and-forecourt-data-via-api-or-email) — updated throughout the day, no scraping
- **Esso card discount** applied automatically (configurable pence/litre)
- **Worth-it calculator** — accounts for detour distance, extra fuel burned, and your fill-up volume
- **Best Pick tab** — one clear answer: which station, how much you save, the full breakdown
- **Interactive fuel gauge** — set your current tank level (2006 Honda Civic, 50 L) and the app calculates exactly how much a fill-up costs you at each station
- **Map view** with colour-coded pins: 🟢 green within 1p of cheapest · 🟡 amber 1–3p more · 🔴 red over 3p more
- **Expandable station rows** — tap any station for the complete cost breakdown (fill-up cost, detour miles, detour fuel cost, gross and net saving)
- **Manual price override** — swipe left on any station to enter a price yourself; timestamped and shown with a staleness indicator
- **10-mile search radius** — covers all of Edinburgh and the western suburbs without needing to scroll

---

## Screenshots

> _Run the app on a simulator or device to see it in action. Features → Location → Custom Location: `55.9065, -3.1800` puts you in south Edinburgh._

---

## Setup

### Prerequisites

| Tool | Install |
| --- | --- |
| Xcode 15.4+ | Mac App Store |
| XcodeGen | `brew install xcodegen` |
| UK Gov Fuel Finder API credentials | [developer.fuel-finder.service.gov.uk](https://developer.fuel-finder.service.gov.uk) |

### 1. Generate the Xcode project

```bash
git clone https://github.com/your-username/FuelTracker.git
cd FuelTracker
xcodegen generate
open FuelTracker.xcodeproj
```

### 2. Add your Fuel Finder API credentials

The app uses the **UK Government Fuel Finder API** for live station and price data.

1. Register at [developer.fuel-finder.service.gov.uk](https://developer.fuel-finder.service.gov.uk)
2. Create an application to get a **Client ID** and **Client Secret**
3. Launch the app → **Settings → Fuel Finder API** → enter your credentials → tap **Save & Refresh**

Credentials are stored in the **iOS Keychain** — never in source code, config files, or iCloud.

### 3. Build & run

Select the **FuelTracker** scheme, pick a simulator or device, and hit `Cmd+R`.

---

## How the maths works

For each non-Esso station, the app computes:

```text
essoEffectivePrice  =  essoPumpPrice − cardDiscount        (default 10p/L)

extraDistance       =  max(0, distToAlt − distToEsso)     miles
extraFuelLitres     =  extraDistance × 2 × (4.546 ÷ mpg)  round-trip detour
extraFuelCost       =  extraFuelLitres × essoEffectivePrice

grossSaving         =  (essoEffectivePrice − altPrice) × fillLitres
netSaving           =  grossSaving − extraFuelCost

  netSaving > 0  →  ✅ WORTH IT
  netSaving ≤ 0  →  ❌ STAY AT ESSO
```

The **effective price per litre** (`altPrice + extraFuelCost ÷ fillLitres`) is used for sorting the list and colour-coding map pins — so the station ranked #1 is the cheapest door-to-door, not just the cheapest at the pump.

---

## Architecture

```text
FuelTracker/
├── Shared/                        # Compiled into app (and future widget)
│   ├── AppGroupStore.swift        # UserDefaults bridge (App Group)
│   └── Assets.xcassets/           # Shared colours + app icon
│
└── FuelTracker/                   # Main app target
    ├── Configuration/
    │   ├── Config.swift           # URL constants, radii, thresholds
    │   └── FuelTracker.xcconfig   # Build settings
    ├── CoreData/                  # Persistent store (App Group container)
    │   ├── FuelTracker.xcdatamodeld
    │   ├── FuelStationCD.swift
    │   ├── FuelPriceRecordCD.swift
    │   ├── UserSettingsCD.swift
    │   └── PersistenceController.swift
    ├── Models/
    │   ├── FuelStation.swift      # Plain value type (not NSManagedObject)
    │   ├── UserSettings.swift     # Settings snapshot passed to services
    │   └── WorthItResult.swift    # Calculation output (Identifiable, Equatable)
    ├── Services/
    │   ├── FuelFinderAPIService.swift   # OAuth2, batch pagination, geo cache
    │   ├── FuelPriceService.swift       # Orchestration → CoreData → calculator
    │   ├── WorthItCalculator.swift      # Pure stateless calculation engine
    │   ├── LocationService.swift        # CLLocationManager wrapper
    │   └── KeychainService.swift        # Credential storage
    ├── ViewModels/
    │   ├── StationsViewModel.swift      # @MainActor, drives Map + List
    │   └── SettingsViewModel.swift      # @MainActor, persists settings
    └── Views/
        ├── ContentView.swift            # TabView root
        ├── Map/                         # MapKit pin + annotation views
        ├── List/                        # Station list + expandable rows
        ├── BestPick/                    # Opinionated recommendation page
        ├── Settings/                    # Credentials, gauge, preferences
        └── Components/                  # VerdictBadge, FuelGaugeView, StalenessLabel
```

**MVVM throughout.** ViewModels hold `@Published` state and call into services. Plain Swift structs (`FuelStation`, `WorthItResult`) flow between layers — `NSManagedObject` subclasses never leave the persistence layer. `WorthItCalculator` is a pure `enum` with `static` functions — fully unit-testable with zero mocking.

---

## Data

| Source | What it provides | Auth |
| --- | --- | --- |
| [UK Gov Fuel Finder API](https://www.fuel-finder.service.gov.uk) | Live prices + station metadata for every UK forecourt (~23,500 stations) | OAuth2 client credentials |
| CoreData (local) | Manually-entered prices + full price history | — |

The Fuel Finder API is mandated by the **Competition and Markets Authority (CMA)** — all major fuel retailers are required to publish live prices to it. Data updates throughout the day.

Station and price data are fetched in parallel batches (6 concurrent requests) and cached locally:

- **Station metadata** — 24-hour TTL, invalidated if you move more than 5 miles
- **Prices** — 15-minute TTL, with incremental delta updates after the first fetch

---

## Configuration

All user settings are editable in **Settings → Save & Refresh**:

| Setting | Default | Notes |
| --- | --- | --- |
| Car MPG | 35 | Used to calculate detour fuel cost |
| Fuel gauge level | ½ tank | Draggable gauge — fill-up litres derived automatically (50 L tank) |
| Esso discount | 10p/L | Applied to all Esso prices |
| Home postcode | _(empty)_ | Set your own — used for the commute widget |
| Destination | _(empty)_ | Set your own |
| Fuel Finder Client ID | _(Keychain)_ | Enter once, stored securely |
| Fuel Finder Client Secret | _(Keychain)_ | Enter once, stored securely |

---

## Notes

- **Simulator location** — use **Features → Location → Custom Location** and enter `55.9065, -3.1800` (south Edinburgh) to get meaningful results
- **Costco excluded** — Costco fuel stations require a paid membership so they're filtered out of results
- **Search radius** — 10 miles by default, with a 20-mile background download cache so nearby stations are always ready even after a short drive
- **App Groups** — work on the simulator without Apple Developer portal registration; only needed for real device builds
