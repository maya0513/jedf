///|
/// Errors raised when decoding the standard JSON format. `InvalidJson` means
/// the input is not JSON at all; `Schema` means it is JSON but does not
/// follow the jedf schema.
#derive(Eq, Debug)
pub(all) suberror CodecError {
  InvalidJson(String)
  Schema(String)
}

///|
/// The version of the standard format written by this implementation.
pub let format_version : Int32 = 1

///|
/// Encode a document as a `Json` value. Object keys are emitted in the
/// schema's fixed order, so equal documents encode to equal text.
pub fn to_json(doc : @ast.Document) -> @json.Json {
  object([
    ("type", @json.Json::string("document")),
    ("version", @json.Json::number(format_version.to_double())),
    ("blocks", @json.Json::array(doc.blocks.map(block_to_json))),
  ])
}

///|
/// Encode a document as JSON text in the standard format.
pub fn to_string(doc : @ast.Document) -> String {
  to_json(doc).stringify()
}

///|
/// Parse JSON text in the standard format. Raises `CodecError` on any
/// problem; never panics, whatever the input contains.
pub fn parse(text : String) -> @ast.Document raise CodecError {
  let value = @json.parse(text[:], reject_duplicate_keys=true) catch {
    e => raise CodecError::InvalidJson(e.to_string())
  }
  from_json(value)
}

///|
/// Decode a document from a `Json` value.
pub fn from_json(value : @json.Json) -> @ast.Document raise CodecError {
  let fields = as_object(value, "document")
  check_keys(fields, ["type", "version", "blocks"], "document")
  match as_string(get(fields, "type"), "document.type") {
    "document" => ()
    other =>
      raise CodecError::Schema(
        "document.type must be \"document\", got \"\{other}\"",
      )
  }
  let version = as_int(get(fields, "version"), "document.version")
  if version != format_version {
    raise CodecError::Schema("unsupported format version: \{version}")
  }
  let blocks = as_array(get(fields, "blocks"), "document.blocks")
  { blocks: blocks.map(item => block_from_json(item)), }
}

///|
fn object(fields : Array[(String, @json.Json)]) -> @json.Json {
  let map : Map[String, @json.Json] = Map([])
  for (key, value) in fields {
    map[key] = value
  }
  @json.Json::object(map)
}

///|
fn get(
  fields : Map[String, @json.Json],
  key : String,
) -> @json.Json raise CodecError {
  match fields.get(key) {
    Some(value) => value
    None => raise CodecError::Schema("missing field: \{key}")
  }
}

///|
fn check_keys(
  fields : Map[String, @json.Json],
  allowed : Array[String],
  what : String,
) -> Unit raise CodecError {
  for (key, _) in fields {
    if !allowed.contains(key) {
      raise CodecError::Schema("unknown field in \{what}: \{key}")
    }
  }
}

///|
fn as_object(
  value : @json.Json,
  what : String,
) -> Map[String, @json.Json] raise CodecError {
  match value {
    @json.Json::Object(fields) => fields
    _ => raise CodecError::Schema("\{what} must be an object")
  }
}

///|
fn as_array(
  value : @json.Json,
  what : String,
) -> Array[@json.Json] raise CodecError {
  match value {
    @json.Json::Array(items) => items
    _ => raise CodecError::Schema("\{what} must be an array")
  }
}

///|
fn as_string(value : @json.Json, what : String) -> String raise CodecError {
  match value {
    @json.Json::String(text) => text
    _ => raise CodecError::Schema("\{what} must be a string")
  }
}

///|
fn as_bool(value : @json.Json, what : String) -> Bool raise CodecError {
  match value {
    @json.Json::True => true
    @json.Json::False => false
    _ => raise CodecError::Schema("\{what} must be a boolean")
  }
}

///|
fn as_int(value : @json.Json, what : String) -> Int32 raise CodecError {
  match value {
    @json.Json::Number(number, ..) =>
      if number == number.floor() &&
        number >= -2147483648.0 &&
        number <= 2147483647.0 {
        number.to_int()
      } else {
        raise CodecError::Schema("\{what} must be a 32-bit integer")
      }
    _ => raise CodecError::Schema("\{what} must be a number")
  }
}

