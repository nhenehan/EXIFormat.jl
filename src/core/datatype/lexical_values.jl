# Preserve.lexicalValues (https://www.w3.org/TR/exi/#fidelityOptions): every value
# is sent as its text, so the decoder gives back exactly what the encoder was
# given ("1.50" stays "1.50").
#
# The text is a String with the restricted character set of the value's built-in
# EXI type (https://www.w3.org/TR/exi/#encodingDatatypes, Table 7-2), whatever
# pattern facets the schema type has. A list uses the set of its item type, and
# an enumeration the set of its base type. Strings, unions and QNames have no
# set. The text still goes through the value string table. The same as rexi's
# crates/rexi-core/src/datatype/lexical_values.rs.

# Each set in code point order, the order EXI numbers its characters in
# (https://www.w3.org/TR/exi/#restrictedCharSet).
const LEX_BASE64 = "\t\n\r +/0123456789=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const LEX_HEX = "\t\n\r 0123456789ABCDEFabcdef"
const LEX_BOOLEAN = "\t\n\r 01aeflrstu"
const LEX_DATE_TIME = "\t\n\r +-.0123456789:TZ"
const LEX_DECIMAL = "\t\n\r +-.0123456789"
const LEX_DOUBLE = "\t\n\r +-.0123456789EFINae"
const LEX_INTEGER = "\t\n\r +-0123456789"

"""
    lexical_alphabet(kind, tables) -> Union{Nothing,String}

The restricted character set for a value of `kind` with Preserve.lexicalValues
(Table 7-2), or `nothing` for a plain String. A list or an enumeration takes
the set of its item or base type, all the way down, as EXIficient does.
"""
function lexical_alphabet(kind::DatatypeKind, tables)
    t = kind.tag
    t == K_BASE64 && return LEX_BASE64
    t == K_HEX && return LEX_HEX
    (t == K_BOOLEAN || t == K_BOOLEAN_PATTERN) && return LEX_BOOLEAN
    t == K_DATETIME && return LEX_DATE_TIME
    t == K_DECIMAL && return LEX_DECIMAL
    t == K_FLOAT && return LEX_DOUBLE
    (t == K_INTEGER || t == K_UNSIGNED || t == K_NBIT) && return LEX_INTEGER
    (t == K_ENUMERATION || t == K_LIST) && return lexical_alphabet(datatype(tables, kind.item), tables)
    return nothing
end
