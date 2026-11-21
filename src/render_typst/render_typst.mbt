///|
/// Render a document as Typst source (the print backend input). Typst is
/// used only to produce fixed page layouts; no Typst code from the document
/// itself is ever executed, because the semantic tree contains no code.
/// All document text is escaped for Typst markup, and all strings embedded
/// in Typst string literals are escaped as such.
pub fn render(doc : @ast.Document) -> String {
  let parts = doc.blocks.map(fn(block) { render_block(block, 1) })
  parts.join("\n") + "\n"
}

///|
fn render_blocks(blocks : Array[@ast.Block], depth : Int32) -> String {
  blocks.map(fn(block) { render_block(block, depth) }).join("\n")
}

///|
fn render_block(block : @ast.Block, depth : Int32) -> String {
  match block {
    @ast.Block::Heading(level, runs) =>
      "\{"=".repeat(@level.clamp_heading_level(level))} \{render_runs(runs)}"
    @ast.Block::Paragraph(runs) => render_runs(runs)
    @ast.Block::Section(title, children) => {
      let heading = "\{"=".repeat(@level.clamp_heading_level(depth + 1))} \{render_runs(title)}"
      "\{heading}\n\{render_blocks(children, depth + 1)}"
    }
    @ast.Block::ListBlock(ordered, items) => {
      let marker = if ordered { "+ " } else { "- " }
      items
      .map(fn(item) { indent_item(render_blocks(item, depth), marker) })
      .join("\n")
    }
    @ast.Block::TableBlock(rows) => render_table(rows, depth)
    @ast.Block::CodeBlock(text, language) => {
      let fence = "`".repeat(longest_backtick_run(text) + 1)
      let fence = if fence.length() < 3 { "```" } else { fence }
      match language {
        Some(lang) => "\{fence}\{lang}\n\{text}\n\{fence}"
        None => "\{fence}\n\{text}\n\{fence}"
      }
    }
    @ast.Block::MathBlock(source) => "$ \{source} $"
    @ast.Block::FigureBlock(source, alt, caption) => {
      let image = "image(\"\{escape_string(source)}\", alt: \"\{escape_string(alt)}\")"
      match caption {
        Some(runs) => "#figure(\{image}, caption: [\{render_runs(runs)}])"
        None => "#figure(\{image})"
      }
    }
    @ast.Block::FootnoteBlock(id, children) =>
      "// jedf footnote: \{id}\n\{render_blocks(children, depth)}"
    @ast.Block::PageBreakHint => "#pagebreak()"
  }
}

///|
fn render_table(rows : Array[@ast.TableRow], depth : Int32) -> String {
  let mut columns = 0
  for row in rows {
    if row.cells.length() > columns {
      columns = row.cells.length()
    }
  }
  if columns == 0 {
    return ""
  }
  let parts : Array[String] = ["#table(", "  columns: \{columns},"]
  for i, row in rows {
    let cells = row.cells.map(fn(cell) { "[\{render_blocks(cell, depth)}]" })
    if i == 0 && row.header {
      parts.push("  table.header(\{cells.join(", ")}),")
    } else {
      parts.push("  \{cells.join(", ")},")
    }
  }
  parts.push(")")
  parts.join("\n")
}

///|
fn indent_item(text : String, marker : String) -> String {
  let lines = text.split("\n")
  let parts : Array[String] = []
  for i, line in lines {
    if i == 0 {
      parts.push("\{marker}\{line}")
    } else {
      parts.push("  \{line}")
    }
  }
  parts.join("\n")
}

///|
fn render_runs(runs : Array[@ast.Run]) -> String {
  runs.map(render_run).join("")
}

///|
fn render_run(run : @ast.Run) -> String {
  let marks = run.marks
  let mut content = escape_text(run.text)
  if marks.code {
    let fence = "`".repeat(longest_backtick_run(run.text) + 1)
    content = "\{fence}\{run.text}\{fence}"
  }
  if marks.math {
    content = "$\{run.text}$"
  }
  if marks.emphasis {
    content = "#emph[\{content}]"
  }
  if marks.strong {
    content = "#strong[\{content}]"
  }
  match marks.link {
    Some(url) => content = "#link(\"\{escape_string(url)}\")[\{content}]"
    None => ()
  }
  content
}

///|
fn longest_backtick_run(text : String) -> Int32 {
  let mut longest = 0
  let mut current = 0
  for ch in text {
    if ch == '`' {
      current += 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }
  longest
}

///|
/// Escape text for Typst markup content.
pub fn escape_text(text : String) -> String {
  let buffer = StringBuilder()
  for ch in text {
    match ch {
      '\\'
      | '#'
      | '$'
      | '@'
      | '`'
      | '*'
      | '_'
      | '<'
      | '>'
      | '['
      | ']'
      | '{'
      | '}'
      | '"' => buffer.write_string("\\\{ch}")
      _ => buffer.write_char(ch)
    }
  }
  buffer.to_string()
}

///|
/// Escape a string for use inside a Typst string literal.
pub fn escape_string(text : String) -> String {
  let buffer = StringBuilder()
  for ch in text {
    match ch {
      '\\' => buffer.write_string("\\\\")
      '"' => buffer.write_string("\\\"")
      '\n' => buffer.write_string("\\n")
      '\r' => buffer.write_string("\\r")
      '\t' => buffer.write_string("\\t")
      _ => buffer.write_char(ch)
    }
  }
  buffer.to_string()
}
