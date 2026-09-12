//
//  Match.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//
//  One file the index knows about.
//
//  A DELIBERATELY SMALL SLICE of what Spotlight holds. A plain text file carries 27
//  attributes and a photograph carries far more — camera, lens, exposure, where it was taken.
//  Everything here is what is true of EVERY file, so a result set is rectangular and a caller
//  never has to test whether a field exists. ``attributes`` is the escape hatch for the rest.
//

import Foundation

/// A file matching a query.
public struct Match: Equatable, Hashable, Sendable, Codable, Identifiable {

    /// The full path — unique, so it doubles as the identity.
    public var id: String { path }

    /// Where the file is.
    public let path: String

    /// Its name, extension included.
    public let name: String

    /// Size in bytes. Zero for a directory, and for a bundle that Spotlight reports as one file.
    public let size: Int

    /// Apple's uniform type identifier — `public.png`, `com.adobe.pdf`, `public.swift-source`.
    public let contentType: String?

    /// What Finder would call it: "PNG image", "Swift Source".
    public let kind: String?

    /// When the contents last changed.
    public let modified: Date?

    /// When it was created.
    public let created: Date?

    /// Everything else Spotlight holds for this file, unparsed.
    ///
    /// Empty unless asked for. Camera and GPS live here for a photograph, duration and codec
    /// for a video, author and page count for a PDF — none of which a text file has, which is
    /// why they are not fields on this type.
    public let attributes: [String: String]

    public init(path: String, name: String, size: Int = 0, contentType: String? = nil,
                kind: String? = nil, modified: Date? = nil, created: Date? = nil,
                attributes: [String: String] = [:]) {
        self.path = path
        self.name = name
        self.size = size
        self.contentType = contentType
        self.kind = kind
        self.modified = modified
        self.created = created
        self.attributes = attributes
    }

    /// The directory holding it.
    public var directory: String { (path as NSString).deletingLastPathComponent }

    /// The file extension, lowercased, or `nil` when it has none.
    public var fileExtension: String? {
        let value = (name as NSString).pathExtension.lowercased()
        return value.isEmpty ? nil : value
    }
}
