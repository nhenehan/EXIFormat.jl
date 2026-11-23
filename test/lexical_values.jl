# Preserve.lexicalValues (https://www.w3.org/TR/exi/#fidelityOptions): every value
# is sent as its text, with the restricted character set of its built-in type
# (https://www.w3.org/TR/exi/#encodingDatatypes, Table 7-2).
#
# Ported from rexi's crates/rexi-xml/tests/lexical_values.rs (its
# `lexical-values` feature), with the same schema and the same bits worked out by
# hand. The bytes are checked against EXIficient by running the whole W3C strict
# group with the option on (scripts/w3c-strict.py --lexical-values).
import EXIFormat as J

const LEX_XSD = """<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="d" type="xs:decimal"/>
  <xs:element name="r"><xs:complexType><xs:sequence>
    <xs:element name="i" type="xs:int" maxOccurs="unbounded"/>
    <xs:element name="l" type="ints"/>
    <xs:element name="n" type="xs:boolean" nillable="true"/>
  </xs:sequence><xs:attribute name="b" type="xs:boolean"/></xs:complexType></xs:element>
  <xs:simpleType name="ints"><xs:list itemType="xs:int"/></xs:simpleType>
  <xs:complexType name="t"><xs:sequence>
    <xs:element name="v" type="xs:int"/>
  </xs:sequence></xs:complexType>
  <xs:complexType name="t2"><xs:complexContent><xs:extension base="t"><xs:sequence>
    <xs:element name="w" type="xs:int"/>
  </xs:sequence></xs:extension></xs:complexContent></xs:complexType>
  <xs:element name="e" type="t"/>
  <xs:element name="m"><xs:complexType mixed="true"><xs:sequence>
    <xs:element name="v" type="xs:int"/>
  </xs:sequence></xs:complexType></xs:element>
</xs:schema>"""

lexical_options(; kw...) = J.strict_options(; preserve = J.Preserve(; lexical_values = true), kw...)

lex_plain(v) = v isa J.Lexical ? v.text : v
lex_text(ev::J.Characters) = J.Characters(lex_plain(ev.value))
lex_text(ev::J.Attribute) = J.Attribute(ev.uri, ev.local_name, lex_plain(ev.value))
lex_text(ev) = ev

@testset "Preserve.lexicalValues" begin
    t = J.compile_string(LEX_XSD)

    """Encodes and decodes `xml` on both alignments; the events and the XML text must come back as they were."""
    function lex_round_trip(xml)
        for o in (lexical_options(), lexical_options(; alignment = J.ALIGN_BYTE_ALIGNED))
            exi = J.encode_xml(xml, t; options = o)
            @test J.decode_events(exi, t; options = o) == map(lex_text, J.xml_events(xml))
            @test J.decode_to_xml(exi, t; options = o) == xml
        end
    end

    unsupported(f) =
        try
            f()
            nothing
        catch e
            e isa J.UnsupportedError ? e.feature : rethrow()
        end

    @testset "bits follow the spec" begin
        # Header 1000 0000 = 0x80. Then:
        #   SE(d): four global elements (d, e, m, r) plus SE(*), so 3 bits; d is first: 000
        #   CH: d's first rule has CH and the xsi:type escape (xs:decimal has subtypes): 1 bit, 0
        #   "1.50": a string table miss, length 4 + 2 = 6 as an Unsigned Integer:
        #       0000 0110; then each character as a 5-bit index into the decimal set
        #       "\t\n\r +-.0123456789" (17 characters, ceil_log2(18) = 5 bits):
        #       1 = 8, . = 6, 5 = 12, 0 = 7
        #   EE, ED: 0 bits
        # 000 0 00000110 01000 00110 01100 00111, 32 bits = 00 64 19 87.
        @test J.encode_xml("<d>1.50</d>", t; options = lexical_options()) == [0x80, 0x00, 0x64, 0x19, 0x87]
    end

    @testset "values come back as written" begin
        # Without the option these become 1.5, 5, the list "1 2", and false.
        lex_round_trip("<d>1.50</d>")
        lex_round_trip("<d> +01.0 </d>")
        lex_round_trip("""<r b="0"><i>+05</i><i>7</i><l> 1  2 </l><n>0</n></r>""")
        # A character outside the integer set is sent escaped, not refused.
        lex_round_trip("<r><i>x</i><l>3</l><n>true</n></r>")
    end

    @testset "whitespace between elements is kept" begin
        # EXIficient keeps every text a CH can take when the option is on.
        lex_round_trip("<m>\n  <v>1</v>\n</m>")
    end

    @testset "xsi:nil is text" begin
        lex_round_trip("""<r xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><i>1</i><l>1</l><n xsi:nil="true"/></r>""")
    end

    @testset "xsi:type with a namespace needs Preserve.prefixes" begin
        xml = """<e xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema" xsi:type="xs:int">5</e>"""
        @test unsupported(() -> J.encode_xml(xml, t; options = lexical_options())) == J.FEATURE_PRESERVE_PREFIXES
        # A type in no namespace is its local name.
        lex_round_trip("""<e xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="t2"><v>05</v><w>6</w></e>""")
    end

    @testset "options in the header" begin
        exi = J.encode_xml("<d>1.50</d>", t; options = lexical_options(), header = J.HeaderConfig(; include_options = true))
        @test J.decode_to_xml(exi, t) == "<d>1.50</d>"
    end
end
