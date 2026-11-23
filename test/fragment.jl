# Schema-informed fragments (https://www.w3.org/TR/exi/#informedFragGrammars):
# a body that holds any number of root elements, each one any element the schema
# declares, global or local. The top level is
# `FragmentContent : SE(F_0) ... SE(F_n-1) SE(*) ED`, with the names sorted by
# local name and then by URI, so its event codes are `ceil_log2(n + 2)` bits wide.
#
# Ported from rexi's crates/rexi-xml/tests/fragment.rs, with the same schemas and
# the same bits worked out by hand from the spec. The byte check against
# EXIficient for a larger schema lives in rexi-interop (case F1).
import EXIFormat as J

# Global `a` and `b`, and `c`, which is declared only inside `b`. Sorted, the
# fragment's names are `a`, `b`, `c`: codes 0, 1, 2, then `SE(*)` = 3 and
# `ED` = 4, three bits each.
const ABC = """<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="b">
    <xs:complexType><xs:sequence>
      <xs:element name="c" type="xs:boolean"/>
    </xs:sequence></xs:complexType>
  </xs:element>
  <xs:element name="a" type="xs:boolean"/>
</xs:schema>"""

fragment_options(; kw...) = J.strict_options(; fragment = true, kw...)

unsupported_feature(f) =
    try
        f()
        nothing
    catch e
        e isa J.UnsupportedError ? e.feature : rethrow()
    end

# The XML reader gives values as `Lexical` text and `decode_events` as plain
# strings: compare them as text.
plain_value(v) = v isa J.Lexical ? v.text : v
plain(ev::J.Characters) = J.Characters(plain_value(ev.value))
plain(ev::J.Attribute) = J.Attribute(ev.uri, ev.local_name, plain_value(ev.value))
plain(ev) = ev
xml_fragment(xml) = map(plain, J.xml_fragment_events(xml))

"""Encodes `xml` as a fragment, decodes it again, and checks the events match the XML's."""
function fragment_round_trip(tables, xml, options)
    exi = J.encode_xml(xml, tables; options)
    @test J.decode_events(exi, tables; options) == xml_fragment(xml)
    return exi
end

