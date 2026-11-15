# Events

Read a stream one event at a time with a [`Decoder`](@ref EXIFormat.Decoder), or write one with an [`Encoder`](@ref EXIFormat.Encoder).

```@docs
EXIFormat.Decoder
EXIFormat.next_event!
EXIFormat.Encoder
EXIFormat.start_document!
EXIFormat.end_document!
EXIFormat.start_element!
EXIFormat.end_element!
EXIFormat.attribute!
EXIFormat.characters!
EXIFormat.xsi_type!
EXIFormat.xsi_nil!
EXIFormat.finish!
EXIFormat.reset!
EXIFormat.written_bytes
EXIFormat.Event
EXIFormat.StartDocument
EXIFormat.EndDocument
EXIFormat.StartElement
EXIFormat.EndElement
EXIFormat.Attribute
EXIFormat.XsiType
EXIFormat.XsiNil
EXIFormat.Characters
EXIFormat.event_name
EXIFormat.QName
EXIFormat.QNameId
```
