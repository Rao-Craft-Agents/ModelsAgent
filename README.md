# ModelsAgent

Write the value types an app is built on the way you would jot them down. Say a recipe has an id, a title, minutes
that default to 30, a cook and its steps, and `models` writes a Swift file for each type, ready to save, send, compare
and show in a preview. It is for the records a service keeps, the choices a setting offers, and one type that brings
several APIs' types together.

## What you can ask

```
$models the recipe app's types: a Recipe with an id, title, minutes (30 by default), its cook, its steps and tags
$models a Cook, a Step, and a Course that is a starter, main or dessert
$models a FederatedPost made from LemmyPost, its id from the post's id and its title from its name
$models the package's types, public, with snake_case JSON keys
```

Craft writes the lines from your request, shows the call on its agent map as `models-1`, and builds and tests what it
writes with the turn.

## What you get

- **A file for each type.** Structs and enums with their doc comments, the fields you named and an initializer with
  every default, in `Shared/Models` or the folder you name.
- **Ready for JSON and SwiftUI.** Every type is `Codable`, `Hashable` and `Sendable`, `Identifiable` when it has an
  `id`, and `CaseIterable` when an enum carries nothing; keys in `snake_case` when you ask, or a key of its own for a
  field.
- **Saved data that keeps loading.** A field with a default decodes as the default when the JSON leaves it out, so a
  store written before you added the field still reads.
- **A preview on every type.** A `preview` value from samples a field's name suggests, for SwiftUI previews and
  tests, made so that no two previews read each other in a loop.
- **One type from another API's.** A unify line writes an initializer that makes your type from another API's type,
  one assignment a field.

## How it works

- It asks no model: the same lines make the same files every time.
- A line it cannot read is refused with the reason, every bad line at once, and nothing is written; so is a unified
  field with no default and no value.
- Every file is parsed with `swiftc -parse` before any lands, and they land together. What it makes is built and
  tested with the turn.

## Works well with

`models` writes the values every other layer shares. The services and pages `granite` makes keep them, `network`
writes its API's own request and response types in the same line, and `loom` shows the app's types as posts,
comments, people and communities.

## Get it

In Craft, install Models from the Agent Store, or run
`craft agents add https://github.com/Rao-Craft-Agents/ModelsAgent.git`, then say `$models` in a request.

## Requirements

- A Mac on macOS 14 or later, with Xcode.
- The types are plain Swift on Foundation, importing only the modules you name (such as the one a unify line's source
  type is in).
- MIT licensed.

## For developers

What a call takes and answers, the line it reads and how the types are made are in the
[reference](Docs/Reference.md). It follows Granite's agent standard,
[Schema/GraniteAgent.md](https://github.com/riteshpakala/Granite/blob/main/Schema/GraniteAgent.md), and how it is
measured is [TESTING.md](TESTING.md).
