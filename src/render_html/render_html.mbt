///|
/// Render a document as an HTML fragment (the Flow View reference
/// rendering). The output is a fragment, not a complete HTML page: embedding
/// it in a page is the caller's job. All text and attribute values are
/// escaped. The input is expected to have passed validation; out-of-range
/// heading levels are clamped into 1..6 rather than emitted as invalid HTML.
pub fn render(doc : @ast.Document) -> String {
  let buffer = StringBuilder()
  render_blocks(buffer, doc.blocks, 1)
  buffer.to_string()
}

///|
fn render_blocks(
  buffer : StringBuilder,
  blocks : Array[@ast.Block],
  section_depth : Int32,
) -> Unit {
  for block in blocks {
    render_block(buffer, block, section_depth)
  }
}

///|
fn render_block(
  buffer : StringBuilder,
  block : @ast.Block,
  section_depth : Int32,
) -> Unit {
  match block {
    @ast.Block::Heading(level, runs) => {
      let tag = "h\{@level.clamp_heading_level(level)}"
      buffer.write_string("<\{tag}>")
      render_runs(buffer, runs)
      buffer.write_string("</\{tag}>\n")
    }
    @ast.Block::Paragraph(runs) => {
      buffer.write_string("<p>")
      render_runs(buffer, runs)
      buffer.write_string("</p>\n")
    }
    @ast.Block::Section(title, children) => {
      buffer.write_string("<section>\n")
      let tag = "h\{@level.clamp_heading_level(section_depth + 1)}"
      buffer.write_string("<\{tag}>")
      render_runs(buffer, title)
      buffer.write_string("</\{tag}>\n")
      render_blocks(buffer, children, section_depth + 1)
      buffer.write_string("</section>\n")
    }
    @ast.Block::ListBlock(ordered, items) => {
      let tag = if ordered { "ol" } else { "ul" }
      buffer.write_string("<\{tag}>\n")
      for item in items {
        buffer.write_string("<li>\n")
        render_blocks(buffer, item, section_depth)
        buffer.write_string("</li>\n")
      }
      buffer.write_string("</\{tag}>\n")
    }
    @ast.Block::TableBlock(rows) => render_table(buffer, rows, section_depth)
    @ast.Block::CodeBlock(text, language) => {
      buffer.write_string("<pre><code")
      match language {
        Some(lang) => {
          buffer.write_string(" class=\"language-")
          buffer.write_string(escape(lang))
          buffer.write_string("\"")
        }
        None => ()
      }
      buffer.write_string(">")
      buffer.write_string(escape(text))
      buffer.write_string("</code></pre>\n")
    }
    @ast.Block::MathBlock(source) => {
      buffer.write_string("<div class=\"math\">")
      buffer.write_string(escape(source))
      buffer.write_string("</div>\n")
    }
    @ast.Block::FigureBlock(source, alt, caption) => {
      buffer.write_string("<figure>\n<img src=\"")
      buffer.write_string(escape(source))
      buffer.write_string("\" alt=\"")
      buffer.write_string(escape(alt))
      buffer.write_string("\">\n")
      match caption {
        Some(runs) => {
          buffer.write_string("<figcaption>")
          render_runs(buffer, runs)
          buffer.write_string("</figcaption>\n")
        }
        None => ()
      }
      buffer.write_string("</figure>\n")
    }
    @ast.Block::FootnoteBlock(id, children) => {
      buffer.write_string("<aside class=\"footnote\" id=\"fn-")
      buffer.write_string(escape(id))
      buffer.write_string("\">\n")
      render_blocks(buffer, children, section_depth)
      buffer.write_string("</aside>\n")
    }
    @ast.Block::PageBreakHint =>
      buffer.write_string("<hr class=\"page-break\">\n")
  }
}

///|
fn render_table(
  buffer : StringBuilder,
  rows : Array[@ast.TableRow],
  section_depth : Int32,
) -> Unit {
  buffer.write_string("<table>\n")
  for i, row in rows {
    if i == 0 && row.header {
      buffer.write_string("<thead>\n")
      render_row(buffer, row, "th", section_depth)
      buffer.write_string("</thead>\n<tbody>\n")
    } else if i == 0 {
      buffer.write_string("<tbody>\n")
      render_row(buffer, row, "td", section_depth)
    } else {
      render_row(
        buffer,
        row,
        if row.header {
          "th"
        } else {
          "td"
        },
        section_depth,
      )
    }
  }
  if rows.length() > 0 {
    buffer.write_string("</tbody>\n")
  }
  buffer.write_string("</table>\n")
}

///|
fn render_row(
  buffer : StringBuilder,
  row : @ast.TableRow,
  cell_tag : String,
  section_depth : Int32,
) -> Unit {
  buffer.write_string("<tr>\n")
  for cell in row.cells {
    buffer.write_string("<\{cell_tag}>\n")
    render_blocks(buffer, cell, section_depth)
    buffer.write_string("</\{cell_tag}>\n")
  }
  buffer.write_string("</tr>\n")
}

///|
fn render_runs(buffer : StringBuilder, runs : Array[@ast.Run]) -> Unit {
  for run in runs {
    buffer.write_string(render_run(run))
  }
}

///|
fn render_run(run : @ast.Run) -> String {
  let mut html = escape(run.text)
  let marks = run.marks
  if marks.code {
    html = "<code>\{html}</code>"
  }
  if marks.math {
    html = "<span class=\"math\">\{html}</span>"
  }
  if marks.emphasis {
    html = "<em>\{html}</em>"
  }
  if marks.strong {
    html = "<strong>\{html}</strong>"
  }
  match marks.link {
    Some(url) => html = "<a href=\"\{escape(url)}\">\{html}</a>"
    None => ()
  }
  html
}

///|
/// Escape text for HTML content and double-quoted attribute values.
pub fn escape(text : String) -> String {
  let buffer = StringBuilder()
  for ch in text {
    match ch {
      '&' => buffer.write_string("&amp;")
      '<' => buffer.write_string("&lt;")
      '>' => buffer.write_string("&gt;")
      '"' => buffer.write_string("&quot;")
      '\'' => buffer.write_string("&#39;")
      _ => buffer.write_char(ch)
    }
  }
  buffer.to_string()
}
