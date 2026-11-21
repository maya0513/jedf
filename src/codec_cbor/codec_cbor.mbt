///|
/// Errors raised when decoding the CBOR encoding. `InvalidCbor` means
/// the input is not CBOR in the subset jedf uses; `Schema` means it
/// decodes as CBOR but does not follow the jedf schema.
#derive(Eq, Debug)
pub(all) suberror CborError {
  InvalidCbor(String)
  Schema(String)
}

///|
/// The CBOR value model: only the types the jedf schema uses.
/// Integers keep their sign split (major types 0 and 1) so that the
/// full UInt64 argument range is representable before schema checks.
priv enum Cbor {
  UInt(UInt64)
  NegInt(UInt64)
  Text(String)
  Array(Array[Cbor])
  Map(Array[(String, Cbor)])
  Bool(Bool)
  Null
}

///|
fn txt(text : String) -> Cbor {
  Cbor::Text(text)
}

///|
fn int(value : Int32) -> Cbor {
  if value >= 0 {
    Cbor::UInt(value.to_uint64())
  } else {
    Cbor::NegInt((-1 - value).to_uint64())
  }
}

///|
fn map(fields : Array[(String, Cbor)]) -> Cbor {
  Cbor::Map(fields)
}

///|
/// Encode a document as CBOR bytes. The schema is the same as the
/// JSON standard format, with CBOR maps, arrays, text, integers,
/// booleans, and null in place of the JSON values. Map keys are
/// emitted in the schema's fixed order and integer arguments in
/// shortest form, so equal documents encode to equal bytes.
pub fn to_bytes(doc : @ast.Document) -> Bytes {
  let out : Array[Byte] = []
  write_value(out, document_to_cbor(doc))
  Bytes::from_array(out[:])
}

///|
/// Parse CBOR bytes in the jedf encoding. Raises `CborError` on any
/// problem; never panics, whatever the input contains.
pub fn parse(data : Bytes) -> @ast.Document raise CborError {
  let reader = Reader::{ data, pos: 0, }
  let value = read_value(reader, 0)
  if reader.pos != data.length() {
    raise CborError::InvalidCbor("trailing bytes after the document")
  }
  document_from_cbor(value)
}

///|
fn document_to_cbor(doc : @ast.Document) -> Cbor {
  map([
    ("type", txt("document")),
    ("version", int(@codec.format_version)),
    ("blocks", Cbor::Array(doc.blocks.map(block_to_cbor))),
  ])
}

///|
fn block_to_cbor(block : @ast.Block) -> Cbor {
  match block {
    @ast.Block::Heading(level, runs) =>
      map([
        ("type", txt("heading")),
        ("level", int(level)),
        ("content", runs_to_cbor(runs)),
      ])
    @ast.Block::Paragraph(runs) =>
      map([("type", txt("paragraph")), ("content", runs_to_cbor(runs))])
    @ast.Block::Section(title, children) =>
      map([
        ("type", txt("section")),
        ("title", runs_to_cbor(title)),
        ("blocks", blocks_to_cbor(children)),
      ])
    @ast.Block::ListBlock(ordered, items) =>
      map([
        ("type", txt("list")),
        ("ordered", Cbor::Bool(ordered)),
        ("items", Cbor::Array(items.map(fn(item) { blocks_to_cbor(item) }))),
      ])
    @ast.Block::TableBlock(rows) =>
      map([
        ("type", txt("table")),
        (
          "rows",
          Cbor::Array(
            rows.map(fn(row) {
              map([
                ("header", Cbor::Bool(row.header)),
                (
                  "cells",
                  Cbor::Array(row.cells.map(fn(cell) { blocks_to_cbor(cell) })),
                ),
              ])
            }),
          ),
        ),
      ])
    @ast.Block::CodeBlock(text, language) =>
      map([
        ("type", txt("code")),
        ("text", txt(text)),
        (
          "language",
          match language {
            Some(value) => txt(value)
            None => Cbor::Null
          },
        ),
      ])
    @ast.Block::MathBlock(source) =>
      map([("type", txt("math")), ("source", txt(source))])
    @ast.Block::FigureBlock(source, alt, caption) =>
      map([
        ("type", txt("figure")),
        ("src", txt(source)),
        ("alt", txt(alt)),
        (
          "caption",
          match caption {
            Some(runs) => runs_to_cbor(runs)
            None => Cbor::Null
          },
        ),
      ])
    @ast.Block::FootnoteBlock(id, children) =>
      map([
        ("type", txt("footnote")),
        ("id", txt(id)),
        ("blocks", blocks_to_cbor(children)),
      ])
    @ast.Block::PageBreakHint => map([("type", txt("page_break"))])
  }
}

///|
fn blocks_to_cbor(blocks : Array[@ast.Block]) -> Cbor {
  Cbor::Array(blocks.map(block_to_cbor))
}

