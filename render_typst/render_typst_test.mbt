///|
fn sample_doc() -> @ast.Document {
  {
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title #1")]),
      @ast.Block::Paragraph([
        @ast.Run::plain("a*b "),
        @ast.Run::marked("link", @ast.Marks::{
          ..@ast.Marks(),
          strong: true,
          link: Some("https://example.com/\"q\""),
        }),
        @ast.Run::marked("x`y", @ast.Marks::{ ..@ast.Marks(), code: true, }),
        @ast.Run::marked("e=mc^2", @ast.Marks::{
          ..@ast.Marks(),
          emphasis: true,
          math: true,
        }),
      ]),
      @ast.Block::Section([@ast.Run::plain("S")], [
        @ast.Block::ListBlock(true, [
          [@ast.Block::Paragraph([@ast.Run::plain("one")])],
          [
            @ast.Block::Paragraph([@ast.Run::plain("two")]),
            @ast.Block::Paragraph([@ast.Run::plain("lines")]),
          ],
        ]),
      ]),
      @ast.Block::TableBlock([
        @ast.TableRow::{
          header: true,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("h")])]],
        },
        @ast.TableRow::{
          header: false,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("c")])]],
        },
      ]),
      @ast.Block::TableBlock([]),
      @ast.Block::CodeBlock("let x = \"```\"", Some("moonbit")),
      @ast.Block::CodeBlock("plain", None),
      @ast.Block::MathBlock("x^2"),
      @ast.Block::FigureBlock("a\"b.png", "alt", Some([@ast.Run::plain("cap")])),
      @ast.Block::FigureBlock("b.png", "alt2", None),
      @ast.Block::FootnoteBlock("n1", [
        @ast.Block::Paragraph([@ast.Run::plain("note")]),
      ]),
      @ast.Block::PageBreakHint,
    ],
  }
}

///|
test "render snapshot" {
  inspect(
    @render_typst.render(sample_doc()),
    content=(
      #|= Title \#1
      #|a\*b #link("https://example.com/\"q\"")[#strong[link]]``x`y``#emph[$e=mc^2$]
      #|== S
      #|+ one
      #|+ two
      #|  lines
      #|#table(
      #|  columns: 1,
      #|  table.header([h]),
      #|  [c],
      #|)
      #|
      #|````moonbit
      #|let x = "```"
      #|````
      #|```
      #|plain
      #|```
      #|$ x^2 $
      #|#figure(image("a\"b.png", alt: "alt"), caption: [cap])
      #|#figure(image("b.png", alt: "alt2"))
      #|// jedf footnote: n1
      #|note
      #|#pagebreak()
      #|
    ),
  )
}

///|
test "escape text" {
  inspect(
    @render_typst.escape_text("#$@\\`*_<x>[y]{z}\"q\" plain"),
    content=(
      #|\#\$\@\\\`\*\_\<x\>\[y\]\{z\}\"q\" plain
    ),
  )
}

///|
test "escape string" {
  inspect(
    @render_typst.escape_string("a\\b\"c\nd\te\rf"),
    content=(
      #|a\\b\"c\nd\te\rf
    ),
  )
}

///|
test "heading clamp" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Heading(0, [@ast.Run::plain("lo")]),
      @ast.Block::Heading(8, [@ast.Run::plain("hi")]),
    ],
  }
  inspect(
    @render_typst.render(doc),
    content=(
      #|= lo
      #|====== hi
      #|
    ),
  )
}

///|
test (b : @bench.T) {
  let doc = sample_doc()
  b.bench(name="render typst sample", fn() { b.keep(@render_typst.render(doc)) })
}
