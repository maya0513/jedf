///|
fn sample_document() -> @ast.Document {
  {
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title")]),
      @ast.Block::Paragraph([
        @ast.Run::plain("plain "),
        {
          text: "bold",
          marks: {
            ..@ast.Marks(),
            strong: true,
            link: Some("https://example.com"),
          },
        },
        { text: "x", marks: { ..@ast.Marks(), math: true, }, },
      ]),
      @ast.Block::Section([@ast.Run::plain("S")], [
        @ast.Block::Paragraph([@ast.Run::plain("inner")]),
      ]),
      @ast.Block::ListBlock(true, [
        [@ast.Block::Paragraph([@ast.Run::plain("one")])],
      ]),
      @ast.Block::TableBlock([
        {
          header: true,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("h")])]],
        },
        {
          header: false,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("c")])]],
        },
      ]),
      @ast.Block::CodeBlock("let x = 1", Some("moonbit")),
      @ast.Block::CodeBlock("plain code", None),
      @ast.Block::MathBlock("x^2"),
      @ast.Block::FigureBlock("a.png", "alt", Some([@ast.Run::plain("cap")])),
      @ast.Block::FigureBlock("b.png", "alt2", None),
      @ast.Block::FootnoteBlock("n1", [
        @ast.Block::Paragraph([@ast.Run::plain("note")]),
      ]),
      @ast.Block::PageBreakHint,
      @ast.Block::Heading(-2, []),
    ],
  }
}

///|
fn kind_of(data : Bytes) -> String {
  try {
    let _ = @codec_cbor.parse(data)
    "ok"
  } catch {
    @codec_cbor.CborError::InvalidCbor(_) => "invalid"
    @codec_cbor.CborError::Schema(_) => "schema"
  }
}

///|
test "empty document encodes to known bytes" {
  let doc : @ast.Document = { blocks: [], }
  let expected = Bytes::from_array([
    0xA3, // map(3)
     0x64, 0x74, 0x79, 0x70, 0x65, // "type"
     0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, // "document"
     0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, // "version"
     0x01, // 1
     0x66, 0x62, 0x6C, 0x6F, 0x63, 0x6B, 0x73, // "blocks"
     0x80, // array(0)
  ])
  @debug.assert_eq(@codec_cbor.to_bytes(doc), expected)
  @debug.assert_eq(@codec_cbor.parse(expected), doc)
}

///|
test "cbor round trip over all block types" {
  let doc = sample_document()
  @debug.assert_eq(@codec_cbor.parse(@codec_cbor.to_bytes(doc)), doc)
}

///|
test "cbor round trip property" {
  @quickcheck.check(fn(doc : @ast.Document) {
    let parsed = Some(@codec_cbor.parse(@codec_cbor.to_bytes(doc))) catch {
      _ => None
    }
    parsed == Some(doc)
  })
}

///|
test "parse rejects malformed cbor" {
  let good = @codec_cbor.to_bytes(sample_document())
  // Truncated.
  let truncated : Array[Byte] = []
  for b in good {
    truncated.push(b)
  }
  ignore(truncated.pop())
  @debug.assert_eq(kind_of(Bytes::from_array(truncated[:])), "invalid")
  // Trailing bytes.
  let trailing : Array[Byte] = []
  for b in good {
    trailing.push(b)
  }
  trailing.push(0x00)
  @debug.assert_eq(kind_of(Bytes::from_array(trailing[:])), "invalid")
  // Indefinite-length array, byte string, tag, float: outside the subset.
  @debug.assert_eq(kind_of(b"\x9f\xff"), "invalid")
  @debug.assert_eq(kind_of(b"\x41\x00"), "invalid")
  @debug.assert_eq(kind_of(b"\xc0\x00"), "invalid")
  @debug.assert_eq(kind_of(b"\xf9\x3c\x00"), "invalid")
  @debug.assert_eq(kind_of(b""), "invalid")
}

///|
test "parse rejects duplicate map keys" {
  // map(2) { "a": 1, "a": 2 }
  @debug.assert_eq(kind_of(b"\xa2\x61a\x01\x61a\x02"), "invalid")
}

///|
test "parse rejects schema violations" {
  // A document whose version is 2: map(3) type/version/blocks.
  let wrong_version = Bytes::from_array([
    0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65,
    0x6E, 0x74, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x02, 0x66, 0x62,
    0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x80,
  ])
  @debug.assert_eq(kind_of(wrong_version), "schema")
  // A block of unknown type "nope" inside an otherwise valid document.
  let unknown_block = Bytes::from_array([
    0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65,
    0x6E, 0x74, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x01, 0x66, 0x62,
    0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x81, // array(1)
     0xA1, // map(1)
     0x64, 0x74, 0x79, 0x70, 0x65, // "type"
     0x64, 0x6E, 0x6F, 0x70, 0x65, // "nope"
  ])
  @debug.assert_eq(kind_of(unknown_block), "schema")
}

///|
fn large_document() -> @ast.Document {
  let blocks : Array[@ast.Block] = []
  for i in 0..<1000 {
    blocks.push(
      @ast.Block::Paragraph([
        @ast.Run::plain("Paragraph number \{i} with some plain text."),
        @ast.Run::marked("emphasized", @ast.Marks::{
          ..@ast.Marks(),
          emphasis: true,
        }),
      ]),
    )
  }
  { blocks, }
}

///|
test (b : @bench.T) {
  let doc = sample_document()
  let bytes = @codec_cbor.to_bytes(doc)
  b.bench(name="encode sample", fn() { b.keep(@codec_cbor.to_bytes(doc)) })
  b.bench(name="parse sample", fn() {
    b.keep(Ok(@codec_cbor.parse(bytes)) catch { e => Err(e) })
  })
}

