# Prebuilt tables

In this chapter you'll compile the schema ahead of time and save the tables as
Julia code, so your program starts fast.

Up to now, every script read and compiled `order.xsd` when it started. You can
do that work once and save the
[grammar tables](@ref "Grammar, grammar tables"):

```julia
import EXIFormat
EXIFormat.SchemaGen.generate(["examples/basics/data/order.xsd"];
    out = "examples/basics/order_tables.jl", module_name = "OrderTables")
```

```mermaid
flowchart LR
    subgraph "Ahead of time"
        X[order.xsd] --> G[EXIFormat.SchemaGen] --> R[order_tables.jl]
    end
    subgraph "When your program runs"
        R --> S["OrderTables.GRAMMARS"] --> E[Encoder / Decoder]
    end
```

The result is a module with a constant `GRAMMARS`. Use it anywhere you used
compiled tables:

```@setup prebuilt-tables
#! setup prebuilt_tables.jl
```

```@example prebuilt-tables
#! include prebuilt_tables.jl main
```

## Why bother?

- **No start-up cost.** Include the file in your package and the tables are
  [precompiled](@ref "Precompile") with it.
- **No XSD files to ship.** The schema is built into your code.
- **Fast names.** The module also has a constant for every name, such as
  `OrderTables.LN_ORDER`. `EXIFormat.start_element!(enc, OrderTables.LN_ORDER)` skips
  the name lookup.

In your tests, pass `check = true` to `generate`. It returns `false` if the
file no longer matches the schema.
