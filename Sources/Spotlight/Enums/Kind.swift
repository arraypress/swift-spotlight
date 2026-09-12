//
//  Kind.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//
//  The handful of file kinds worth a name.
//
//  Spotlight speaks uniform type identifiers — `public.image`, `com.adobe.pdf` — and a caller
//  who wants pictures should be able to say "image". These are the TREE types, so `.image`
//  matches a PNG because a PNG is one; matching `public.png` exactly would miss every JPEG.
//
//  A SHORT LIST ON PURPOSE. There are hundreds of UTIs and wrapping them all would be a
//  worse version of the type system Apple already ships. Anything not here is still reachable
//  by passing the identifier straight through — see ``Kind/other(_:)``.
//

import Foundation

/// A kind of file, as a person would name it.
public enum Kind: Equatable, Hashable, Sendable {

    case image
    case video
    case audio
    case pdf
    case text
    case sourceCode
    case archive
    case spreadsheet
    case presentation
    case folder
    /// Any other uniform type identifier, passed through untouched.
    case other(String)

    /// The identifier Spotlight matches on.
    public var identifier: String {
        switch self {
        case .image: return "public.image"
        case .video: return "public.movie"
        case .audio: return "public.audio"
        case .pdf: return "com.adobe.pdf"
        case .text: return "public.text"
        case .sourceCode: return "public.source-code"
        case .archive: return "public.archive"
        case .spreadsheet: return "public.spreadsheet"
        case .presentation: return "public.presentation"
        case .folder: return "public.folder"
        case .other(let identifier): return identifier
        }
    }

    /// The names a caller can type.
    public static let names = ["image", "video", "audio", "pdf", "text", "code",
                               "archive", "spreadsheet", "presentation", "folder"]

    /// A kind for a word, or an identifier passed straight through.
    ///
    /// Anything containing a dot is taken to be a UTI already, which is what lets a caller
    /// reach the hundreds of types this enum does not name.
    public static func named(_ value: String) -> Kind {
        switch value.lowercased() {
        case "image", "images", "picture", "photo": return .image
        case "video", "videos", "movie", "movies": return .video
        case "audio", "sound", "music": return .audio
        case "pdf", "pdfs": return .pdf
        case "text", "txt": return .text
        case "code", "source", "sourcecode": return .sourceCode
        case "archive", "zip": return .archive
        case "spreadsheet", "sheet", "excel": return .spreadsheet
        case "presentation", "slides", "keynote": return .presentation
        case "folder", "directory", "dir": return .folder
        default: return .other(value)
        }
    }
}
