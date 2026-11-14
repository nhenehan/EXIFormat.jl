# Reads an EXI stream one event at a time with the pull decoder, and prints each
# event with the type of its value.
#
# The decoder gives typed values (a Bool, an integer, a decimal), not just text,
# because the schema says what type each value has
# (EXI 7, https://www.w3.org/TR/exi/#encodingDatatypes).
#
# Rust version: rexi/examples/basics/src/bin/read_events.rs.

import EXIFormat
include("common.jl")

# ANCHOR: main
"""The value as text, followed by the kind of value the decoder gave."""
function describe(value)
    kind = value isa AbstractString ? "string" :
           value isa Bool ? "boolean" :
           value isa Integer ? "integer" :
           value isa EXIFormat.ExiDecimal ? "decimal" : "other"
    return "$(EXIFormat.plain_format(value)) ($kind)"
end

tables = EXIFormat.compile_files(data("order.xsd"))
exi = EXIFormat.encode_xml(read(data("order.xml"), String), tables)

dec = EXIFormat.Decoder(exi, tables; options = EXIFormat.strict_options())
depth = 0
# A decoder is also an iterator: the loop ends after the end of the document.
for event in dec
    indent = "  "^depth
    if event isa EXIFormat.StartDocument
        println("start document")
    elseif event isa EXIFormat.EndDocument
        println("end document")
    elseif event isa EXIFormat.StartElement
        println(indent, event.local_name)
        global depth += 1
    elseif event isa EXIFormat.EndElement
        global depth -= 1
    elseif event isa EXIFormat.Attribute
        println(indent, "@", event.local_name, " = ", describe(event.value))
    elseif event isa EXIFormat.Characters
        println(indent, describe(event.value))
    else
        println(indent, EXIFormat.event_name(event))
    end
end
# ANCHOR_END: main
