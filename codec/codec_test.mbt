///|
fn sample_doc() -> @ast.Document {
  {
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title")]),
      @ast.Block::Paragraph([
        @ast.Run::plain("Hello "),
        @ast.Run::marked("world", @ast.Marks::{
          ..@ast.Marks(),
          emphasis: true,
          link: Some("https://example.com"),
        }),
        @ast.Run::marked("x^2", @ast.Marks::{ ..@ast.Marks(), math: true, }),
      ]),
      @ast.Block::Section([@ast.Run::plain("S")], [
        @ast.Block::ListBlock(true, [
          [@ast.Block::Paragraph([@ast.Run::plain("i")])],
        ]),
      ]),
      @ast.Block::TableBlock([
        @ast.TableRow::{
          header: true,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("h")])]],
        },
      ]),
      @ast.Block::CodeBlock("code", None),
      @ast.Block::MathBlock("E = mc^2"),
      @ast.Block::FigureBlock("a.png", "alt", None),
      @ast.Block::FootnoteBlock("n1", [
        @ast.Block::Paragraph([@ast.Run::plain("note")]),
      ]),
      @ast.Block::PageBreakHint,
    ],
  }
}

///|
fn error_kind(text : String) -> String {
  let result : Result[@ast.Document, @codec.CodecError] = Ok(@codec.parse(text)) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => "ok"
    Err(@codec.CodecError::InvalidJson(_)) => "invalid_json"
    Err(@codec.CodecError::Schema(_)) => "schema"
  }
}

///|
test "encode snapshot" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Heading(2, [@ast.Run::plain("Hi")]),
      @ast.Block::Paragraph([
        @ast.Run::marked("b", @ast.Marks::{ ..@ast.Marks(), strong: true, }),
      ]),
    ],
  }
  inspect(
    @codec.to_string(doc),
    content=(
      #|{"type":"document","version":1,"blocks":[{"type":"heading","level":2,"content":[{"text":"Hi"}]},{"type":"paragraph","content":[{"text":"b","marks":{"strong":true}}]}]}
    ),
  )
}

///|
test "sample roundtrip" {
  let doc = sample_doc()
  @debug.assert_eq(@codec.parse(@codec.to_string(doc)), doc)
}

///|
test "roundtrip property" {
  @quickcheck.check(fn(doc : @ast.Document) {
    let result : Result[@ast.Document, @codec.CodecError] = Ok(
      @codec.parse(@codec.to_string(doc)),
    ) catch {
      e => Err(e)
    }
    result == Ok(doc)
  })
}

///|
test "parse errors" {
  @debug.assert_eq(error_kind("not json"), "invalid_json")
  @debug.assert_eq(error_kind(""), "invalid_json")
  @debug.assert_eq(error_kind("[1,2]"), "schema")
  @debug.assert_eq(
    error_kind("{\"type\":\"document\",\"version\":2,\"blocks\":[]}"),
    "schema",
  )
  @debug.assert_eq(
    error_kind("{\"type\":\"document\",\"version\":1}"),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[],\"extra\":true}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"type\":\"document\",\"version\":1,\"blocks\":[]}",
    ),
    "invalid_json",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"video\"}]}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1.5,\"content\":[]}]}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"paragraph\",\"content\":[{\"text\":\"x\",\"marks\":{\"blink\":true}}]}]}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"figure\",\"src\":\"a\",\"alt\":\"b\",\"caption\":42}]}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind("{\"type\":\"doc\",\"version\":1,\"blocks\":[]}"),
    "schema",
  )
  @debug.assert_eq(
    error_kind("{\"type\":42,\"version\":1,\"blocks\":[]}"),
    "schema",
  )
  @debug.assert_eq(
    error_kind("{\"type\":\"document\",\"version\":\"1\",\"blocks\":[]}"),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"list\",\"ordered\":\"yes\",\"items\":[]}]}",
    ),
    "schema",
  )
  @debug.assert_eq(
    error_kind(
      "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"code\",\"text\":\"y\",\"language\":42}]}",
    ),
    "schema",
  )
}

///|
test "parse accepts explicit false marks and null language" {
  let text = "{\"type\":\"document\",\"version\":1,\"blocks\":[" +
    "{\"type\":\"paragraph\",\"content\":[{\"text\":\"x\",\"marks\":{\"emphasis\":false,\"strong\":true}}]}," +
    "{\"type\":\"code\",\"text\":\"y\",\"language\":null}]}"
  let doc = @codec.parse(text)
  @debug.assert_eq(doc, {
    blocks: [
      @ast.Block::Paragraph([
        @ast.Run::marked("x", @ast.Marks::{ ..@ast.Marks(), strong: true, }),
      ]),
      @ast.Block::CodeBlock("y", None),
    ],
  })
}

///|
test (b : @bench.T) {
  let doc = sample_doc()
  let text = @codec.to_string(doc)
  b.bench(name="encode sample", fn() { b.keep(@codec.to_string(doc)) })
  b.bench(name="parse sample", fn() {
    b.keep(Ok(@codec.parse(text)) catch { e => Err(e) })
  })
}

///|
fn large_doc() -> @ast.Document {
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
  let doc = large_doc()
  let text = @codec.to_string(doc)
  b.bench(name="encode large (1000 blocks)", fn() {
    b.keep(@codec.to_string(doc))
  })
  b.bench(name="parse large (1000 blocks)", fn() {
    b.keep(Ok(@codec.parse(text)) catch { e => Err(e) })
  })
}
