# Working on EXIFormat

## Status

0.1.0 has the scope of rexi 0.2, plus rexi 0.3.1's handling of an `xsi:type`
that names no type in the schema. rexi 0.3 also encodes schema-informed
fragments; EXIFormat does not yet.

The interop fixtures (EXIficient 1.0.7 reference bytes) encode bit for bit in
the strict bit-packed, bit-packed with options, and byte-aligned profiles. They
decode to EXIficient's event stream, re-encode from the decoded events, and are
accepted by exipd, exip's decoder. The schema compiler makes the same tables as
rexi for every fixture schema, and its EXIficient-format grammar dump equals
EXIficient's. In the [rexi-interop](https://github.com/nhenehan/rexi-interop)
matrix, EXIFormat matches rexi in every strict case. Wildcards are refused with
`UnsupportedError(FEATURE_WILDCARD)`, and restricted strings whose pattern does
not parse with `UnsupportedError(FEATURE_RESTRICTED_CHARACTER_SET)`.

## Layout

One package with the layers of rexi's crates:

| Part | Files | rexi crate |
|---|---|---|
| Codec core: bit I/O, datatypes, string tables, grammar tables and runtime, `Encoder` / `Decoder`, header and options document | `src/core/` | `rexi-core` |
| XSD compiler: loader, resolver, proto-grammars, normalization, emit; EXIficient-format grammar dump | `src/schema/` | `rexi-schema` |
| Static tables written as a Julia module (`EXIFormat.SchemaGen`) | `src/schemagen.jl` | `rexi-schema-gen` |
| XML front end over XML.jl: namespace-aware reader, writer, `.events` dump | `src/xml/` | `rexi-xml` |
| Struct mapping: `to_exi` / `from_exi` (the rules are in `?EXIFormat.to_exi`) | `src/structs/` | `rexi-serde` |
| Command line (`bin/exiformat`, `EXIFormat.CLI`) | `src/cli.jl` | `rexi` binary |

Grammar tables (`GrammarSet`) are flat vectors of plain bits structs indexed by
0-based ids, like rexi's, so a table written by `SchemaGen` is a constant that
precompiles into the package that includes it.

## Commands

```bash
scripts/fetch-third-party.sh --build   # exip (exipd, EXIficient oracle) and rexi, pinned
scripts/fetch-standards.sh [--check]   # W3C EXI 1.0 (dated REC) and its Appendix C schema, by sha256
scripts/sync-fixtures.sh [--check]     # fixtures and rexi's grammar listings, from the pinned rexi
scripts/gen-tables.sh [--check]        # static tables in test/generated
scripts/gate.sh [--quick]              # everything a commit must pass
bin/exiformat encode --xsd a.xsd in.xml out.exi
bin/exiformat decode --xsd a.xsd [--max-depth N ... | --no-limits] out.exi
bin/exiformat dump-grammar --xsd a.xsd[,b.xsd]
bin/exiformat bench encode|decode --xsd a.xsd [--warmup N --iterations N] in
```

`bin/exiformat` takes rexi 0.2's command line (rexi 0.3 adds `--fragment`) and
prints the same `bench` JSON, which is how the
[rexi-interop](https://github.com/nhenehan/rexi-interop) harness drives both.
Speed notes are in the docs appendix ([`docs/src/appendix/performance.md`](docs/src/appendix/performance.md)).

## Julia versions

1.10 (LTS) and newer. The gate runs the tests, with Aqua and JET, on Julia 1.10
(juliaup channel `lts`; set `EXIFORMAT_JULIA_LTS`) and on a current Julia
(channel `1.12`; set `EXIFORMAT_JULIA_CURRENT`), then checks the generated
tables and the fixtures. The full gate needs the judges (exipd, exip's test
data); `--quick` runs only the current Julia.

## Tests and the downloaded standard

Some tests compare against the EXI options schema from the W3C Recommendation.
It is never committed: `scripts/fetch-standards.sh` downloads it into
`${EXIFORMAT_STANDARDS:-${XDG_CACHE_HOME:-~/.cache}/exiformat/standards}`. Without it,
`Pkg.test("EXIFormat")` skips those tests with a warning. The gate sets
`EXIFORMAT_REQUIRE_JUDGES=1`, which makes them required.

## Docs

The documentation is built with [Documenter.jl](https://documenter.juliadocs.org/)
from `docs/`, and published to https://nhenehan.github.io/EXIFormat.jl: `/dev` from `main`, `/stable` from the
latest version tag. The `docs` job of `.github/workflows/CI.yml` builds and
deploys it.

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'   # once
julia --project=docs docs/make.jl                        # writes docs/build
```

- `docs/src/manual` holds the chapters. Their code comes from the scripts in
  `examples/basics`: a fenced block holding `#! include roundtrip.jl main`
  gets that script's `# ANCHOR: main` region, and `#! setup roundtrip.jl` the
  script's imports, for a hidden `@setup` block. Documenter runs the
  `@example` blocks, so the pages always show the scripts' real output. Never
  paste code or output into a page.
- `docs/src/api` lists every public name in `@docs` blocks. EXIFormat has no
  exports, so a new public name must be added there by hand; the build fails
  when a listed name has no docstring or a cross-reference does not resolve.
- Deploying needs the `DOCUMENTER_KEY` secret and its deploy key (made once with
  `DocumenterTools.genkeys`).

## Reference fixtures

`test/fixtures/interop` is a copy of rexi's `crates/rexi-tests/fixtures/interop`
at the commit pinned in `third-party.lock`: EXIficient 1.0.7 bytes, decoded
event streams and grammar dumps, with their sha256 in `manifest.tsv`.
`test/fixtures/listings` holds `rexi dump-grammar` for each case, which
`EXIFormat.grammar_listing` must reproduce exactly. Change them only with
`scripts/sync-fixtures.sh` after moving the pin.

## W3C strict group

`scripts/w3c-strict.py` runs the W3C test suite's strict group
(`config/testCases-interop/strict.xml`: schemaValidDatatypes and
declaredProductions, 219 cases) from the cached exi-testsuite, with
`bin/exiformat`. For each case, on bit-packed and byte-aligned, EXIficient (the
oracle jar) makes the reference stream and its events; EXIFormat's encode must
give the same bytes, its decode the same events, and decode then encode the same
bytes again. It is the same file as rexi's `scripts/w3c-strict.py`: keep the two
copies the same. It is not part of the gate, because it starts Julia for every
step (about 6 minutes with 8 jobs).

```bash
scripts/w3c-strict.py --jobs 8               # compare with scripts/w3c-strict.expected
scripts/w3c-strict.py --jobs 8 --update      # on purpose: accept the new results
```

The run fails when a result differs from `scripts/w3c-strict.expected`, both
when a case stops passing and when one starts.

## Third parties

Nothing third-party lives in the working tree. `scripts/fetch-third-party.sh`
checks out the commits pinned in `third-party.lock` (exip for the exipd judge
and the EXIficient oracle, rexi for the fixtures and its CLI, exi-testsuite for
`scripts/w3c-strict.py`) into
`${EXIFORMAT_THIRD_PARTY:-${XDG_CACHE_HOME:-~/.cache}/exiformat/third_party}`.
Julia dependencies: XML.jl and PrecompileTools; the tests also use Aqua and JET.
