import CoreLocation
import Foundation
import MapKit

enum EgyptGovernorate: String, CaseIterable, Codable, Hashable, Identifiable {
    case cairo = "Cairo"
    case alexandria = "Alexandria"
    case giza = "Giza"
    case beheira = "Beheira"
    case qalyubia = "Qalyubia"
    case dakahlia = "Dakahlia"
    case sharqia = "Sharqia"
    case damietta = "Damietta"
    case portSaid = "Port Said"
    case ismailia = "Ismailia"
    case suez = "Suez"
    case southSinai = "South Sinai"
    case northSinai = "North Sinai"
    case fayoum = "Fayoum"
    case beniSuef = "Beni Suef"
    case minya = "Minya"
    case asyut = "Asyut"
    case sohag = "Sohag"
    case qena = "Qena"
    case luxor = "Luxor"
    case aswan = "Aswan"
    case redSea = "Red Sea"
    case newValley = "New Valley"
    case matrouh = "Matrouh"
    case monufia = "Monufia"
    case gharbia = "Gharbia"
    case kafrElSheikh = "Kafr El Sheikh"

    var id: String { rawValue }

    var latitude: Double {
        switch self {
        case .cairo: return 30.0444
        case .alexandria: return 31.2001
        case .giza: return 30.0131
        case .beheira: return 30.8481
        case .qalyubia: return 30.3292
        case .dakahlia: return 31.0409
        case .sharqia: return 30.5965
        case .damietta: return 31.4175
        case .portSaid: return 31.2653
        case .ismailia: return 30.5965
        case .suez: return 29.9668
        case .southSinai: return 28.2360
        case .northSinai: return 30.4550
        case .fayoum: return 29.3084
        case .beniSuef: return 29.0661
        case .minya: return 28.0871
        case .asyut: return 27.1801
        case .sohag: return 26.5591
        case .qena: return 26.1551
        case .luxor: return 25.6872
        case .aswan: return 24.0889
        case .redSea: return 26.3541
        case .newValley: return 25.4510
        case .matrouh: return 31.3543
        case .monufia: return 30.5972
        case .gharbia: return 30.8754
        case .kafrElSheikh: return 31.1107
        }
    }

    var longitude: Double {
        switch self {
        case .cairo: return 31.2357
        case .alexandria: return 29.9187
        case .giza: return 31.2089
        case .beheira: return 30.3436
        case .qalyubia: return 31.2165
        case .dakahlia: return 31.3785
        case .sharqia: return 31.5145
        case .damietta: return 31.8144
        case .portSaid: return 32.3019
        case .ismailia: return 32.2715
        case .suez: return 32.5498
        case .southSinai: return 33.6176
        case .northSinai: return 33.8064
        case .fayoum: return 30.8428
        case .beniSuef: return 31.0994
        case .minya: return 30.7618
        case .asyut: return 31.1837
        case .sohag: return 31.6957
        case .qena: return 32.7160
        case .luxor: return 32.6396
        case .aswan: return 32.8998
        case .redSea: return 33.7692
        case .newValley: return 30.5464
        case .matrouh: return 27.2373
        case .monufia: return 30.9876
        case .gharbia: return 31.0335
        case .kafrElSheikh: return 30.9388
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isCODEligible: Bool {
        switch self {
        case .cairo, .giza, .alexandria, .beheira, .qalyubia, .dakahlia, .sharqia, .ismailia:
            return true
        default:
            return false
        }
    }

    var isMetroGovernorate: Bool {
        switch self {
        case .cairo, .giza:
            return true
        default:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let rawValue = try? container.decode(String.self),
           let governorate = Self.mappedGovernorate(from: rawValue) {
            self = governorate
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)

        guard let governorate = Self.mappedGovernorate(from: name) else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Unsupported governorate: \(name)"
            )
        }

        self = governorate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(isCODEligible, forKey: .isCODEligible)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
        case isCODEligible
    }

    private static func mappedGovernorate(from rawValue: String) -> EgyptGovernorate? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "menoufia", "menofia":
            return .monufia
        case "daqahlia":
            return .dakahlia
        case "assyut":
            return .asyut
        default:
            return Self.allCases.first { $0.rawValue.lowercased() == normalized }
        }
    }
}
