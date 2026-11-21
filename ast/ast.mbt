///|
/// Marks applied to a text run. Inline structure is expressed as marks on
/// runs, never as nested inline nodes, so overlapping ranges cannot be
/// represented.
#derive(Eq, Debug, Arbitrary, Shrink)
pub(all) struct Marks {
  emphasis : Bool
  strong : Bool
  code : Bool
  math : Bool
  link : String?
}

///|
/// A run of text sharing one set of marks.
#derive(Eq, Debug, Arbitrary, Shrink)
pub(all) struct Run {
  text : String
  marks : Marks
}

///|
/// One row of a table. A cell is a list of blocks.
#derive(Eq, Debug, Arbitrary, Shrink)
pub(all) struct TableRow {
  header : Bool
  cells : Array[Array[Block]]
}

///|
/// A block-level node of the semantic tree.
#derive(Eq, Debug, Arbitrary, Shrink)
pub(all) enum Block {
  Heading(Int32, Array[Run])
  Paragraph(Array[Run])
  Section(Array[Run], Array[Block])
  ListBlock(Bool, Array[Array[Block]])
  TableBlock(Array[TableRow])
  CodeBlock(String, String?)
  MathBlock(String)
  FigureBlock(String, String, Array[Run]?)
  FootnoteBlock(String, Array[Block])
  PageBreakHint
}

///|
/// A whole document: an ordered list of top-level blocks.
#derive(Eq, Debug, Arbitrary, Shrink)
pub(all) struct Document {
  blocks : Array[Block]
}

///|
/// The empty mark set.
pub fn Marks::Marks() -> Marks {
  { emphasis: false, strong: false, code: false, math: false, link: None, }
}

///|
/// A run of plain text with no marks.
pub fn Run::plain(text : String) -> Run {
  { text, marks: Marks(), }
}

///|
/// A run of text with the given marks.
pub fn Run::marked(text : String, marks : Marks) -> Run {
  { text, marks, }
}

///|
/// Count the Unicode scalar values in a string. MoonBit strings are UTF-16,
/// so this differs from the code-unit length for non-BMP characters.
pub fn count_scalars(text : String) -> Int32 {
  let mut count = 0
  for _ in text {
    count += 1
  }
  count
}
