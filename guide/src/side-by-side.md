# EXIFormat and rexi side by side

This page helps you move between EXIFormat and rexi, its Rust twin.

Each example in `examples/basics` (in EXIFormat.jl) has a
twin in `rexi/examples/basics` that prints exactly the same output. rexi's
`examples/basics/compare.sh` runs both and checks.

| Task | EXIFormat (Julia) | rexi (Rust) |
|---|---|---|
| Compile a schema | `EXIFormat.compile_files(path)` | `rexi_schema::compile_files(&[path])` |
| Strict options | `EXIFormat.strict_options()` | `ExiOptions::strict()` |
| Change an option | `strict_options(; alignment = EXIFormat.ALIGN_BYTE_ALIGNED)` | `.with_alignment(Alignment::ByteAligned)` |
| Header settings | `HeaderConfig(; cookie = true, include_options = true)` | `HeaderConfig::new().with_cookie(true).with_include_options(true)` |
| XML to EXI | `EXIFormat.encode_xml(xml, tables; options, header)` | `rexi_xml::encode_xml(xml, tables, &opts, header)` |
| EXI to XML | `EXIFormat.decode_to_xml(bytes, tables; options)` | `rexi_xml::decode_to_xml(bytes, tables, Some(opts))` |
| Read events | `for ev in dec` | `while let Some(ev) = dec.next_event()?` |
| Write events | `EXIFormat.start_element!(enc, ns, name)` | `enc.start_element(ns, name)?` |
| Text to parse | `EXIFormat.Lexical("42.95")` | `Value::Lexical("42.95")` |
| Structs | `EXIFormat.to_exi` / `from_exi` with `exi_names` | `rexi_serde::to_exi` / `from_exi` with serde |
| Prebuilt tables | `EXIFormat.SchemaGen.generate` | `rexi-schema-gen` command |
| Errors | Exceptions such as `UnsupportedError` | `Result` with `ExiError` |

rexi also has things EXIFormat does not: `no_std` and fixed buffers for small devices,
streaming from any `Read`/`Write`, and a C API.
