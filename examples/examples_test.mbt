///|
/// Read an example file. Tests run either in this package's directory or
/// in the module root depending on the runner, so both locations are
/// tried.
fn read_example(name : String) -> String {
  let direct = Some(@fs.read_file_to_string(name)) catch { _ => None }
  match direct {
    Some(text) => text
    None =>
      @fs.read_file_to_string("examples/" + name) catch {
        _ => abort("example file not found: " + name)
      }
  }
}

///|
/// Every example must parse, validate with no issues, render to HTML and
/// Typst, and survive a JSON round trip unchanged. `marker` is a
/// substring that must appear in the HTML output.
test "examples parse, validate, render, and round-trip" {
  let cases = [
    ("showcase.json", "<table>"),
    ("letter.json", "mailto:maya0513@muse.ai"),
    ("meeting-notes.json", "<ol>"),
  ]
  for (name, marker) in cases {
    let doc = @codec.parse(read_example(name))
    inspect(@validate.validate(doc).length(), content="0")
    let html = @render_html.render(doc)
    inspect(html.contains(marker), content="true")
    inspect(@render_typst.render(doc).length() > 0, content="true")
    let again = @codec.parse(@codec.to_string(doc))
    inspect(again == doc, content="true")
  }
}
