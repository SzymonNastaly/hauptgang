import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case payloadTooLarge
    case unsupportedMediaType
    case unprocessableEntity(String?)
    case serverError(statusCode: Int)
    case decodingError(Error)
    case invalidCredentials
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .invalidResponse:
            return "Received an invalid response from the server"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound:
            return "The requested resource was not found"
        case .payloadTooLarge:
            return "Image is too large. Please try a smaller photo."
        case .unsupportedMediaType:
            return "Unsupported image format."
        case .unprocessableEntity(let message):
            return message ?? "Could not process this image."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingError:
            return "Unable to process the server response"
        case .invalidCredentials:
            return "Invalid email or password"
        case .unknown:
            return "An unexpected error occurred"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your Wi-Fi or cellular connection and try again."
        case .unauthorized:
            return "Please sign in with your credentials."
        case .invalidCredentials:
            return "Double-check your email and password, then try again."
        case .serverError:
            return "Wait a moment and try again. If the problem persists, contact support."
        default:
            return nil
        }
    }
}
