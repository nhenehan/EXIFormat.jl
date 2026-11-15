# Tools

## Prebuilt tables

```@docs
EXIFormat.SchemaGen.generate
```

## Command line

In a clone, run `bin/exiformat --help`. With the package installed:

```
julia -e 'using EXIFormat; exit(EXIFormat.CLI.main(ARGS))' -- --help
```

```@docs
EXIFormat.CLI.main
```
