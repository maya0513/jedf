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

///|
/// Valid documents in the standard format, used as bases for mutation
/// testing.
fn corpus() -> Array[String] {
  [
    @codec.to_string(sample_doc()),
    "{\"type\":\"document\",\"version\":1,\"blocks\":[]}",
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":3,\"content\":[{\"text\":\"h\"}]}]}",
  ]
}

///|
/// `seed mod n`, always in `0..n` even for negative seeds.
fn pick(seed : Int32, n : Int32) -> Int32 {
  if n <= 0 {
    0
  } else {
    let r = seed % n
    if r < 0 {
      r + n
    } else {
      r
    }
  }
}

///|
fn from_chars(chars : Array[Char]) -> String {
  let builder = StringBuilder()
  for c in chars {
    builder.write_char(c)
  }
  builder.to_string()
}

///|
fn to_chars(text : String) -> Array[Char] {
  let out : Array[Char] = []
  for c in text {
    out.push(c)
  }
  out
}

///|
/// Parse, returning `None` instead of raising on invalid input.
fn try_parse(text : String) -> @ast.Document? {
  Some(@codec.parse(text)) catch {
    _ => None
  }
}

///|
/// Decode, returning `None` instead of raising on invalid input.
fn try_from_json(value : @json.Json) -> @ast.Document? {
  Some(@codec.from_json(value)) catch {
    _ => None
  }
}

///|
/// Apply one small mutation to `base`, chosen by `seed`: delete the
/// character at an index, insert `junk` there, replace the character
/// there, or truncate at that index.
fn mutate(base : String, seed : Int32, junk : String) -> String {
  let chars = to_chars(base)
  if chars.length() == 0 {
    return junk
  }
  let idx = pick(seed, chars.length())
  match pick(seed / 7, 4) {
    0 => {
      let out : Array[Char] = []
      for i, c in chars {
        if i != idx {
          out.push(c)
        }
      }
      from_chars(out)
    }
    1 => {
      let out : Array[Char] = []
      for i, c in chars {
        if i == idx {
          for jc in junk {
            out.push(jc)
          }
        }
        out.push(c)
      }
      from_chars(out)
    }
    2 => {
      let out = chars.copy()
      out[idx] = '"'
      from_chars(out)
    }
    _ => from_chars(chars[:idx].to_owned())
  }
}

///|
/// The property behind the next three tests: parsing arbitrary or
/// mutated input either succeeds or raises `CodecError`. Any other
/// failure (a panic) fails the test run itself.
test "parse never panics on arbitrary text" {
  @quickcheck.check(fn(text : String) {
    match try_parse(text) {
      None => true
      Some(doc) => try_parse(@codec.to_string(doc)) == Some(doc)
    }
  })
}

///|
test "parse never panics on mutated documents" {
  let bases = corpus()
  @quickcheck.check(fn(pair : (Int32, String)) {
    let (seed, junk) = pair
    let text = mutate(bases[pick(seed, bases.length())], seed, junk)
    match try_parse(text) {
      None => true
      Some(doc) => try_parse(@codec.to_string(doc)) == Some(doc)
    }
  })
}

///|
test "from_json never panics on mutated documents" {
  let bases = corpus()
  @quickcheck.check(fn(pair : (Int32, String)) {
    let (seed, junk) = pair
    let text = mutate(bases[pick(seed, bases.length())], seed, junk)
    let value : Result[@json.Json, @json.ParseError] = Ok(
      @json.parse(text[:], reject_duplicate_keys=true),
    ) catch {
      e => Err(e)
    }
    match value {
      Err(_) => true
      Ok(json) =>
        match try_from_json(json) {
          None => true
          Some(doc) => try_from_json(@codec.to_json(doc)) == Some(doc)
        }
    }
  })
}

///|
/// The format does not normalize Unicode text (decided 2026-11-22):
/// decomposed text round-trips exactly, scalar for scalar.
test "text is preserved without normalization" {
  // U+304B followed by U+3099 (combining dakuten) is the decomposed
  // form of the single scalar U+304C.
  let text = "か\u{3099}"
  @debug.assert_eq(@ast.count_scalars(text), 2)
  let doc : @ast.Document = {
    blocks: [@ast.Block::Paragraph([@ast.Run::plain(text)])],
  }
  let parsed = @codec.parse(@codec.to_string(doc))
  @debug.assert_eq(parsed, doc)
  match parsed.blocks[0] {
    @ast.Block::Paragraph(runs) =>
      @debug.assert_eq(@ast.count_scalars(runs[0].text), 2)
    _ => @debug.assert_eq("wrong block", "paragraph")
  }
}
