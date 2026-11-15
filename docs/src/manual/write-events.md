# Writing events

In this chapter you'll build an EXI document straight from your program's data,
with no XML text at all.

The encoder works like the decoder in reverse: you call one function per
[event](@ref "Event").

```@setup write-events
#! setup write_events.jl
```

```@example write-events
#! include write_events.jl main
```

## The encoder follows the schema

The [grammar](@ref "Grammar, grammar tables") works like a map of what may
come next. After `start Order`, the encoder expects `@orderId`, then perhaps
`@priority`, then a `Customer`, and so on:

```mermaid
stateDiagram-v2
    direction LR
    [*] --> orderId: start Order
    orderId --> priority
    orderId --> Customer
    priority --> Customer
    Customer --> Item
    Item --> Item
    Item --> Notes
    Item --> [*]: end Order
    Notes --> [*]: end Order
```

If you call something out of order, such as `Item` before `Customer`, the
encoder throws a `GrammarError` that says what it expected. Two rules trip
people up:

- **Attributes come first, sorted by name.**
  [Strict](@ref "Strict, non-strict") EXI wants them in the schema's sorted
  order, before any child elements.
- **Unqualified attributes have no namespace.** This schema puts elements in
  `urn:rexi:interop:order`, but attributes use `""`.

## Three ways to pass a value

| Value | Meaning |
|---|---|
| `"gold"` | Text. A string field stores it as it is. Other types parse it, like text from an XML file. |
| `true`, `2` | A typed value, used as it is. |
| `EXIFormat.Lexical("42.95")` | [Text](@ref lexical) that EXIFormat always parses with the schema's type. |

`Lexical` makes it clear you mean "parse this". Typed values skip the parsing.
