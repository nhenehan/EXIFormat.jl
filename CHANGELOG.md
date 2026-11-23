# Changelog

## Unreleased

- `Preserve.lexicalValues` ([EXI 6.3](https://www.w3.org/TR/exi/#fidelityOptions)),
  as in rexi with its `lexical-values` feature: every value is sent as its text,
  with the restricted character set of its built-in type
  ([EXI 7](https://www.w3.org/TR/exi/#encodingDatatypes), Table 7-2), so `1.50`
  decodes as `1.50`. Text is not changed by the whitespace facet, whitespace
  between elements is kept wherever a `CH` can take it, and `xsi:type` can name
  only a type in no namespace (a prefixed one needs Preserve.prefixes, as in
  EXIficient). The `exiformat` tool takes `--preserve lexicalValues`. The W3C
  strict group run again with the option on (`scripts/w3c-strict.py
  --lexical-values`): 173 of 219 give EXIficient's bytes and events, the same
  cases as rexi.
- Wildcards, as in rexi with its `wildcard` feature: `xs:any` and
  `xs:anyAttribute` in strict mode, `SE(*)`, `SE(uri:*)`, `AT(*)` and `AT(uri:*)`
  ([EXI 8.5.4.1.6](https://www.w3.org/TR/exi/#elementTerms)). An element follows
  its global declaration's grammar; one with no declaration still needs a
  built-in grammar and is refused. An attribute takes its global declaration's
  type, or is a string. The W3C wildcard cases give EXIficient's bytes and events
  (16 of 17): 177 of 219 in all, the same cases as rexi.
- Schema-informed fragments ([EXI 8.5.2](https://www.w3.org/TR/exi/#informedFragGrammars)),
  as in rexi 0.3.1: set the `fragment` option (`strict_options(; fragment = true)`)
  to encode and decode a run of root elements, each one any element the schema
  declares, global or local. `encode_xml` reads several roots when the option is
  set, `xml_fragment_events` reads a fragment into events, and `bin/exiformat`
  takes `--fragment`. A name declared twice with different types or `nillable`
  needs EXI's relaxed element grammar, which EXIFormat refuses with the new
  `FEATURE_RELAXED_ELEMENT_GRAMMAR`. The same bits as rexi, on rexi's tests and
  rexi-interop's case F1.
- A decoded enumeration value comes out in the standard form of its base
  type, as EXIficient and rexi give it: a float the schema lists as `1.0`
  decodes as `1E0`, not `1.0`
  ([EXI 7.2](https://www.w3.org/TR/exi/#encodingEnumerations) says only that the
  value is an index). The bytes do not change. Found by the W3C case
  enumeration.valid-02.
- For developers: `scripts/w3c-strict.py` (the same script as rexi's) runs the
  W3C test suite's strict group, 219 cases, against `bin/exiformat`, compared
  with EXIficient 1.0.7: 161 the same, the same cases as rexi. exi-testsuite is
  now pinned in `third-party.lock`, and exip moves to `fd43178` (its oracle has
  `--fragment`).

## 0.1.0

The first release as EXIFormat, and the first in Julia's General registry. The
version numbers start again with the new name: the JExi releases below (0.1.0
and 0.2.0, on GitHub only) are the same package's history. EXIFormat 0.1.0 has
everything JExi 0.2.0 had, plus:

- **Documentation** built with Documenter.jl and published at
  https://nhenehan.github.io/EXIFormat.jl: the manual (the former mdbook guide, now running its
  examples), an API reference for every public name, and an appendix. CI runs
  the tests on Julia 1.10 and the latest release, and builds the docs.
- **New name: EXIFormat** (it was JExi, up to JExi 0.2.0), so that it can be added to
  Julia's General registry. Write `using EXIFormat` and `EXIFormat.encode_xml`.
  The command line tool is `bin/exiformat`, and its environment variables and
  cache folder are `EXIFORMAT_*` and `~/.cache/exiformat`. Nothing else changes.
- `xsi:type` that names no type in the schema is no longer an error. The name is
  written, and the element keeps the grammar it has
  ([EXI 8.5.4.4.2](https://www.w3.org/TR/exi/#addingProductionsStrict)); decoding
  does the same. An `xsi:type` value whose prefix is not declared gives uri `""`
  and the whole value as the local name
  ([EXI 7.1.7](https://www.w3.org/TR/exi/#encodingQName)). Both match
  EXIficient; rexi made the same change in 0.3.1.
- `Pkg.test` works without the downloaded W3C text: the one test that needs it
  is skipped with a warning.
- For developers: the EXI options schema is no longer in the repository.
  `scripts/fetch-standards.sh` downloads the dated W3C Recommendation and takes
  the schema out of it, checked by sha256 against `standards.lock`.

## JExi 0.2.0

- The decoder checks the stream's `schemaId` option against the tables'
  ([EXI 5.4](https://www.w3.org/TR/exi/#options)), in `Decoder` and in
  `reset!`, and throws a `SchemaIdError` when they differ. An absent
  `schemaId` is not checked. `xsi:nil` (no schema) is always refused, since
  JExi's tables are schema-informed. `""` and any other id must equal the
  tables' id exactly, and tables with no id refuse a stream that names one.
  Tables compiled from XSD have no id: give them one with
  `with_schema_id(tables, id)` (the tables are shared, not copied) or the CLI's
  `--schema-id`. `check_schema_id` is the rule on its own. rexi applies the
  same rule.
- Restricted character sets
  ([EXI 7.1.10.1](https://www.w3.org/TR/exi/#restrictedCharSet)) are encoded
  and decoded instead of refused. The alphabet a string type's patterns allow
  is kept in the grammar tables, and each character of a new string value is
  written as an n-bit index into it, or as the escape index and the code
  point. The bytes equal EXIficient 1.0.7's,
  bit-packed and byte-aligned, on new test vectors (an ISO 3779 VIN pattern,
  escaped characters, non-ASCII alphabets, the empty alphabet, string-table
  hits, list items, `xs:token`, and two alphabets in one document). A
  character outside the BMP is one escaped code point, as the spec says;
  EXIficient writes it as two (see the README).
- A restricted string whose pattern does not parse still has no alphabet, and
  its values are still refused with
  `UnsupportedError(FEATURE_RESTRICTED_CHARACTER_SET)`.
- `restricted_string_kind(ws, alphabet)` takes the alphabet, and
  `SchemaGen` writes it. Tables generated before this change hold restricted
  kinds with no alphabet, which behave as before (refused); regenerate them.

## JExi 0.1.0

First release. JExi encodes and decodes schema-informed, strict EXI 1.0 in
native Julia. It is a port of [rexi](https://github.com/nhenehan/rexi) and
writes the same bytes as rexi and as EXIficient 1.0.7 on the interop test
cases. Anything outside the supported profile is refused with an
`UnsupportedError` (the list is in the README).

### Codec and supported EXI profile

- Strict, schema-informed EXI 1.0 (Second Edition), bit-packed or
  byte-aligned, with or without the `$EXI` cookie, with the options in the
  header or out of band.
- Every datatype of the strict profile, string tables, grammar tables, the EXI
  header and the options document.
- An `Encoder` (push) and a `Decoder` (pull) that work one event at a time.
  Plain text passed to `attribute!` or `characters!` for a typed datatype is
  parsed like XML text.
- `reset!(dec, bytes)` and `reset!(enc)` reuse a codec for the next document.
  A reset codec writes and reads the same bits as a new one, with about half
  the allocations. `reset!` itself allocates nothing.
- `event_qname_id(dec)` gives the current name as a `QNameId`, with no string
  lookup.
- XML front end over XML.jl: `encode_xml`, `decode_events`, `decode_to_xml`,
  `write_xml` and the `.events` text format. Encoding from XML streams
  through the tokenizer and builds no tree.

### Schemas

- An XSD compiler that handles `xs:include`, `xs:import`, groups, derived
  types, substitution groups and `xs:all`. Its tables equal rexi's for every
  test schema, and its EXIficient-format grammar dump equals EXIficient's.
- Include and import rules: `xs:include` and `xs:import` read only regular
  local files under the main schema's folder, at most 16 MiB each, and never
  a URL. Set the root with `load_options = SchemaLoadOptions(; root)` on
  `compile_files` and `compile_string`, or `--schema-root DIR` on the command
  line. A file outside the rules is refused with a `SchemaError` before it is
  opened.
- Size limits: a group that refers to itself is an invalid-schema error, and
  one type's content may expand to at most 100,000 grammar rules
  (`SchemaLoadOptions(; max_grammar_size)`). Past that, a `SchemaError` says
  "schema too large".
- Pattern refusal: a string type whose `xs:pattern` allows only a small
  alphabet is a restricted character set
  ([EXI 7.1.10.1](https://www.w3.org/TR/exi/#restrictedCharSet)). Its values
  are refused with `UnsupportedError(FEATURE_RESTRICTED_CHARACTER_SET)`.
  Wildcards (`xs:any`, `xs:anyAttribute`) are refused with
  `UnsupportedError(FEATURE_WILDCARD)`. In both cases the schema still
  compiles, and only a document that uses that part is refused.

### Safety: decoder limits

- `DecodeLimits`, on by default: depth 256, 1,000,000 list items, 4096-bit
  integers and 256 MiB strings. A stream past a limit stops with a
  `LimitError`. `unlimited_limits()` turns them off.
- A `limits` keyword on `Decoder`, `decode_events`, `decode_to_xml` and
  `from_exi`.
- Big integers and mixed-content text are read in linear time.

### Structs and SchemaGen

- `to_exi` and `from_exi` map your own Julia structs to EXI, with the same
  rules as rexi's serde mapping: attributes or elements, `Vector` for repeats,
  `Union{Nothing,T}` for optional parts, `@enum`, choices and `xsi:type`.
- `Float32` and `Float16` fields are written as the shortest text at their own
  width.
- `JExi.SchemaGen` writes grammar tables as a Julia module, so they
  precompile into the package that includes them.

### Command line

- `bin/jexi` takes the same commands and flags as rexi's command line:
  `encode`, `decode`, `dump-events`, `dump-grammar` and `bench`.
- `--max-depth`, `--max-list-items`, `--max-integer-bits`,
  `--max-string-bytes` and `--no-limits` on `decode`, `dump-events` and
  `bench decode`.

### Docs and examples

- A user guide in `guide/` (mdbook) that walks through the examples one at a
  time, with a chapter on untrusted input.
- Small examples in `examples/basics`, one idea each. Each has a Rust twin in
  rexi that prints the same output.
- Speed and allocation numbers in `doc/performance.md`.
