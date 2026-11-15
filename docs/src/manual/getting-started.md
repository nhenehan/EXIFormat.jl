# Getting started

In this chapter you'll add EXIFormat to a project and run the examples.

## Add EXIFormat to your project

EXIFormat needs Julia 1.10 or newer.

```julia
using Pkg
Pkg.add("EXIFormat")
```

To work on EXIFormat itself, clone it and use the clone instead:
`Pkg.develop(path = "path/to/EXIFormat.jl")`.

Then:

```julia
import EXIFormat
```

EXIFormat has no exports. You write every name as `EXIFormat.name`, so it is always clear
where a name comes from.

## Run the examples

The examples live in `examples/basics` of the repository, with their own
`Project.toml`. Clone the repository first; the copy that `Pkg.add` installs is
read-only.

```bash
git clone https://github.com/nhenehan/EXIFormat.jl && cd EXIFormat.jl
julia --project=examples/basics -e 'using Pkg; Pkg.develop(path=".")'   # once
julia --project=examples/basics examples/basics/roundtrip.jl
julia --project=examples/basics examples/basics/run-all.jl          # every example
```

## The sample order

Every example uses the same two files in `examples/basics/data`. The
[schema](@ref "Schema") says an `Order` has an `orderId`, a `Customer`,
one or more `Item`s and maybe some `Notes`:

```xml
#! include data/order.xml
```

!!! details "The schema, `order.xsd`"
    ```xml
    #! include data/order.xsd
    ```
