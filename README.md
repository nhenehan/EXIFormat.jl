# EXIFormat.jl

*EXI (Efficient XML Interchange) for Julia: small, fast binary XML from your XML Schema.*

[![docs-stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://nhenehan.github.io/EXIFormat.jl/stable)
[![docs-dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://nhenehan.github.io/EXIFormat.jl/dev)
[![CI](https://github.com/nhenehan/EXIFormat.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/nhenehan/EXIFormat.jl/actions/workflows/CI.yml)

EXIFormat turns XML into small, fast binary messages and back. The format is EXI,
a W3C standard. You give EXIFormat your XML Schema. Both ends use it to agree on
the structure and types of the data, so names and other things the schema
already says don't need to be repeated in every message. In the manual's
example, 538 bytes of XML become 129 bytes of EXI.

EXIFormat is the Julia version of [rexi](https://github.com/nhenehan/rexi), and
writes the same bytes. Up to version 0.2.0 it was called JExi.

**Supported profile:** EXI 1.0 (Second Edition), schema-informed, strict,
bit-packed or byte-aligned, with or without the `$EXI` cookie, and options in the
header or agreed out of band (the smallest form has a one-byte header). Whole
documents.

## Installation

The package can be installed with Julia's package manager. In the Pkg REPL (press
`]` to enter it):

```
pkg> add EXIFormat
```

or with Pkg functions: `using Pkg; Pkg.add("EXIFormat")`. EXIFormat needs Julia
1.10 or newer. It has no exports, so every name is written `EXIFormat.name`.

## Quick example

With [`order.xsd`](examples/basics/data/order.xsd) and
[`order.xml`](examples/basics/data/order.xml) from `examples/basics/data` in the
current folder:

```julia
import EXIFormat

# Turn the schema into tables once, then reuse them for every message.
tables = EXIFormat.compile_files("order.xsd")
xml = read("order.xml", String)

options = EXIFormat.strict_options()
exi = EXIFormat.encode_xml(xml, tables; options)       # XML to EXI
back = EXIFormat.decode_to_xml(exi, tables; options)   # and back again

println(sizeof(xml), " bytes of XML became ", length(exi), " bytes of EXI")
println(back)
```

It prints `538 bytes of XML became 129 bytes of EXI`, then the XML.

## Learn more

- **[The documentation](https://nhenehan.github.io/EXIFormat.jl/stable)** has a manual that works through one small
  example per idea, from a first round trip to prebuilt tables, and an API
  reference for every public name.
- **[`examples/basics`](examples/basics/README.md)** contains the manual's
  scripts. Each has a Rust twin in rexi that prints the same output.
- **The command line** encodes and decodes files and lists a schema's grammars:
  `bin/exiformat --help` in a clone, or
  `julia -e 'using EXIFormat; exit(EXIFormat.CLI.main(ARGS))' -- --help` with the
  package installed.

## EXI 1.0 implementation

What the codec can encode and decode.

| EXI feature | Status | Notes |
|---|---|---|
| Schema-informed grammars | Supported | Compiled from XML Schema, with `xs:include`, `xs:import`, groups, derived types, substitution groups and `xs:all` |
| Strict mode | Supported | Documents must match the schema |
| Bit-packed encoding | Supported | |
| Byte-aligned encoding | Supported | |
| EXI header | Supported | Optional `$EXI` cookie; options document in the header |
| Out-of-band options | Supported | |
| Restricted character sets | Partial | When the `xs:pattern` alphabet can be read |
| Fragments | Not supported | `fragment = true` is refused (rexi 0.3 has them) |
| Schema-less / built-in grammars | Not supported | |
| Non-strict mode | Not supported | |
| Compression | Not supported | |
| Pre-compression | Not supported | |
| Wildcards | Not supported | `xs:any`, `xs:anyAttribute` |
| `Preserve.lexicalValues` | Not supported | |
| `datatypeRepresentationMap` | Not supported | Uses standard datatype representations |
| `xs:redefine`, `xs:override`, `xs:notation` | Not supported | Refused when the schema is compiled |
| Preserve comments, PIs, DTD, prefixes | Not allowed in strict mode | EXI forbids them together with `strict` ([EXI 5.4](https://www.w3.org/TR/exi/#options)) |
| `selfContained` | Not allowed in strict mode | Same rule |

Every "Not supported" or "Not allowed" row fails with an `UnsupportedError` that
names the feature. EXIFormat never quietly writes something "close enough". A
schema that uses a wildcard or an unreadable pattern still compiles; only
documents that use that part are refused.

For restricted character sets, EXI has a compact form when an `xs:pattern` limits
a string to fewer than 256 characters
([EXI 7.1.10.1](https://www.w3.org/TR/exi/#restrictedCharSet)). EXIFormat uses it
when it can read the alphabet, and its bytes equal EXIficient 1.0.7's, except for
a character outside the BMP, which EXIficient counts as two UTF-16 units. When a
pattern can't be read, values of that type are refused rather than guessed.

## Julia library features

| Feature | Names | Description |
|---|---|---|
| Schema compiler | `compile_files`, `compile_string` | XSD to grammar tables at run time |
| Prebuilt tables | `EXIFormat.SchemaGen` | Tables written as a Julia module, precompiled with your package |
| XML conversion | `encode_xml`, `decode_to_xml` | XML text to EXI and back |
| Events | `Encoder`, `Decoder` | Write or read a stream one event at a time |
| Structs | `to_exi`, `from_exi` | Your own Julia types, laid out by the schema |
| Command line | `bin/exiformat` | Encode, decode, dump grammars, benchmark |

## Conformance and interoperability

Test results from the full test gate (`scripts/gate.sh`, on Julia 1.10 and 1.12,
with the exip judges required).

| Test | Profiles | Result |
|---|---|---|
| Encode, compared with EXIficient 1.0.7's bytes | strict bit-packed; strict bit-packed with options in the header; strict byte-aligned | Same bytes |
| Decode EXIficient's streams, compared with EXIficient's events | the same | Same events |
| Re-encode the decoded events | the same | Same bytes |
| exip's decoder (exipd) reads EXIFormat's output | strict bit-packed; strict byte-aligned | Accepted |
| Grammar tables compared with rexi's (`rexi dump-grammar`) | every fixture schema | The same |

[rexi-interop](https://github.com/nhenehan/rexi-interop) is a separate matrix, run
by hand, where EXIficient, Nagasena, Nagasena for .NET, exip, rexi and EXIFormat
encode and decode each other's streams. EXIFormat matches rexi in every strict
case.

## Safe with untrusted data

EXI is compact, so a few bytes can ask a decoder for a lot of work, such as a list
of four billion items or endless nesting. EXIFormat's decoder has four limits, on
by default, that stop this early with a `LimitError`. Schema loading has limits
too: `xs:include` and `xs:import` read only regular local files under the main
schema's folder, never a URL, and one type's grammar may only grow so large.

See the manual's [Untrusted input](https://nhenehan.github.io/EXIFormat.jl/stable/manual/untrusted-input/) chapter to
change either.

## Thanks

EXI is a careful, clearly written W3C Recommendation with good open libraries
behind it, and that work made this project possible.

- **Rumen Kyusakov** wrote [exip](https://exip.sourceforge.net/), a compact C
  implementation of EXI, and co-edited the Second Edition of the
  [EXI specification](https://www.w3.org/TR/exi/). exip's decoder is one of the
  checks EXIFormat's output must pass.
- **Daniel Peintner** wrote [EXIficient](https://exificient.github.io/) with
  Richard Kuntschke at Siemens, co-edited the Second Edition, and edited the
  [EXI Primer](https://www.w3.org/TR/exi-primer/). EXIFormat's bytes are checked
  against EXIficient's.
- **Takuki Kamiya** edited the First Edition, chaired the EXI Working Group,
  and wrote Nagasena ([OpenEXI](https://sourceforge.net/projects/openexi/)).
  **John Schneider** also edited the First Edition, and **Santiago
  Pericas-Geertsen** co-edited the Primer and wrote the W3C test framework.
- The **W3C EXI Working Group** as a whole made the specification that EXIFormat
  follows closely.

Thank you.

## How this was made

EXIFormat was written with the help of an AI coding tool (Claude Code), working
to my design and under my review. Every change has to pass the same tests: the
bytes must match EXIficient 1.0.7 and rexi bit for bit, the decoded events must
match EXIficient's, and the test suite runs on Julia 1.10 and 1.12. I
understand and maintain the code, and I answer for it.

## License

BSD-3-Clause, see [LICENSE](LICENSE).

For the code layout, tests, reference files and docs build, see
[CONTRIBUTING.md](CONTRIBUTING.md). Notes for AI coding agents are in
[AGENTS.md](AGENTS.md).
