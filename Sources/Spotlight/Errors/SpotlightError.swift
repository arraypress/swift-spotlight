//
//  SpotlightError.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong asking the index a question.
public enum SpotlightError: Error, Equatable, Sendable {

    /// The query was rejected before it started. Almost always a malformed raw predicate.
    case queryRefused(String)

    /// The index did not answer in time.
    ///
    /// Not a failure of the query so much as of the machine: Spotlight is rebuilding, or the
    /// scope is a volume that has to be woken. The timeout is the caller's to raise.
    case timedOut(seconds: Double)

    /// A scope that is not a directory, or does not exist.
    case badScope(String)
}

extension SpotlightError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .queryRefused(let detail):
            return "Spotlight refused the query: \(detail)"
        case .timedOut(let seconds):
            return "Spotlight did not answer within \(Int(seconds))s"
        case .badScope(let path):
            return "Not a directory to search: \(path)"
        }
    }
}
