//
//  Scope.swift
//  Spotlight
//
//  Created by David Sherlock on 2026.
//
//  Where to look.
//
//  A scope is a directory path or one of Spotlight's own constants. The constants are worth
//  having because "my home directory" is a question the index answers faster than a path does.
//

import Foundation

/// Somewhere to search.
public enum Scope {

    /// Everywhere indexed on this machine.
    public static let everywhere: [String] = []

    /// The user's home directory.
    public static let home = [NSMetadataQueryUserHomeScope]

    /// Everything indexed on local volumes.
    public static let local = [NSMetadataQueryLocalComputerScope]

    /// A directory, with `~` expanded and the path made absolute.
    ///
    /// Relative paths are resolved against the working directory, so `spotlight … --in .`
    /// means what it looks like.
    public static func path(_ value: String) -> String {
        let expanded = (value as NSString).expandingTildeInPath
        guard !expanded.hasPrefix("/") else { return (expanded as NSString).standardizingPath }
        let cwd = FileManager.default.currentDirectoryPath
        return ((cwd as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
    }
}
