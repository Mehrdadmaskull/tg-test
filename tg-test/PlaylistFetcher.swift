//
//  PlaylistFetcher.swift
//  tg-test
//
//  Created by Mehrdad Ahmadi on 2024-10-21.
//

import Foundation

// MARK: - PlaylistFetcher
/// Responsible for downloading and parsing the .m3u8 playlist,
/// extracting segment URLs for video playback.
class PlaylistFetcher {
    func fetchPlaylist(url: URL, completion: @escaping ([URL]) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            let playlist = String(data: data, encoding: .utf8)
            let segmentURLs = self.parseM3U8(playlist: playlist ?? "", baseURL: url)
            completion(segmentURLs)
        }.resume()
    }
    
    /// Parses the .m3u8 file to extract segment URLs.
    private func parseM3U8(playlist: String, baseURL: URL) -> [URL] {
        var segmentURLs: [URL] = []
        let lines = playlist.components(separatedBy: "\n")
        
        for line in lines where line.hasSuffix(".ts") {
            if let url = URL(string: line, relativeTo: baseURL) {
                segmentURLs.append(url)
            }
        }
        return segmentURLs
    }
}
