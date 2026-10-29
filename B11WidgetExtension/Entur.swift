import Foundation

struct Departure: Codable, Hashable {
    let aimed: Date
    let expected: Date
    let realtime: Bool
    let cancelled: Bool
    let destination: String
    let quay: String?

    var delayMinutes: Int {
        Int((expected.timeIntervalSince(aimed) / 60).rounded())
    }
}

struct Disruption: Codable, Hashable {
    let id: String
    let summary: String
}

struct Board {
    let departures: [Departure]
    let disruptions: [Disruption]
}

enum Entur {
    static let stopPlaceId = "NSR:StopPlace:58377" // Lysaker brygge
    static let lineId = "RUT:Line:3811"            // B11 Lysaker - Nesoddtangen

    private static let endpoint = URL(string: "https://api.entur.io/journey-planner/v3/graphql")!
    private static let clientName = "harrynystad-b11widget"

    private static let query = """
    query($stop: String!, $line: ID!) {
      line(id: $line) {
        situations { ...situation }
      }
      stopPlace(id: $stop) {
        estimatedCalls(numberOfDepartures: 10, timeRange: 86400, whiteListed: { lines: [$line] }) {
          aimedDepartureTime
          expectedDepartureTime
          realtime
          cancellation
          quay { publicCode }
          destinationDisplay { frontText }
          situations { ...situation }
        }
      }
    }

    fragment situation on PtSituationElement {
      id
      summary { value language }
      validityPeriod { startTime endTime }
    }
    """

    static func fetchBoard() async throws -> Board {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientName, forHTTPHeaderField: "ET-Client-Name")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": ["stop": stopPlaceId, "line": lineId],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let calls = decoded.data.stopPlace?.estimatedCalls ?? []
        let iso = ISO8601DateFormatter()

        let departures: [Departure] = calls.compactMap { call in
            guard let aimed = iso.date(from: call.aimedDepartureTime),
                  let expected = iso.date(from: call.expectedDepartureTime) else { return nil }
            return Departure(
                aimed: aimed,
                expected: expected,
                realtime: call.realtime,
                cancelled: call.cancellation,
                destination: call.destinationDisplay?.frontText ?? "Nesoddtangen",
                quay: call.quay?.publicCode
            )
        }

        // Line-wide messages plus ones attached to individual sailings, deduplicated.
        let now = Date()
        var seen = Set<String>()
        let situations = (decoded.data.line?.situations ?? []) + calls.flatMap { $0.situations ?? [] }
        let disruptions: [Disruption] = situations.compactMap { situation in
            guard seen.insert(situation.id).inserted else { return nil }
            if let end = situation.validityPeriod?.endTime.flatMap(iso.date(from:)), end < now { return nil }
            if let start = situation.validityPeriod?.startTime.flatMap(iso.date(from:)),
               start > now.addingTimeInterval(86400) { return nil }
            let texts = situation.summary ?? []
            guard let text = (texts.first { $0.language == "en" } ?? texts.first)?.value else { return nil }
            return Disruption(id: situation.id, summary: text)
        }

        return Board(departures: departures, disruptions: disruptions)
    }

    private struct Response: Decodable {
        struct DataField: Decodable {
            let line: Line?
            let stopPlace: StopPlace?
        }
        struct Line: Decodable { let situations: [Situation]? }
        struct StopPlace: Decodable { let estimatedCalls: [Call] }
        struct Situation: Decodable {
            struct Text: Decodable {
                let value: String
                let language: String?
            }
            struct Validity: Decodable {
                let startTime: String?
                let endTime: String?
            }
            let id: String
            let summary: [Text]?
            let validityPeriod: Validity?
        }
        struct Call: Decodable {
            let aimedDepartureTime: String
            let expectedDepartureTime: String
            let realtime: Bool
            let cancellation: Bool
            let quay: Quay?
            let destinationDisplay: DestinationDisplay?
            let situations: [Situation]?
        }
        struct Quay: Decodable { let publicCode: String? }
        struct DestinationDisplay: Decodable { let frontText: String? }
        let data: DataField
    }
}