///|
fn runs_to_cbor(runs : Array[@ast.Run]) -> Cbor {
  Cbor::Array(runs.map(run_to_cbor))
}

///|
fn run_to_cbor(run : @ast.Run) -> Cbor {
  let marks = run.marks
  if marks == @ast.Marks() {
    map([("text", txt(run.text))])
  } else {
    let fields : Array[(String, Cbor)] = []
    if marks.emphasis {
      fields.push(("emphasis", Cbor::Bool(true)))
    }
    if marks.strong {
      fields.push(("strong", Cbor::Bool(true)))
    }
    if marks.code {
      fields.push(("code", Cbor::Bool(true)))
    }
    if marks.math {
      fields.push(("math", Cbor::Bool(true)))
    }
    match marks.link {
      Some(url) => fields.push(("link", txt(url)))
      None => ()
    }
    map([("text", txt(run.text)), ("marks", Cbor::Map(fields))])
  }
}

///|
fn write_header(out : Array[Byte], major : Int32, value : UInt64) -> Unit {
  let base = major << 5
  if value < 24 {
    out.push((base | value.to_int()).to_byte())
  } else if value < 256 {
    out.push((base | 24).to_byte())
    out.push(value.to_int().to_byte())
  } else if value < 65536 {
    out.push((base | 25).to_byte())
    push_be(out, value, 2)
  } else if value < 4294967296 {
    out.push((base | 26).to_byte())
    push_be(out, value, 4)
  } else {
    out.push((base | 27).to_byte())
    push_be(out, value, 8)
  }
}

///|
fn push_be(out : Array[Byte], value : UInt64, count : Int32) -> Unit {
  for i in 0..<count {
    let shift = (count - 1 - i) * 8
    out.push(((value >> shift) & 0xFF).to_int().to_byte())
  }
}

///|
fn write_value(out : Array[Byte], value : Cbor) -> Unit {
  match value {
    Cbor::UInt(number) => write_header(out, 0, number)
    Cbor::NegInt(number) => write_header(out, 1, number)
    Cbor::Text(text) => {
      let bytes = @utf8.encode(text[:])
      write_header(out, 3, bytes.length().to_uint64())
      for b in bytes {
        out.push(b)
      }
    }
    Cbor::Array(items) => {
      write_header(out, 4, items.length().to_uint64())
      for item in items {
        write_value(out, item)
      }
    }
    Cbor::Map(fields) => {
      write_header(out, 5, fields.length().to_uint64())
      for (key, field_value) in fields {
        write_value(out, txt(key))
        write_value(out, field_value)
      }
    }
    Cbor::Bool(true) => out.push(0xF5)
    Cbor::Bool(false) => out.push(0xF4)
    Cbor::Null => out.push(0xF6)
  }
}

///|
priv struct Reader {
  data : Bytes
  mut pos : Int32
}

///|
fn Reader::read_byte(self : Reader) -> Int32 raise CborError {
  if self.pos >= self.data.length() {
    raise CborError::InvalidCbor("unexpected end of input")
  }
  let byte = self.data[self.pos].to_int()
  self.pos = self.pos + 1
  byte
}

///|
fn Reader::read_bytes(self : Reader, length : Int32) -> Bytes raise CborError {
  if length < 0 || self.pos + length > self.data.length() {
    raise CborError::InvalidCbor("unexpected end of input")
  }
  let slice = self.data[self.pos:self.pos + length].to_owned()
  self.pos = self.pos + length
  slice
}

///|
fn read_argument(reader : Reader, info : Int32) -> UInt64 raise CborError {
  if info < 24 {
    info.to_uint64()
  } else if info == 24 {
    reader.read_byte().to_uint64()
  } else if info == 25 {
    read_be(reader, 2)
  } else if info == 26 {
    read_be(reader, 4)
  } else if info == 27 {
    read_be(reader, 8)
  } else {
    raise CborError::InvalidCbor("indefinite lengths are not supported")
  }
}

///|
fn read_be(reader : Reader, count : Int32) -> UInt64 raise CborError {
  let mut value : UInt64 = 0
  for _ in 0..<count {
    value = (value << 8) | reader.read_byte().to_uint64()
  }
  value
}

///|
fn read_length(reader : Reader, info : Int32) -> Int32 raise CborError {
  let value = read_argument(reader, info)
  if value > 2147483647 {
    raise CborError::InvalidCbor("length is too large")
  }
  value.to_int()
}

///|
/// Nesting deeper than this cannot occur in a valid document and is
/// rejected to bound the reader's stack use.
let max_depth : Int32 = 256

