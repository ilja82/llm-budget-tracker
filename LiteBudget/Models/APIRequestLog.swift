import Foundation

struct APIRequestLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let requestURL: String
    let statusCode: Int?
    let responseBody: String
    let errorMessage: String?
    let extractedFields: [ExtractedField]

    struct ExtractedField: Codable, Identifiable {
        var id: String { name }
        let name: String
        let value: String
    }
}