///|
fn as_opt_string(value : @json.Json, what : String) -> String? raise CodecError {
  match value {
    @json.Json::Null => None
    @json.Json::String(text) => Some(text)
    _ => raise CodecError::Schema("\{what} must be a string or null")
  }
}

///|
fn block_to_json(block : @ast.Block) -> @json.Json {
  match block {
    @ast.Block::Heading(level, runs) =>
      object([
        ("type", @json.Json::string("heading")),
        ("level", @json.Json::number(level.to_double())),
        ("content", runs_to_json(runs)),
      ])
    @ast.Block::Paragraph(runs) =>
      object([
        ("type", @json.Json::string("paragraph")),
        ("content", runs_to_json(runs)),
      ])
    @ast.Block::Section(title, children) =>
      object([
        ("type", @json.Json::string("section")),
        ("title", runs_to_json(title)),
        ("blocks", blocks_to_json(children)),
      ])
    @ast.Block::ListBlock(ordered, items) =>
      object([
        ("type", @json.Json::string("list")),
        ("ordered", @json.Json::boolean(ordered)),
        (
          "items",
          @json.Json::array(items.map(fn(item) { blocks_to_json(item) })),
        ),
      ])
    @ast.Block::TableBlock(rows) =>
      object([
        ("type", @json.Json::string("table")),
        (
          "rows",
          @json.Json::array(
            rows.map(fn(row) {
              object([
                ("header", @json.Json::boolean(row.header)),
                (
                  "cells",
                  @json.Json::array(
                    row.cells.map(fn(cell) { blocks_to_json(cell) }),
                  ),
                ),
              ])
            }),
          ),
        ),
      ])
    @ast.Block::CodeBlock(text, language) =>
      object([
        ("type", @json.Json::string("code")),
        ("text", @json.Json::string(text)),
        ("language", opt_string_to_json(language)),
      ])
    @ast.Block::MathBlock(source) =>
      object([
        ("type", @json.Json::string("math")),
        ("source", @json.Json::string(source)),
      ])
    @ast.Block::FigureBlock(source, alt, caption) =>
      object([
        ("type", @json.Json::string("figure")),
        ("src", @json.Json::string(source)),
        ("alt", @json.Json::string(alt)),
        (
          "caption",
          match caption {
            Some(runs) => runs_to_json(runs)
            None => @json.Json::null()
          },
        ),
      ])
    @ast.Block::FootnoteBlock(id, children) =>
      object([
        ("type", @json.Json::string("footnote")),
        ("id", @json.Json::string(id)),
        ("blocks", blocks_to_json(children)),
      ])
    @ast.Block::PageBreakHint =>
      object([("type", @json.Json::string("page_break"))])
  }
}

///|
fn blocks_to_json(blocks : Array[@ast.Block]) -> @json.Json {
  @json.Json::array(blocks.map(block_to_json))
}

///|
fn runs_to_json(runs : Array[@ast.Run]) -> @json.Json {
  @json.Json::array(runs.map(run_to_json))
}

///|
fn opt_string_to_json(value : String?) -> @json.Json {
  match value {
    Some(text) => @json.Json::string(text)
    None => @json.Json::null()
  }
}

///|
fn run_to_json(run : @ast.Run) -> @json.Json {
  let marks = run.marks
  if marks == @ast.Marks() {
    object([("text", @json.Json::string(run.text))])
  } else {
    let fields : Array[(String, @json.Json)] = []
    if marks.emphasis {
      fields.push(("emphasis", @json.Json::boolean(true)))
    }
    if marks.strong {
      fields.push(("strong", @json.Json::boolean(true)))
    }
    if marks.code {
      fields.push(("code", @json.Json::boolean(true)))
    }
    if marks.math {
      fields.push(("math", @json.Json::boolean(true)))
    }
    match marks.link {
      Some(url) => fields.push(("link", @json.Json::string(url)))
      None => ()
    }
    object([("text", @json.Json::string(run.text)), ("marks", object(fields))])
  }
}

