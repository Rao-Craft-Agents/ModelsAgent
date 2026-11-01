import GraniteAgents

/// The models agent's place in Granite's roster: an app that links this package finds the `models` agent by this
/// record, with nothing listed by hand.
@used @section("__DATA_CONST,__granite")
let modelsRecord: GraniteRoster.Record = { GraniteRoster.record(ModelsAgent.self) }
