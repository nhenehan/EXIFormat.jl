# EXIFormat

EXIFormat is a Julia library for EXI (Efficient XML Interchange), the W3C format
that sends XML as small, fast binary. You give it your XML Schema. Both ends use
the schema to agree on the format, so the messages can leave out names and
types. EXIFormat is a port of [rexi](https://github.com/nhenehan/rexi), the Rust
version, and makes the same bytes. Up to version 0.2.0 it was called JExi.

EXIFormat needs your XML Schema and writes strict EXI 1.0 (Second Edition). You
can pick bit-packed or byte-aligned, with or without the `$EXI` cookie, and
with the options written in the header or agreed ahead of time. With no cookie
and the options agreed ahead of time, the header is one byte.

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

## Add to your project

```julia
using Pkg
Pkg.add("EXIFormat")
```

To work on EXIFormat itself, clone it and use the clone instead:
`Pkg.develop(path = "path/to/EXIFormat.jl")`. [CONTRIBUTING.md](CONTRIBUTING.md)
explains the tests and tools.

EXIFormat needs Julia 1.10 or newer. It has no exports, so every name is written
`EXIFormat.name`.

## Learn more

- **The user guide**, in [`guide/`](guide/src/introduction.md), walks through
  the examples one at a time, from a first round trip to prebuilt tables. To
  read it in a browser, install [mdbook](https://rust-lang.github.io/mdBook/)
  and mdbook-mermaid, then run
  `mdbook-mermaid install guide && mdbook serve guide`.
- **The examples**, in [`examples/basics`](examples/basics/README.md), are
  small scripts, one idea each. Each has a Rust twin in rexi that prints the
  same output.
- **The command line** encodes and decodes files and lists a schema's grammars.
  In a clone, run [`bin/exiformat`](bin/exiformat) `--help`. With the package
  installed, run
  `julia -e 'using EXIFormat; exit(EXIFormat.CLI.main(ARGS))' -- --help`.

## What it does

- Turns XML Schemas (with `xs:include`, `xs:import`, groups, derived types,
  substitution groups and `xs:all`) into grammar tables.
- Encodes and decodes XML text, one event at a time, or your own Julia
  structs (`to_exi` / `from_exi`).
- Writes the tables as a Julia module ahead of time (`EXIFormat.SchemaGen`), so
  they precompile into your package.
- Writes the same bytes as EXIficient, the reference Java library, for every
  interop test case in the strict profiles.
- Refuses anything it does not support with an `UnsupportedError`. It never
  quietly writes something close enough.

## What it doesn't do yet

- **Compression and pre-compression.** They regroup the values and add
  DEFLATE, a large separate piece of work.
- **Schema-less streams.** EXIFormat needs your schema; the built-in grammars for
  streams without one are not written yet.
- **Non-strict mode.** Documents that stray from the schema need extra grammar
  rules everywhere, which EXIFormat does not build.
- **Preserve options.** Strict mode drops comments, processing instructions,
  DTDs and prefixes by design; keeping lexical values is not done yet.
- **Wildcards** (`xs:any`, `xs:anyAttribute`). The stream must then carry the
  name of the element or attribute, and that path is not built yet. Documents
  that don't use the wildcard work.
- **Unreadable patterns on restricted strings.** When an `xs:pattern` cannot
  be parsed, the alphabet of its restricted character set is unknown, and its
  values are refused (more below).
- **Fragments.** EXIFormat encodes whole documents with one root element;
  `fragment = true` is refused with `UnsupportedError`. (rexi 0.3 encodes
  schema-informed fragments.)
- **`xs:redefine`, `xs:override` and `xs:notation`** in a schema are refused
  when the schema is compiled.
- **selfContained.** The EXI spec does not allow it together with strict.
- **datatypeRepresentationMap.** It swaps in other encodings for datatypes; it
  is rarely used, and every reader would need the same map.

The schema still compiles when it uses a wildcard or an unreadable pattern.
The refusal happens only when a document uses that part, so a large schema
with one such spot still works.

Restricted character sets ([EXI 7.1.10.1](https://www.w3.org/TR/exi/#restrictedCharSet))
are supported. One comes from a string type whose `xs:pattern` allows fewer
than 256 characters, all in the BMP, such as `[A-Z]{2}[0-9]{4}`; each
character is then written as an n-bit index into that alphabet, in code point
order, and a character outside it as an escape and its code point. The bytes
equal EXIficient 1.0.7's, bit-packed and byte-aligned, except for a character
outside the BMP: EXIficient counts it as two UTF-16 units and writes its low
surrogate as a second character, where the spec counts one character. Patterns
with a large alphabet (`\d+`, `\p{L}+`, `.*`, `[^x]`, anything outside the
BMP) are not restricted and stay plain strings.

## Safe with untrusted data

EXI is compact, so a few bytes can ask for a huge amount of work. The decoder
has four limits, on by default, and stops with a `LimitError` when a stream
goes past one. Schemas have rules too: `xs:include` and `xs:import` read only
regular local files under the main schema's folder, and a schema's grammars
may only grow so large. The guide chapter
[Untrusted input](guide/src/untrusted-input.md) explains each one and how to
change it.

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

## License

BSD-3-Clause, see [LICENSE](LICENSE).

## How this was made

EXIFormat was written with the help of an AI coding tool (Claude Code), working
to my design and under my review. Every change has to pass the same tests: the
bytes must match EXIficient 1.0.7 and rexi bit for bit, the decoded events must
match EXIficient's, and the test suite runs on Julia 1.10 and 1.12. I
understand and maintain the code, and I answer for it.

## Working on EXIFormat

How the code is laid out, how to run the tests, and where the reference files
come from: [CONTRIBUTING.md](CONTRIBUTING.md). Notes for AI coding agents:
[AGENTS.md](AGENTS.md).