///|
fn read_value(reader : Reader, depth : Int32) -> Cbor raise CborError {
  if depth > max_depth {
    raise CborError::InvalidCbor("the value is nested too deeply")
  }
  let first = reader.read_byte()
  let major = first >> 5
  let info = first & 0x1F
  match major {
    0 => Cbor::UInt(read_argument(reader, info))
    1 => Cbor::NegInt(read_argument(reader, info))
    2 => raise CborError::InvalidCbor("byte strings are not used in jedf CBOR")
    3 => {
      let length = read_length(reader, info)
      let bytes = reader.read_bytes(length)
      let text = @utf8.decode(bytes) catch {
        _ => raise CborError::InvalidCbor("a text string is not valid UTF-8")
      }
      Cbor::Text(text)
    }
    4 => {
      let length = read_length(reader, info)
      let items : Array[Cbor] = []
      for _ in 0..<length {
        items.push(read_value(reader, depth + 1))
      }
      Cbor::Array(items)
    }
    5 => {
      let length = read_length(reader, info)
      let fields : Array[(String, Cbor)] = []
      for _ in 0..<length {
        let key = match read_value(reader, depth + 1) {
          Cbor::Text(text) => text
          _ => raise CborError::InvalidCbor("map keys must be text")
        }
        for (existing, _) in fields {
          if existing == key {
            raise CborError::InvalidCbor("duplicate map key: \{key}")
          }
        }
        fields.push((key, read_value(reader, depth + 1)))
      }
      Cbor::Map(fields)
    }
    6 => raise CborError::InvalidCbor("tags are not used in jedf CBOR")
    _ =>
      match info {
        20 => Cbor::Bool(false)
        21 => Cbor::Bool(true)
        22 => Cbor::Null
        _ => raise CborError::InvalidCbor("unsupported simple or float value")
      }
  }
}

///|
fn get_field(
  fields : Array[(String, Cbor)],
  key : String,
) -> Cbor raise CborError {
  for (existing, value) in fields {
    if existing == key {
      return value
    }
  }
  raise CborError::Schema("missing field: \{key}")
}

///|
fn find_field(fields : Array[(String, Cbor)], key : String) -> Cbor? {
  for (existing, value) in fields {
    if existing == key {
      return Some(value)
    }
  }
  None
}

///|
fn check_keys(
  fields : Array[(String, Cbor)],
  allowed : Array[String],
  what : String,
) -> Unit raise CborError {
  for (key, _) in fields {
    if !allowed.contains(key) {
      raise CborError::Schema("unknown field in \{what}: \{key}")
    }
  }
}

///|
fn as_map(value : Cbor, what : String) -> Array[(String, Cbor)] raise CborError {
  match value {
    Cbor::Map(fields) => fields
    _ => raise CborError::Schema("\{what} must be a map")
  }
}

///|
fn as_array(value : Cbor, what : String) -> Array[Cbor] raise CborError {
  match value {
    Cbor::Array(items) => items
    _ => raise CborError::Schema("\{what} must be an array")
  }
}

///|
fn as_text(value : Cbor, what : String) -> String raise CborError {
  match value {
    Cbor::Text(text) => text
    _ => raise CborError::Schema("\{what} must be a string")
  }
}

///|
fn as_bool(value : Cbor, what : String) -> Bool raise CborError {
  match value {
    Cbor::Bool(flag) => flag
    _ => raise CborError::Schema("\{what} must be a boolean")
  }
}

///|
fn as_int(value : Cbor, what : String) -> Int32 raise CborError {
  match value {
    Cbor::UInt(number) =>
      if number <= 2147483647 {
        number.to_int()
      } else {
        raise CborError::Schema("\{what} must be a 32-bit integer")
      }
    Cbor::NegInt(number) =>
      if number <= 2147483647 {
        -1 - number.to_int()
      } else {
        raise CborError::Schema("\{what} must be a 32-bit integer")
      }
    _ => raise CborError::Schema("\{what} must be an integer")
  }
}

///|
fn as_opt_text(value : Cbor, what : String) -> String? raise CborError {
  match value {
    Cbor::Null => None
    Cbor::Text(text) => Some(text)
    _ => raise CborError::Schema("\{what} must be a string or null")
  }
}

///|
fn document_from_cbor(value : Cbor) -> @ast.Document raise CborError {
  let fields = as_map(value, "document")
  check_keys(fields, ["type", "version", "blocks"], "document")
  match as_text(get_field(fields, "type"), "document.type") {
    "document" => ()
    other =>
      raise CborError::Schema(
        "document.type must be \"document\", got \"\{other}\"",
      )
  }
  let version = as_int(get_field(fields, "version"), "document.version")
  if version != @codec.format_version {
    raise CborError::Schema("unsupported format version: \{version}")
  }
  let blocks = as_array(get_field(fields, "blocks"), "document.blocks")
  { blocks: blocks.map(item => block_from_cbor(item)), }
}

