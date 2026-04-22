import Foundation

/// Four-way FSRS rating the Monterey Wall UI surfaces to the user.
///
/// Raw values match FSRS convention (1=Again, 2=Hard, 3=Good, 4=Easy) so they can be
/// serialized into reviews and compared with library layers without a translation table.
public enum MWRating: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard = 2, good = 3, easy = 4

    /// label.
    public var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}