///|
fn block_from_json(value : @json.Json) -> @ast.Block raise CodecError {
  let fields = as_object(value, "block")
  let kind = as_string(get(fields, "type"), "block.type")
  match kind {
    "heading" => {
      check_keys(fields, ["type", "level", "content"], "heading")
      @ast.Block::Heading(
        as_int(get(fields, "level"), "heading.level"),
        runs_from_json(get(fields, "content")),
      )
    }
    "paragraph" => {
      check_keys(fields, ["type", "content"], "paragraph")
      @ast.Block::Paragraph(runs_from_json(get(fields, "content")))
    }
    "section" => {
      check_keys(fields, ["type", "title", "blocks"], "section")
      @ast.Block::Section(
        runs_from_json(get(fields, "title")),
        blocks_from_json(get(fields, "blocks")),
      )
    }
    "list" => {
      check_keys(fields, ["type", "ordered", "items"], "list")
      let items = as_array(get(fields, "items"), "list.items")
      @ast.Block::ListBlock(
        as_bool(get(fields, "ordered"), "list.ordered"),
        items.map(item => blocks_from_json(item)),
      )
    }
    "table" => {
      check_keys(fields, ["type", "rows"], "table")
      let rows = as_array(get(fields, "rows"), "table.rows")
      @ast.Block::TableBlock(rows.map(row_from_json))
    }
    "code" => {
      check_keys(fields, ["type", "text", "language"], "code")
      @ast.Block::CodeBlock(
        as_string(get(fields, "text"), "code.text"),
        as_opt_string(get(fields, "language"), "code.language"),
      )
    }
    "math" => {
      check_keys(fields, ["type", "source"], "math")
      @ast.Block::MathBlock(as_string(get(fields, "source"), "math.source"))
    }
    "figure" => {
      check_keys(fields, ["type", "src", "alt", "caption"], "figure")
      let caption = match get(fields, "caption") {
        @json.Json::Null => None
        value => Some(runs_from_json(value))
      }
      @ast.Block::FigureBlock(
        as_string(get(fields, "src"), "figure.src"),
        as_string(get(fields, "alt"), "figure.alt"),
        caption,
      )
    }
    "footnote" => {
      check_keys(fields, ["type", "id", "blocks"], "footnote")
      @ast.Block::FootnoteBlock(
        as_string(get(fields, "id"), "footnote.id"),
        blocks_from_json(get(fields, "blocks")),
      )
    }
    "page_break" => {
      check_keys(fields, ["type"], "page_break")
      @ast.Block::PageBreakHint
    }
    other => raise CodecError::Schema("unknown block type: \{other}")
  }
}

///|
fn row_from_json(value : @json.Json) -> @ast.TableRow raise CodecError {
  let fields = as_object(value, "table row")
  check_keys(fields, ["header", "cells"], "table row")
  let cells = as_array(get(fields, "cells"), "row.cells")
  {
    header: as_bool(get(fields, "header"), "row.header"),
    cells: cells.map(cell => blocks_from_json(cell)),
  }
}

///|
fn blocks_from_json(value : @json.Json) -> Array[@ast.Block] raise CodecError {
  as_array(value, "blocks").map(item => block_from_json(item))
}

///|
fn runs_from_json(value : @json.Json) -> Array[@ast.Run] raise CodecError {
  as_array(value, "content").map(item => run_from_json(item))
}

///|
fn run_from_json(value : @json.Json) -> @ast.Run raise CodecError {
  let fields = as_object(value, "run")
  check_keys(fields, ["text", "marks"], "run")
  let marks = match fields.get("marks") {
    Some(marks_value) => marks_from_json(marks_value)
    None => @ast.Marks()
  }
  { text: as_string(get(fields, "text"), "run.text"), marks, }
}

///|
fn marks_from_json(value : @json.Json) -> @ast.Marks raise CodecError {
  let fields = as_object(value, "marks")
  check_keys(fields, ["emphasis", "strong", "code", "math", "link"], "marks")
  let mut marks = @ast.Marks()
  match fields.get("emphasis") {
    Some(v) => marks = { ..marks, emphasis: as_bool(v, "marks.emphasis"), }
    None => ()
  }
  match fields.get("strong") {
    Some(v) => marks = { ..marks, strong: as_bool(v, "marks.strong"), }
    None => ()
  }
  match fields.get("code") {
    Some(v) => marks = { ..marks, code: as_bool(v, "marks.code"), }
    None => ()
  }
  match fields.get("math") {
    Some(v) => marks = { ..marks, math: as_bool(v, "marks.math"), }
    None => ()
  }
  match fields.get("link") {
    Some(v) => marks = { ..marks, link: Some(as_string(v, "marks.link")), }
    None => ()
  }
  marks
}
