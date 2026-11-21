///|
fn codes(issues : Array[@validate.Issue]) -> Array[String] {
  issues.map(fn(issue) { issue.code })
}

///|
fn sample_doc() -> @ast.Document {
  {
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title")]),
      @ast.Block::Paragraph([
        @ast.Run::plain("Hello "),
        @ast.Run::marked("link", @ast.Marks::{
          ..@ast.Marks(),
          link: Some("https://example.com"),
        }),
      ]),
      @ast.Block::Section([@ast.Run::plain("Section")], [
        @ast.Block::Paragraph([@ast.Run::plain("nested")]),
      ]),
      @ast.Block::ListBlock(false, [
        [@ast.Block::Paragraph([@ast.Run::plain("item")])],
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
      @ast.Block::CodeBlock("let x = 1", Some("moonbit")),
      @ast.Block::MathBlock("x^2"),
      @ast.Block::FigureBlock(
        "img.png",
        "an image",
        Some([@ast.Run::plain("caption")]),
      ),
      @ast.Block::FootnoteBlock("n1", [
        @ast.Block::Paragraph([@ast.Run::plain("note")]),
      ]),
      @ast.Block::PageBreakHint,
    ],
  }
}

///|
test "valid document has no issues" {
  @debug.assert_eq(@validate.validate(sample_doc()), [])
}

///|
test "heading level outside 1..6" {
  let doc : @ast.Document = {
    blocks: [@ast.Block::Heading(0, [@ast.Run::plain("x")])],
  }
  @debug.assert_eq(codes(@validate.validate(doc)), ["structure.heading_level"])
  let doc7 : @ast.Document = {
    blocks: [@ast.Block::Heading(7, [@ast.Run::plain("x")])],
  }
  @debug.assert_eq(codes(@validate.validate(doc7)), ["structure.heading_level"])
}

///|
test "empty run and bad link scheme" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Paragraph([
        @ast.Run::plain(""),
        @ast.Run::marked("click", @ast.Marks::{
          ..@ast.Marks(),
          link: Some("javascript:alert(1)"),
        }),
      ]),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc)), [
    "structure.empty_run", "structure.link_scheme",
  ])
}

///|
test "relative and fragment links are allowed" {
  for
    url in [
      "docs/page.html", "#frag", "/abs/path", "mailto:a@example.com", "a/b:c",
    ] {
    let doc : @ast.Document = {
      blocks: [
        @ast.Block::Paragraph([
          @ast.Run::marked("x", @ast.Marks::{ ..@ast.Marks(), link: Some(url), }),
        ]),
      ],
    }
    @debug.assert_eq(@validate.validate(doc), [])
  }
}

///|
test "depth limit" {
  let limits = @validate.Limits::{
    ..@validate.Limits::default(),
    max_depth: 2,
  }
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Section([@ast.Run::plain("s")], [
        @ast.Block::Section([@ast.Run::plain("s2")], [
          @ast.Block::Paragraph([@ast.Run::plain("deep")]),
        ]),
      ]),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc, limits~)), ["limit.depth"])
}

///|
test "block count limit reported once" {
  let limits = @validate.Limits::{
    ..@validate.Limits::default(),
    max_blocks: 2,
  }
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Paragraph([@ast.Run::plain("a")]),
      @ast.Block::Paragraph([@ast.Run::plain("b")]),
      @ast.Block::Paragraph([@ast.Run::plain("c")]),
      @ast.Block::Paragraph([@ast.Run::plain("d")]),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc, limits~)), ["limit.blocks"])
}

///|
test "text limits" {
  let limits = @validate.Limits::{
    ..@validate.Limits::default(),
    max_text_scalars: 3,
    max_total_text_scalars: 5,
  }
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Paragraph([@ast.Run::plain("abcd")]),
      @ast.Block::CodeBlock("xyzw", None),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc, limits~)), [
    "limit.text", "limit.text", "limit.total_text",
  ])
}

///|
test "run count limit" {
  let limits = @validate.Limits::{
    ..@validate.Limits::default(),
    max_runs_per_block: 1,
  }
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::Paragraph([@ast.Run::plain("a"), @ast.Run::plain("b")]),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc, limits~)), ["limit.runs"])
}

///|
test "table and list limits" {
  let limits = @validate.Limits::{
    ..@validate.Limits::default(),
    max_table_rows: 1,
    max_table_columns: 1,
    max_list_items: 1,
  }
  let cell = [@ast.Block::Paragraph([@ast.Run::plain("x")])]
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::TableBlock([
        @ast.TableRow::{ header: false, cells: [cell, cell], },
        @ast.TableRow::{ header: false, cells: [cell], },
      ]),
      @ast.Block::ListBlock(true, [
        [@ast.Block::Paragraph([@ast.Run::plain("1")])],
        [@ast.Block::Paragraph([@ast.Run::plain("2")])],
      ]),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc, limits~)), [
    "limit.table_rows", "limit.table_columns", "limit.list_items",
  ])
}

///|
test "figure alt and footnote ids" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::FigureBlock("a.png", "", None),
      @ast.Block::FootnoteBlock("", []),
      @ast.Block::FootnoteBlock("dup", []),
      @ast.Block::FootnoteBlock("dup", []),
    ],
  }
  @debug.assert_eq(codes(@validate.validate(doc)), [
    "structure.figure_alt", "structure.footnote_id", "structure.footnote_id",
  ])
}

///|
test "deeply nested input does not panic" {
  let mut block = @ast.Block::Paragraph([@ast.Run::plain("leaf")])
  for _ in 0..<200 {
    block = @ast.Block::Section([@ast.Run::plain("s")], [block])
  }
  let issues = @validate.validate(@ast.Document::{ blocks: [block], })
  @debug.assert_eq(codes(issues), ["limit.depth"])
}

///|
test (b : @bench.T) {
  let doc = sample_doc()
  b.bench(name="validate sample document", fn() {
    b.keep(@validate.validate(doc))
  })
}

///|
test (b : @bench.T) {
  let blocks : Array[@ast.Block] = []
  for i in 0..<1000 {
    blocks.push(
      @ast.Block::Paragraph([
        @ast.Run::plain("Paragraph number \{i} with text."),
      ]),
    )
  }
  let doc : @ast.Document = { blocks, }
  b.bench(name="validate large (1000 blocks)", fn() {
    b.keep(@validate.validate(doc))
  })
}
