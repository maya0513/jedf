///|
test "plain run has no marks" {
  let run = @ast.Run::plain("hello")
  @debug.assert_eq(run.text, "hello")
  @debug.assert_eq(run.marks, @ast.Marks())
}

///|
test "marked run keeps marks" {
  let marks = @ast.Marks::{
    ..@ast.Marks(),
    strong: true,
    link: Some("https://example.com"),
  }
  let run = @ast.Run::marked("x", marks)
  @debug.assert_eq(run.marks.strong, true)
  @debug.assert_eq(run.marks.link, Some("https://example.com"))
}

///|
test "count_scalars counts code points" {
  @debug.assert_eq(@ast.count_scalars(""), 0)
  @debug.assert_eq(@ast.count_scalars("abc"), 3)
  @debug.assert_eq(@ast.count_scalars("あいう"), 3)
  // U+1F600 is one scalar but two UTF-16 code units.
  @debug.assert_eq(@ast.count_scalars("😀"), 1)
  @debug.assert_eq(@ast.count_scalars("a😀b"), 3)
}

///|
test "document snapshot" {
  let doc = @ast.Document::{
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title")]),
      @ast.Block::Paragraph([@ast.Run::plain("body")]),
    ],
  }
  debug_inspect(
    doc,
    content=(
      #|{
      #|  blocks: [
      #|    Heading(
      #|      1,
      #|      [
      #|        {
      #|          text: "Title",
      #|          marks: {
      #|            emphasis: false,
      #|            strong: false,
      #|            code: false,
      #|            math: false,
      #|            link: None,
      #|          },
      #|        },
      #|      ],
      #|    ),
      #|    Paragraph(
      #|      [
      #|        {
      #|          text: "body",
      #|          marks: {
      #|            emphasis: false,
      #|            strong: false,
      #|            code: false,
      #|            math: false,
      #|            link: None,
      #|          },
      #|        },
      #|      ],
      #|    ),
      #|  ],
      #|}
    ),
  )
}