@testset "fragments" begin
    abc = J.compile_string(ABC)

    @testset "bits follow the spec" begin
        # Header: distinguishing bits 10, no options, version 0 0000 = 0x80. Then:
        #   SE(c) code 2 010; CH 0 bits, true: 1; EE 0 bits
        #   SE(a) code 0 000; CH 0 bits, false: 0; EE 0 bits
        #   ED    code 4 100
        # 0101 0000 100, padded with zeros: 0x50 0x80.
        @test J.encode_xml("<c>true</c><a>false</a>", abc; options = fragment_options()) == [0x80, 0x50, 0x80]
    end

    @testset "round trips" begin
        for xml in ("", "<a>true</a>", "<b><c>false</c></b><a>true</a><c>true</c><b><c>true</c></b>")
            fragment_round_trip(abc, xml, fragment_options())
            fragment_round_trip(abc, xml, fragment_options(; alignment = J.ALIGN_BYTE_ALIGNED))
        end
    end

    @testset "an empty fragment is only ED" begin
        # ED is code 4 in three bits: 100, padded.
        @test fragment_round_trip(abc, "", fragment_options()) == [0x80, 0x80]
    end

    @testset "options in the header" begin
        xml = "<a>true</a><b><c>false</c></b>"
        exi = J.encode_xml(xml, abc; options = fragment_options(), header = J.HeaderConfig(; include_options = true))
        # No out-of-band options: the decoder finds `fragment` in the header.
        @test J.decode_events(exi, abc) == xml_fragment(xml)
    end

    @testset "decodes to XML with namespaces on each root" begin
        t = J.compile_string("""<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:t" xmlns="urn:t" elementFormDefault="qualified">
              <xs:element name="p" type="xs:int"/>
              <xs:element name="q" type="xs:string"/>
            </xs:schema>""")
        xml = """<p xmlns="urn:t">7</p><q xmlns="urn:t">hi</q>"""
        exi = fragment_round_trip(t, xml, fragment_options())
        text = J.decode_to_xml(exi, t; options = fragment_options())
        # Each root declares its namespace, so the output reads back as the same fragment.
        @test xml_fragment(text) == xml_fragment(xml)
    end

    @testset "several roots need the fragment option" begin
        @test_throws J.XmlSyntaxError J.encode_xml("<a>true</a><a>false</a>", abc)
        # A local element cannot be the root of a document either.
        @test unsupported_feature(() -> J.encode_xml("<c>true</c>", abc)) == J.FEATURE_BUILT_IN_ELEMENT_GRAMMAR
    end

    @testset "an undeclared root needs a built-in grammar" begin
        @test unsupported_feature(() -> J.encode_xml("<a>true</a><z/>", abc; options = fragment_options())) ==
              J.FEATURE_BUILT_IN_ELEMENT_GRAMMAR
        # And on decode: code 3 is SE(*). 011 after the header.
        @test unsupported_feature(() -> J.decode_events(UInt8[0x80, 0x60], abc; options = fragment_options())) ==
              J.FEATURE_BUILT_IN_ELEMENT_GRAMMAR
    end

    # Two local `x` declarations with different types: EXI reads a fragment-level
    # `x` with the relaxed element grammar, which EXIFormat refuses. Inside its
    # parent, each `x` still has its own grammar.
    @testset "a shared name with different types is refused at the top level only" begin
        t = J.compile_string("""<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="m"><xs:complexType><xs:sequence>
                <xs:element name="x" type="xs:int"/>
              </xs:sequence></xs:complexType></xs:element>
              <xs:element name="n"><xs:complexType><xs:sequence>
                <xs:element name="x" type="xs:string"/>
              </xs:sequence></xs:complexType></xs:element>
            </xs:schema>""")
        fragment_round_trip(t, "<m><x>5</x></m><n><x>five</x></n>", fragment_options())
        @test unsupported_feature(() -> J.encode_xml("<x>5</x>", t; options = fragment_options())) ==
              J.FEATURE_RELAXED_ELEMENT_GRAMMAR
        # Names m, n, x, then SE(*) and ED: five codes, three bits. x is 010.
        @test unsupported_feature(() -> J.decode_events(UInt8[0x80, 0x40], t; options = fragment_options())) ==
              J.FEATURE_RELAXED_ELEMENT_GRAMMAR
    end

    # The same name declared twice with the same type keeps that type's grammar.
    @testset "a shared name with the same type is one entry" begin
        t = J.compile_string("""<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="m"><xs:complexType><xs:sequence>
                <xs:element name="x" type="xs:int"/>
              </xs:sequence></xs:complexType></xs:element>
              <xs:element name="x" type="xs:int"/>
            </xs:schema>""")
        # Names m, x: two entries, so codes are ceil_log2(4) = 2 bits: x is 01. x's
        # first rule has CH and the xsi:type escape (xs:int has built-in subtypes),
        # so CH takes one bit: 0. Then the int 5: a sign bit 0 and one byte
        # 0000 0101. Then ED is 11.
        # 01 0 0 00000101 11 -> 0100 0000 0101 11(00) -> 0x40 0x5C.
        @test fragment_round_trip(t, "<x>5</x>", fragment_options()) == [0x80, 0x40, 0x5c]
    end

    @testset "a reused codec codes the next fragment the same" begin
        exi = J.encode_xml("<b><c>true</c></b><a>false</a>", abc; options = fragment_options())
        dec = J.Decoder(exi, abc; options = fragment_options())
        first = collect(dec)
        # SD, SE(b), SE(c), CH, EE, EE, SE(a), CH, EE, ED
        @test length(first) == 10
        J.reset!(dec, exi)
        @test collect(dec) == first
    end
end
