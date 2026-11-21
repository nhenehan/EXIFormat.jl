# AGENTS.md

## About this project

EXIFormat is an implementation of W3C Efficient XML Interchange (EXI) 1.0 in native Julia. It is a port of [rexi](https://github.com/nhenehan/rexi), the Rust implementation, and must write the same bytes. It was called JExi up to JExi 0.2.0; numbering started again at 0.1.0 as EXIFormat, and JExi's old tags are deleted.

It encodes and decodes XML using schema-informed, strict EXI. Both communicating ends must use compatible schema grammars and EXI options.

It is one package, `EXIFormat`, with no exports: write `EXIFormat.name`. Its only dependencies are XML.jl and PrecompileTools. Use the parts it already has rather than adding another encoding, schema or XML layer.

## Package layout

| If you need to... | Look in | rexi crate it matches |
|---|---|---|
| Encode or decode EXI events | `src/core/` (`Encoder`, `Decoder`, grammar tables, string tables, header) | `rexi-core` |
| Compile an XSD at runtime | `src/schema/` (`compile_files`, `compile_string`, `grammar_listing`) | `rexi-schema` |
| Generate grammar tables ahead of time | `src/schemagen.jl` (`EXIFormat.SchemaGen`) | `rexi-schema-gen` |
| Convert XML text to and from EXI | `src/xml/` (`encode_xml`, `decode_to_xml`, `decode_events`, `xml_events`) | `rexi-xml` |
| Encode or decode Julia structs | `src/structs/structs.jl` (`to_exi`, `from_exi`) | `rexi-serde` |
| Run from the command line | `src/cli.jl` (`EXIFormat.CLI`), `bin/exiformat` | the `rexi` binary |

## Choosing an interface

### XML input and output

Use `encode_xml` and `decode_to_xml` when the application works with XML documents. The normal workflow is:

1. Compile the XML Schema with `compile_files` or `compile_string`.
2. Keep the resulting `GrammarSet` and reuse it for every message.
3. Pick the options (`strict_options(; ...)`) and header settings (`HeaderConfig`).
4. Encode, and decode with the same tables and options.

See `examples/basics` and the manual in `docs/src/manual`.

### Julia structs

Use `to_exi` and `from_exi` when the application already has Julia types. The schema decides the XML structure: element names, attributes, namespaces, choices and value types. The rules are in the `to_exi` docstring. Overrides are traits: `exi_name`, `exi_names`, `exi_rename_all`, `exi_choices`, `exi_xsi_type`.

### Low-level encoding

Use `Encoder` (push: `start_document!`, `start_element!`, `attribute!`, `characters!`, `end_element!`, `end_document!`, `finish!`) and `Decoder` (pull: iterate it, or `next_event!`) when working directly with events. `reset!` reuses a codec without allocating. Prefer these over writing another encoder or decoder.

### Static grammar tables

`SchemaGen.generate` writes a schema's tables as a Julia module that precompiles into the package that includes it. Use `check = true` to compare the written tables with a fresh compile. Never edit generated files by hand; regenerate them (`scripts/gen-tables.sh` for the ones in `test/generated`).

## EXI rules

The implemented profile is EXI 1.0 (Second Edition), schema-informed and strict, for documents and fragments.

Supported:

- Bit-packed and byte-aligned.
- With or without the `$EXI` cookie.
- Options in the header or agreed out of band.
- Restricted character sets whose `xs:pattern` can be parsed.
- An `xsi:type` that names no type in the schema: written, and the element keeps its grammar (as EXIficient and rexi 0.3.1 do).
- Schema-informed fragments (`fragment = true`, as rexi 0.3.1): any number of root elements, each any element the schema declares, global or local.

Refused with `UnsupportedError` (`src/core/errors.jl`, `validate_options` in `src/core/options.jl`): compression and pre-compression, a fragment-level name declared twice with different types or `nillable` (relaxed element grammars), wildcards (`xs:any`, `xs:anyAttribute`), schema-less streams (built-in grammars), non-strict mode, the Preserve options, selfContained, datatypeRepresentationMap, and restricted strings whose pattern does not parse.

Both ends must agree on the schema and the options. Do not silently substitute a different encoding for an unsupported feature. Do not assume that a schema that compiles can encode every document that uses it: the refusal comes when a document reaches the unsupported part.

Report only what the tests show. Of the W3C EXI test suite, EXIFormat runs only the strict group (`scripts/w3c-strict.py`, expected results in `scripts/w3c-strict.expected`), the same script as rexi's.

## Allocations and type stability

The hot paths are kept free of runtime dispatch and most allocations:

- `test/performance.jl` holds allocation budgets for per-stream setup, whole documents and reused codecs. Do not raise a budget without a measured reason.
- JET's `@test_opt` must find no runtime dispatch in decoding a whole document (`test/performance.jl`); `test/quality.jl` runs `JET.test_package`.
- JET on Julia 1.12 flags a `Union{Nothing,...}` field read twice: bind it to a local first.

## Error handling and unsupported features

Unsupported EXI functionality must fail explicitly. Use the existing `ExiError` subtypes (`UnsupportedError`, `GrammarError`, `ValueError`, `SchemaError`, `HeaderError`, `SchemaIdError`, `LimitError`, `MappingError`, ...). `XmlSyntaxError` is the one error that is not an `ExiError`, because the problem is in the XML.

Do not:

- Ignore an unsupported feature.
- Encode a different representation without telling the caller.
- Accept invalid data because another implementation happens to decode it.
- Weaken validation to make an interoperability test pass.

If a restricted character set's alphabet cannot be worked out, do not encode the value as a plain string: another EXI implementation would read those bytes differently.

## Security

Treat EXI streams and XML Schemas as untrusted input. Do not remove or weaken:

- The `DecodeLimits` defaults: depth 256, list items 1,000,000, integer bits 4096, string bytes 256 MiB (`src/core/limits.jl`).
- The `SchemaLoadOptions` rules: includes and imports only under the root, regular files of at most 16 MiB, `max_grammar_size = 100_000`, and the production cap while tidying grammars (`src/schema/loader.jl`, `src/schema/proto.jl`).
- Circular group detection.

Changes to these limits or how they are enforced need tests.

## Interoperability

Interoperability is the core requirement. EXIFormat's bytes must equal EXIficient 1.0.7's and rexi's, bit for bit, in the bit-packed, bit-packed-with-options and byte-aligned profiles. Decoded events must equal EXIficient's. `grammar_listing` must equal `rexi dump-grammar` (`test/fixtures/listings`). exipd, exip's decoder, must accept the output.

`test/fixtures` is only ever copied from the rexi commit pinned in `third-party.lock`, by `scripts/sync-fixtures.sh` (sha256 checked against `manifest.tsv`). Never edit the fixtures by hand, and never regenerate them to make a test pass. To change them, move the rexi pin and sync.

A change in encoding or decoding behaviour should land in rexi and EXIFormat together, with the same tests.

## Development conventions

Before changing an interface or implementation:

1. Read the relevant part of `src/` and its docstrings.
2. Check the manual and the examples.
3. Keep the same layering as rexi's crates.
4. Prefer extending an existing function over adding a parallel one.
5. Add tests for both the supported behaviour and the failure cases.

Do not invent functions, keyword arguments or error types. Check the source before using them.

Write comments in plain, everyday words, and link the EXI specification section (`https://www.w3.org/TR/exi/#...`) where code follows the spec. Julia closures share outer locals assigned anywhere in the function: use `local` in nested helpers.

## Testing

Read `CONTRIBUTING.md` for the full procedure. In short:

1. `scripts/fetch-third-party.sh --build` (exip and rexi, pinned) and `scripts/fetch-standards.sh` (the W3C options schema), once.
2. `scripts/gate.sh` before every commit: the standards check, `Pkg.test` with Aqua and JET on Julia 1.10 and 1.12, `scripts/gen-tables.sh --check` and `scripts/sync-fixtures.sh --check`. It sets `EXIFORMAT_REQUIRE_JUDGES=1`, so tests that need exipd or the downloaded standard fail instead of skipping.
3. `scripts/gate.sh --quick` runs only the tests on the current Julia.

Check the gate's exit status itself; do not pipe it through `grep` and read the output.

Changes to encoding or decoding need interoperability tests (reference bytes and events), not just unit tests. Changes to schema handling need tests for both accepted and refused schemas.

## Documentation

Keep the README about what EXIFormat does and how to use it. Keep development, testing and maintenance steps in `CONTRIBUTING.md`.

Update the docs (`docs/`, Documenter.jl) when a public function or user-facing behaviour changes: the manual in `docs/src/manual`, and the API reference in `docs/src/api`, which lists every public name by hand (EXIFormat has no exports). Every public name needs a docstring that starts with its signature. Manual pages take their code from `examples/basics` with `#! include` lines (see `docs/make.jl`); never paste code or output into them. Each example in `examples/basics` has a twin in rexi's `examples/basics` that prints the same output; rexi's `examples/basics/compare.sh` checks them. Keep both in step.

Prefer direct technical explanations over marketing language.

## Repository rules

- Never commit `CR.md` (change requests are instructions, not project files), `Manifest.toml`, third-party code, or text and schemas copied from W3C standards. Link them, and fetch them with `scripts/fetch-standards.sh` (checked by `standards.lock`).
- Third-party checkouts live in `${EXIFORMAT_THIRD_PARTY:-${XDG_CACHE_HOME:-~/.cache}/exiformat/third_party}`, never in the working tree.