///|
fn block_from_cbor(value : Cbor) -> @ast.Block raise CborError {
  let fields = as_map(value, "block")
  let kind = as_text(get_field(fields, "type"), "block.type")
  match kind {
    "heading" => {
      check_keys(fields, ["type", "level", "content"], "heading")
      @ast.Block::Heading(
        as_int(get_field(fields, "level"), "heading.level"),
        runs_from_cbor(get_field(fields, "content")),
      )
    }
    "paragraph" => {
      check_keys(fields, ["type", "content"], "paragraph")
      @ast.Block::Paragraph(runs_from_cbor(get_field(fields, "content")))
    }
    "section" => {
      check_keys(fields, ["type", "title", "blocks"], "section")
      @ast.Block::Section(
        runs_from_cbor(get_field(fields, "title")),
        blocks_from_cbor(get_field(fields, "blocks")),
      )
    }
    "list" => {
      check_keys(fields, ["type", "ordered", "items"], "list")
      let items = as_array(get_field(fields, "items"), "list.items")
      @ast.Block::ListBlock(
        as_bool(get_field(fields, "ordered"), "list.ordered"),
        items.map(item => blocks_from_cbor(item)),
      )
    }
    "table" => {
      check_keys(fields, ["type", "rows"], "table")
      let rows = as_array(get_field(fields, "rows"), "table.rows")
      @ast.Block::TableBlock(rows.map(row_from_cbor))
    }
    "code" => {
      check_keys(fields, ["type", "text", "language"], "code")
      @ast.Block::CodeBlock(
        as_text(get_field(fields, "text"), "code.text"),
        as_opt_text(get_field(fields, "language"), "code.language"),
      )
    }
    "math" => {
      check_keys(fields, ["type", "source"], "math")
      @ast.Block::MathBlock(as_text(get_field(fields, "source"), "math.source"))
    }
    "figure" => {
      check_keys(fields, ["type", "src", "alt", "caption"], "figure")
      let caption = match get_field(fields, "caption") {
        Cbor::Null => None
        value => Some(runs_from_cbor(value))
      }
      @ast.Block::FigureBlock(
        as_text(get_field(fields, "src"), "figure.src"),
        as_text(get_field(fields, "alt"), "figure.alt"),
        caption,
      )
    }
    "footnote" => {
      check_keys(fields, ["type", "id", "blocks"], "footnote")
      @ast.Block::FootnoteBlock(
        as_text(get_field(fields, "id"), "footnote.id"),
        blocks_from_cbor(get_field(fields, "blocks")),
      )
    }
    "page_break" => {
      check_keys(fields, ["type"], "page_break")
      @ast.Block::PageBreakHint
    }
    other => raise CborError::Schema("unknown block type: \{other}")
  }
}

///|
fn row_from_cbor(value : Cbor) -> @ast.TableRow raise CborError {
  let fields = as_map(value, "table row")
  check_keys(fields, ["header", "cells"], "table row")
  let cells = as_array(get_field(fields, "cells"), "row.cells")
  {
    header: as_bool(get_field(fields, "header"), "row.header"),
    cells: cells.map(cell => blocks_from_cbor(cell)),
  }
}

///|
fn blocks_from_cbor(value : Cbor) -> Array[@ast.Block] raise CborError {
  as_array(value, "blocks").map(item => block_from_cbor(item))
}

///|
fn runs_from_cbor(value : Cbor) -> Array[@ast.Run] raise CborError {
  as_array(value, "content").map(item => run_from_cbor(item))
}

///|
fn run_from_cbor(value : Cbor) -> @ast.Run raise CborError {
  let fields = as_map(value, "run")
  check_keys(fields, ["text", "marks"], "run")
  let marks = match find_field(fields, "marks") {
    Some(marks_value) => marks_from_cbor(marks_value)
    None => @ast.Marks()
  }
  { text: as_text(get_field(fields, "text"), "run.text"), marks, }
}

///|
fn marks_from_cbor(value : Cbor) -> @ast.Marks raise CborError {
  let fields = as_map(value, "marks")
  check_keys(fields, ["emphasis", "strong", "code", "math", "link"], "marks")
  let mut marks = @ast.Marks()
  match find_field(fields, "emphasis") {
    Some(v) => marks = { ..marks, emphasis: as_bool(v, "marks.emphasis"), }
    None => ()
  }
  match find_field(fields, "strong") {
    Some(v) => marks = { ..marks, strong: as_bool(v, "marks.strong"), }
    None => ()
  }
  match find_field(fields, "code") {
    Some(v) => marks = { ..marks, code: as_bool(v, "marks.code"), }
    None => ()
  }
  match find_field(fields, "math") {
    Some(v) => marks = { ..marks, math: as_bool(v, "marks.math"), }
    None => ()
  }
  match find_field(fields, "link") {
    Some(v) => marks = { ..marks, link: Some(as_text(v, "marks.link")), }
    None => ()
  }
  marks
}