///|
test (b : @bench.T) {
  let doc = large_document()
  let bytes = @codec_cbor.to_bytes(doc)
  b.bench(name="encode large (1000 blocks)", fn() {
    b.keep(@codec_cbor.to_bytes(doc))
  })
  b.bench(name="parse large (1000 blocks)", fn() {
    b.keep(Ok(@codec_cbor.parse(bytes)) catch { e => Err(e) })
  })
}

///|
/// Wrap block-array bytes in a document map.
fn doc_with_blocks(block_bytes : Array[Byte]) -> Bytes {
  let out : Array[Byte] = [
    0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, // "type"
     0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65, 0x6E, 0x74, // "document"
     0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, // "version"
     0x01, // 1
     0x66, 0x62, 0x6C, 0x6F, 0x63, 0x6B, 0x73, // "blocks"
  ]
  for b in block_bytes {
    out.push(b)
  }
  Bytes::from_array(out[:])
}

///|
test "parse rejects out-of-subset and inconsistent values" {
  // A text header claiming more bytes than remain.
  @debug.assert_eq(kind_of(b"\x6a\x61\x62"), "invalid")
  // A text length beyond the supported range (also the 8-byte form).
  @debug.assert_eq(kind_of(b"\x7b\xff\xff\xff\xff\xff\xff\xff\xff"), "invalid")
  // Nesting deeper than the reader allows.
  let deep : Array[Byte] = []
  for _ in 0..<300 {
    deep.push(0x81)
  }
  deep.push(0x01)
  @debug.assert_eq(kind_of(Bytes::from_array(deep[:])), "invalid")
  // A text string that is not valid UTF-8.
  @debug.assert_eq(kind_of(b"\x61\xff"), "invalid")
  // A map whose key is not text.
  @debug.assert_eq(kind_of(b"\xa1\x01\x02"), "invalid")
}

///|
test "parse rejects schema type errors" {
  // The top-level value is an array, not a map.
  @debug.assert_eq(kind_of(b"\x80"), "schema")
  // The document type is not a string.
  @debug.assert_eq(
    kind_of(
      Bytes::from_array([
        0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x01, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69,
        0x6F, 0x6E, 0x01, 0x66, 0x62, 0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x80,
      ]),
    ),
    "schema",
  )
  // The document type is the wrong string.
  @debug.assert_eq(
    kind_of(
      Bytes::from_array([
        0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x63, 0x64, 0x6F, 0x63, // "doc"
         0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x01, 0x66, 0x62, 0x6C,
        0x6F, 0x63, 0x6B, 0x73, 0x80,
      ]),
    ),
    "schema",
  )
  // An unknown extra field in the document.
  @debug.assert_eq(
    kind_of(
      Bytes::from_array([
        0xA4, 0x64, 0x74, 0x79, 0x70, 0x65, 0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65,
        0x6E, 0x74, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x01, 0x66, 0x62,
        0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x80, 0x61, 0x78, 0x00, // "x": 0
      ]),
    ),
    "schema",
  )
  // Blocks is not an array.
  @debug.assert_eq(
    kind_of(
      Bytes::from_array([
        0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x68, 0x64, 0x6F, 0x63, 0x75, 0x6D, 0x65,
        0x6E, 0x74, 0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x01, 0x66, 0x62,
        0x6C, 0x6F, 0x63, 0x6B, 0x73, 0x01,
      ]),
    ),
    "schema",
  )
  // A list whose "ordered" is not a boolean.
  @debug.assert_eq(
    kind_of(
      doc_with_blocks([
        0x81, 0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x64, 0x6C, 0x69, 0x73, 0x74, // "list"
         0x67, 0x6F, 0x72, 0x64, 0x65, 0x72, 0x65, 0x64, // "ordered"
         0x61, 0x79, // "y"
         0x65, 0x69, 0x74, 0x65, 0x6D, 0x73, // "items"
         0x80,
      ]),
    ),
    "schema",
  )
  // A heading level outside the 32-bit range, positive and negative,
  // and a level that is not an integer at all.
  let level_doc = fn(level_bytes : Array[Byte]) {
    let blocks : Array[Byte] = [
      0x81, 0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x67, 0x68, 0x65, 0x61, 0x64, 0x69,
      0x6E, 0x67, // "heading"
       0x65, 0x6C, 0x65, 0x76, 0x65, 0x6C, // "level"
    ]
    for b in level_bytes {
      blocks.push(b)
    }
    blocks.push(0x67)
    blocks.push(0x63)
    blocks.push(0x6F)
    blocks.push(0x6E)
    blocks.push(0x74)
    blocks.push(0x65)
    blocks.push(0x6E)
    blocks.push(0x74)
    blocks.push(0x80)
    doc_with_blocks(blocks)
  }
  @debug.assert_eq(kind_of(level_doc([0x1A, 0xFF, 0xFF, 0xFF, 0xFF])), "schema")
  @debug.assert_eq(kind_of(level_doc([0x3A, 0xFF, 0xFF, 0xFF, 0xFF])), "schema")
  @debug.assert_eq(kind_of(level_doc([0x61, 0x78])), "schema")
  // A code block whose language is neither text nor null.
  @debug.assert_eq(
    kind_of(
      doc_with_blocks([
        0x81, 0xA3, 0x64, 0x74, 0x79, 0x70, 0x65, 0x64, 0x63, 0x6F, 0x64, 0x65, // "code"
         0x64, 0x74, 0x65, 0x78, 0x74, // "text"
         0x61, 0x61, // "a"
         0x68, 0x6C, 0x61, 0x6E, 0x67, 0x75, 0x61, 0x67, 0x65, // "language"
         0x01,
      ]),
    ),
    "schema",
  )
}
