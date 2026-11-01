# ModelsAgent

An app's own domain types, written as Swift from one compact line a type, shipped as a
[Granite](https://github.com/riteshpakala/Granite) agent package. A call says each type the way a person would jot it
down; the package writes a file a type into the folder the call names, each one `Codable`, `Hashable` and `Sendable`,
`Identifiable` when it has an `id`, with an explicit initializer and a `preview` value for SwiftUI previews and tests.

It is one of the [Rao Craft Agents](https://github.com/Rao-Craft-Agents): independent packages that, tagged in prompts
along the life of a project, build an app of [Loom](https://github.com/riteshpakala/Loom)'s quality. `models` writes
the values every other layer shares: the records a service keeps, the choices a setting offers, and one type that
unifies several APIs' types.

## How an app finds it

ModelsAgent is a `GraniteAgentPackage`, and it carries a record in its binary:

```swift
@used @section("__DATA_CONST,__granite")
let modelsRecord: GraniteRoster.Record = { GraniteRoster.record(ModelsAgent.self) }
```

In [Craft](https://github.com/riteshpakala/Craft), install it from the Agent Store or with
`craft agents add https://github.com/Rao-Craft-Agents/ModelsAgent.git`, then say `$models` in a request:

```
$models the recipe app's types: a Recipe with an id, title, minutes (30 by default), its cook,
its steps and tags; a Cook; a Step; and a Course that is a starter, main or dessert
```

The model writes the lines; the call shows on Craft's agent map as `models-1`, and the files it names are built and
tested with the turn.

## What a call takes and answers

| Field | | |
|---|---|---|
| `entities` | optional | one line a type (below) |
| `unify` | optional | one line a type made from another API's: `FederatedPost from LemmyPost: id = String(post.id), title = post.name` |
| `into` | optional | the folder, relative to the project; `Shared/Models` when left out |
| `access` | optional | `public` for a package's types; `internal` when left out |
| `coding` | optional | `snake` for snake_case JSON keys; `exact` when left out |
| `imports` | optional | modules to import beside Foundation (where a unify line's source type lives) |
| `previews` | optional | whether each type gets a `preview` value; true when left out |
| `directory` | the host's | the folder the host works in; a host fills it and does not show it to a model |

The answer is a `ModelsResult`: every file written (`path`, `paths`, absolute), the types, which have a preview, and a
sentence for anything left out.

## The line

```
Recipe "a dish someone saved": id String, title String, minutes Int = 30, author Cook?, steps [Step], added Date
Cook: id UUID, name String, avatar URL?, recipes [Recipe] = []
Course: starter | main | dessert = "pudding"
Media: photo(URL) | video(url URL, seconds Double) | none
```

- A struct is a name, an optional doc in quotes, a colon, and its fields split by commas. A field is a name and a type;
  `?` makes it optional, `= value` gives a default, `@json_key` names its JSON key, a trailing quoted string
  documents it. `title: String` reads the same as `title String`, and `string`, `int`, `bool`, `url` and `date` are
  read as the Swift types.
- An enum is its cases split by bars. A case may carry values (`video(url URL, seconds Double)`) or have a raw value
  (`= "pudding"`, `= 2`), never both in one enum. `enum Size: small, large` says enum when there is one case or
  commas.
- A line it cannot read is refused with the reason, every bad line at once, and nothing is written.

## How the types are made

| Step | What |
|---|---|
| Read | every line parsed; a refused line names its reason |
| Write | a file a type: the doc comment, the conformances, the fields, an initializer with every default |
| Decode | a field with a default decodes as the default when the JSON leaves it out (a hand-written `init(from:)`, only when one is needed), so a persisted store keeps reading after a field is added |
| Preview | a `preview` value from samples a field's name suggests; a type of this call is named by its preview, and an optional or a collection names another type's preview only when that cannot loop back, since two static values that read each other deadlock |
| Unify | an `init(_ source:)` from the other API's type, its arguments in the target's order (read off its file when an earlier call wrote it); a target field with no default and no value is refused |
| Check | every file staged, parsed with `swiftc -parse`, then moved into the project together |

No model is asked: the same lines make the same files every time.

## Testing

```
swift test                    # the record, the schema, the line, the files, a call through the roster
MODELS_BUILD=1 swift test     # the files compiled in a package and run: JSON missing every default decodes
```

MIT licensed.
