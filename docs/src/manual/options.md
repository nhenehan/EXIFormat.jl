# Choosing options

In this chapter you'll choose what goes in a stream's header, and see how each
choice changes the size.

Every EXI stream starts with a short [header](@ref "Header"). At its
smallest it is a single byte. It can also carry a `$EXI`
[cookie](@ref "Cookie"), so tools can spot the format, and an **options
document** that tells the decoder how the body was written.

```mermaid
flowchart LR
    C["$EXI cookie<br/>(optional, 4 bytes)"] --> H["header bits<br/>(always)"]
    H --> O["options document<br/>(optional)"]
    O --> B[body]
```

If the options are not in the header, both sides must agree on them some other
way, such as in a protocol spec or a config file. The EXI spec calls this
[out of band](@ref "Out of band"). Options are keyword arguments to
`strict_options`, and header settings are keyword arguments to `HeaderConfig`:

```@setup options
#! setup options.jl
```

```@example options
#! include options.jl main
```

## Which should I use?

| Setting | Pick it when |
|---|---|
| [Bit-packed](@ref "Bit-packed, byte-aligned"), options out of band | Both ends are yours. This is the smallest. |
| Options in the header | Readers should not need to be told the options. For strict options the document is only a few bits, so here the size does not change. |
| Cookie | People or tools may need to recognize the file. The `24 45 58 49` above is `$EXI`. |
| `schema_id` | Readers should be able to check they have the right schema. Name the tables with the same id (`with_schema_id`), and the decoder refuses a stream that names another schema. |
| Byte-aligned | You are debugging. Text like `4f 52 44` (`ORD`) shows up in a hex dump. |

EXIFormat refuses options it does not support when you build the encoder, so you
find out right away.

## Fragments

A normal EXI body holds one document with one root element. Set the `fragment`
option (`strict_options(; fragment = true)`) to send a run of elements instead,
such as tank level and flow readings with no wrapper around them
([EXI 8.5.2](https://www.w3.org/TR/exi/#informedFragGrammars)). Each element may
be any element the schema declares, even one that is only declared inside
another element. `encode_xml` then takes XML with several root elements,
`decode_to_xml` gives them back, and [`xml_fragment_events`](@ref
EXIFormat.xml_fragment_events) reads such XML into events. The `exiformat`
tool takes `--fragment` for the same thing.

One case is refused: when two elements share a name but have different types
(or differ in `nillable`), EXI would read that name at the top of a fragment
with a looser grammar that EXIFormat does not build. Inside their parents those
elements work as usual.
