import Foundation
import MapKit
import SwiftUI

/// Lightweight data wrapper used as the items array for `MapAnnotation`.
struct StationAnnotationData: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let displayPricePence: Double?
    let pinColor: PinColour
    let isEsso: Bool

    enum PinColour {
        case green, amber, red, blue, gray

        var color: Color {
            switch self {
            case .green: return Color("PinGreen")
            case .amber: return Color("PinAmber")
            case .red:   return Color("PinRed")
            case .blue:  return .blue
            case .gray:  return .gray
            }
        }
    }
}
