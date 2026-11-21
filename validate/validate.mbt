///|
/// Resource limits checked by the validator. Every limit is part of the
/// format specification: a document that exceeds a limit is invalid, and
/// readers may reject it without attempting to process it further.
#derive(Eq, Debug)
pub(all) struct Limits {
  max_depth : Int32
  max_blocks : Int32
  max_runs_per_block : Int32
  max_text_scalars : Int32
  max_total_text_scalars : Int32
  max_table_rows : Int32
  max_table_columns : Int32
  max_list_items : Int32
}

///|
/// One validation problem. `code` is a stable machine-readable identifier,
/// `path` locates the offending node (for example `blocks[2].runs[0]`), and
/// `message` is a human-readable explanation.
#derive(Eq, Debug)
pub(all) struct Issue {
  code : String
  path : String
  message : String
}

///|
/// The default limits of the format.
pub fn Limits::default() -> Limits {
  {
    max_depth: 32,
    max_blocks: 10000,
    max_runs_per_block: 1000,
    max_text_scalars: 100000,
    max_total_text_scalars: 10000000,
    max_table_rows: 1000,
    max_table_columns: 100,
    max_list_items: 10000,
  }
}

///|
priv struct Validator {
  limits : Limits
  issues : Array[Issue]
  mut blocks : Int32
  mut total_scalars : Int32
  mut blocks_reported : Bool
  mut total_reported : Bool
  footnote_ids : Array[String]
}

///|
fn Validator::add(
  self : Self,
  code : String,
  path : String,
  message : String,
) -> Unit {
  self.issues.push({ code, path, message, })
}

///|
/// Validate a document against the structural rules of the format and the
/// given resource limits. Returns every problem found; an empty array means
/// the document is valid. Never panics, whatever the input tree contains.
pub fn validate(
  doc : @ast.Document,
  limits~ : Limits = Limits::default(),
) -> Array[Issue] {
  let validator = Validator::{
    limits,
    issues: [],
    blocks: 0,
    total_scalars: 0,
    blocks_reported: false,
    total_reported: false,
    footnote_ids: [],
  }
  validator.check_blocks(doc.blocks, "blocks", 1)
  validator.issues
}

///|
fn Validator::check_blocks(
  self : Self,
  blocks : Array[@ast.Block],
  path : String,
  depth : Int32,
) -> Unit {
  if depth > self.limits.max_depth {
    self.add(
      "limit.depth",
      path,
      "nesting depth exceeds max_depth (\{self.limits.max_depth})",
    )
    return
  }
  for i, block in blocks {
    self.check_block(block, "\{path}[\{i}]", depth)
  }
}

///|
fn Validator::check_block(
  self : Self,
  block : @ast.Block,
  path : String,
  depth : Int32,
) -> Unit {
  self.blocks += 1
  if self.blocks > self.limits.max_blocks && !self.blocks_reported {
    self.blocks_reported = true
    self.add(
      "limit.blocks",
      path,
      "block count exceeds max_blocks (\{self.limits.max_blocks})",
    )
  }
  match block {
    @ast.Block::Heading(level, runs) => {
      if level < 1 || level > 6 {
        self.add(
          "structure.heading_level",
          path,
          "heading level \{level} is outside 1..6",
        )
      }
      self.check_runs(runs, path)
    }
    @ast.Block::Paragraph(runs) => self.check_runs(runs, path)
    @ast.Block::Section(title, children) => {
      self.check_runs(title, path)
      self.check_blocks(children, "\{path}.blocks", depth + 1)
    }
    @ast.Block::ListBlock(_, items) => {
      if items.length() > self.limits.max_list_items {
        self.add(
          "limit.list_items",
          path,
          "list item count exceeds max_list_items (\{self.limits.max_list_items})",
        )
      }
      for i, item in items {
        self.check_blocks(item, "\{path}.items[\{i}]", depth + 1)
      }
    }
    @ast.Block::TableBlock(rows) => {
      if rows.length() > self.limits.max_table_rows {
        self.add(
          "limit.table_rows",
          path,
          "table row count exceeds max_table_rows (\{self.limits.max_table_rows})",
        )
      }
      for r, row in rows {
        if row.cells.length() > self.limits.max_table_columns {
          self.add(
            "limit.table_columns",
            "\{path}.rows[\{r}]",
            "table column count exceeds max_table_columns (\{self.limits.max_table_columns})",
          )
        }
        for c, cell in row.cells {
          self.check_blocks(cell, "\{path}.rows[\{r}].cells[\{c}]", depth + 1)
        }
      }
    }
    @ast.Block::CodeBlock(text, _) => self.check_text(text, path)
    @ast.Block::MathBlock(source) => self.check_text(source, path)
    @ast.Block::FigureBlock(_, alt, caption) => {
      if alt == "" {
        self.add("structure.figure_alt", path, "figure alt text is empty")
      }
      match caption {
        Some(runs) => self.check_runs(runs, path)
        None => ()
      }
    }
    @ast.Block::FootnoteBlock(id, children) => {
      if id == "" {
        self.add("structure.footnote_id", path, "footnote id is empty")
      } else if self.footnote_ids.contains(id) {
        self.add(
          "structure.footnote_id",
          path,
          "footnote id \{id} is used more than once",
        )
      } else {
        self.footnote_ids.push(id)
      }
      self.check_blocks(children, "\{path}.blocks", depth + 1)
    }
    @ast.Block::PageBreakHint => ()
  }
}

///|
fn Validator::check_runs(
  self : Self,
  runs : Array[@ast.Run],
  path : String,
) -> Unit {
  if runs.length() > self.limits.max_runs_per_block {
    self.add(
      "limit.runs",
      path,
      "run count exceeds max_runs_per_block (\{self.limits.max_runs_per_block})",
    )
  }
  for i, run in runs {
    let run_path = "\{path}.runs[\{i}]"
    if run.text == "" {
      self.add("structure.empty_run", run_path, "text run is empty")
    }
    self.check_text(run.text, run_path)
    match run.marks.link {
      Some(url) =>
        if !link_scheme_allowed(url) {
          self.add(
            "structure.link_scheme",
            run_path,
            "link URL scheme is not allowed: \{url}",
          )
        }
      None => ()
    }
  }
}

///|
fn Validator::check_text(self : Self, text : String, path : String) -> Unit {
  let scalars = @ast.count_scalars(text)
  if scalars > self.limits.max_text_scalars {
    self.add(
      "limit.text",
      path,
      "text length exceeds max_text_scalars (\{self.limits.max_text_scalars})",
    )
  }
  self.total_scalars += scalars
  if self.total_scalars > self.limits.max_total_text_scalars &&
    !self.total_reported {
    self.total_reported = true
    self.add(
      "limit.total_text",
      path,
      "total text length exceeds max_total_text_scalars (\{self.limits.max_total_text_scalars})",
    )
  }
}

///|
/// A link URL is allowed when it has no scheme (a relative reference or a
/// fragment) or when its scheme is http, https, or mailto.
fn link_scheme_allowed(url : String) -> Bool {
  let colon = url.find(":")
  match colon {
    None => true
    Some(index) =>
      // A colon after a slash, question mark, or hash belongs to the path,
      // query, or fragment, not to a scheme.
      if special_before(url, index) {
        true
      } else {
        let scheme = url[:index].to_owned().to_lower()
        scheme == "http" || scheme == "https" || scheme == "mailto"
      }
  }
}

///|
fn special_before(text : String, index : Int32) -> Bool {
  for needle in ["/", "?", "#"] {
    match text.find(needle) {
      Some(i) if i < index => return true
      _ => ()
    }
  }
  false
}
