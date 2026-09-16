# Preset Schema

Presets are JSON objects with `schemaVersion: 1`. The canonical definition is `shared/contracts/preset.schema.json`.

`output.strategy` distinguishes `fixedQuality` from `targetBytes`. Fixed quality applies one quality value and makes no byte promise. Target bytes measures every encoded candidate and returns the highest quality that fits the safety target. Final validation uses the hard target.

`targetBytes` is literal bytes. The built-in 150KB preset stores `150000`; it does not use 153600 or an ambiguous binary unit. `safetyTargetBytes` must be positive and no greater than `targetBytes`.

System presets are read-only. Editing one produces a user copy with a new stable ID. Imported presets are decoded as data, validated, and never execute paths or code. Unknown JSON fields are permitted by the schema so another platform can preserve future extensions.

Future migrations must decode the old document, construct a new document, validate it, and atomically write a separate replacement. A failed migration retains the original bytes.
