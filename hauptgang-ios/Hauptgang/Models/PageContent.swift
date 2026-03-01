import Foundation

struct PageContent: Sendable {
    let url: URL
    let jsonLd: [String]
    let metaTags: [String: String]
    let coverImageCandidates: [String]
    let html: String

    init?(from javaScriptValues: [String: Any]) {
        guard let urlString = javaScriptValues["url"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        self.url = url
        self.jsonLd = (javaScriptValues["jsonLd"] as? [String]) ?? []
        self.metaTags = (javaScriptValues["metaTags"] as? [String: String]) ?? [:]
        self.coverImageCandidates = (javaScriptValues["coverImageCandidates"] as? [String]) ?? []
        self.html = (javaScriptValues["html"] as? String) ?? ""
    }
}
