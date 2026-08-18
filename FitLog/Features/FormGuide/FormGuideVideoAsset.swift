//
//  FormGuideVideoAsset.swift
//  FitLog
//
//  Builds AVURLAsset instances that attach auth headers for MuscleWiki / proxy streams.
//

import AVFoundation
import Foundation

enum FormGuideVideoAsset {
    /// Undocumented AVFoundation option used to attach HTTP headers to media requests.
    static let httpHeaderFieldsKey = "AVURLAssetHTTPHeaderFieldsKey"

    static func makeURLAsset(url: URL, headers: [String: String]) -> AVURLAsset {
        guard !headers.isEmpty else {
            return AVURLAsset(url: url)
        }
        return AVURLAsset(url: url, options: [httpHeaderFieldsKey: headers])
    }
}
