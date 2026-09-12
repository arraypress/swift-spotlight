# swift-spotlight

Ask macOS's own file index a question, from Swift.

Spotlight has been indexing this machine since it was set up and keeps doing it whether
anything asks or not. So the whole job is phrasing a question and reading the answer — which
is why a content search over a whole home directory comes back in **0.6 s** where `grep -r`
walks the disk for minutes. The work was already done.

```swift
import Spotlight

// Inside files, not in their names.
let hits = try Index.search(Query(content: "blockQuoteLevel", scopes: Scope.home, limit: 20))

// By name, newest first.
let recent = try Index.search(Query(name: "*.swift", scopes: [Scope.path("~/Developer")]))

// By kind and date.
let shots = try Index.search(Query(type: Kind.image.identifier,
                                   changedAfter: .now.addingTimeInterval(-86_400)))
```

## Measured

| | |
|---|---|
| `blockQuoteLevel` inside every file in a home directory | **0.63 s**, 6 hits |
| `*.swift` across a home directory | **0.09 s**, 7,924 hits |
| images changed in the last day | **0.06 s** |

## What Spotlight cannot see

This is the part worth reading before depending on it.

**Group Containers are not indexed.** `~/Library/Group Containers` is outside the index
entirely — `mdutil` reports *"unknown indexing state"* for it. Measured directly: a file
written there is unfindable by name or by content, while the same file in
`~/Library/Application Support` is found within seconds. That is where sandboxed apps keep
their data, so Apple Notes' database, Mail's store and the rest are invisible here. Nothing
in this library can fix that; walking the filesystem is the only way in.

There is a test asserting this stays true, so if Apple ever changes it, the docs get corrected
rather than quietly becoming wrong.

Also invisible: anything on the user's Spotlight privacy list, and the *contents* of file
types with no content importer — for those the name is indexed and the inside is not.

## Two things that bite

**The run loop is not optional.** `NSMetadataQuery` reports through notifications, so a caller
that starts one and returns gets nothing. It works fine in a command-line process with no GUI
— verified before any of this was written — but only if something pumps the run loop until the
answer arrives. `Index.search` is synchronous outside and a run loop inside.

**Do not call `enableUpdates()` before starting.** It reads like the right way to say "give me
a snapshot, not a live feed". What it actually does is stop the gathering notification ever
arriving, so every query times out. Written that way once, from reasoning rather than
measurement, and it cost a thirty-second timeout on a search that takes a tenth of a second.

## Shape of a query

Every part is optional and they combine with `AND`:

| | |
|---|---|
| `name` | a filename **glob** — `*.swift`, `Screenshot*`. Not a regex; that is what Spotlight takes |
| `content` | words inside the file |
| `type` | a uniform type, matched as a **tree** — `public.image` catches PNG and JPEG both |
| `changedAfter` / `changedBefore` | a date range |
| `largerThan` | bytes |
| `raw` | a `kMDItem…` predicate, for the attributes this shape has no field for |

An empty query is refused rather than run: it would match every file on the machine, which is
never what anybody meant and is a slow way to find that out.

`Match` carries only what **every** file has — path, name, size, type, kind, dates — so a
result set is rectangular and a caller never tests whether a field exists. Camera, GPS,
duration, page count and the rest live in `attributes`, collected only when asked for.

## Requirements

macOS 14+, Swift 6.2. Foundation only — nothing vendored, nothing fetched, no index of its own.

## Tested

26 tests. Most need no index at all: a predicate is a value, so what it says can be read back,
which matters because the index holds whatever this machine happens to contain and anything
asserting on real results elsewhere would pass or fail by accident.

The few that must touch the index search **this package's own files**, and *skip* rather than
fail when it cannot answer — a machine mid-reindex is not a broken library, and a test that
fails for a reason the code cannot cause teaches the reader to ignore it.

Mutation-verified: matching the content type exactly instead of its tree, treating a name as a
regex, ignoring the limit, accepting an empty query, skipping the scope check, or sorting
newest-first backwards each fail the suite.

## Licence

MIT.
