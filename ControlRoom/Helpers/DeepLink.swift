//
//  DeepLink.swift
//  ControlRoom
//
//  Created by Paul Hudson on 16/05/2023.
//  Copyright © 2023 Paul Hudson. All rights reserved.
//

import Foundation

/// A named URL with a unique identifier to make them work well with SwiftUI.
struct DeepLink: Identifiable, Codable {
    var id: UUID
    var name: String
    var url: URL
}

extension String {
    var appLaunchDeepLinkTarget: String {
        guard let extracted = extractWrappedDeepLinkTarget() else {
            return self
        }

        return extracted
    }

    private func extractWrappedDeepLinkTarget() -> String? {
        let parameterNames = ["url", "deeplink", "deepLink", "targetUrl", "targetURL"]

        for parameterName in parameterNames {
            guard let range = wrappedParameterRange(named: parameterName) else { continue }

            let candidate = String(self[range...])
            if candidate.contains("://") {
                return candidate.removingPercentEncoding ?? candidate
            }

            if let decoded = candidate.removingPercentEncoding, decoded.contains("://") {
                return decoded
            }
        }

        return nil
    }

    private func wrappedParameterRange(named parameterName: String) -> String.Index? {
        let lowercase = lowercased()
        let tokens = ["?\(parameterName.lowercased())=", "&\(parameterName.lowercased())="]

        for token in tokens {
            guard let range = lowercase.range(of: token) else { continue }
            return range.upperBound.samePosition(in: self)
        }

        return nil
    }
}
