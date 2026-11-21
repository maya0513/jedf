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
    ("showcase.jedf", "<table>"),
    ("letter.jedf", "mailto:maya0513@muse.ai"),
    ("meeting-notes.jedf", "<ol>"),
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

///|
/// Every sample document also survives a container round trip: packed
/// with a small asset, the unpacked document text parses back to an
/// equal document.
test "examples survive a container round trip" {
  let files = ["showcase.jedf", "letter.jedf", "meeting-notes.jedf"]
  for name in files {
    let text = @fs.read_file_to_string("examples/" + name)
    let packed = @container.pack(text, [("note.txt", b"sample")])
    let (unpacked, assets) = @container.unpack(packed)
    @debug.assert_eq(assets, [("note.txt", b"sample")])
    @debug.assert_eq(@codec.parse(unpacked), @codec.parse(text))
  }
}

///|
/// Every sample document also survives a CBOR round trip.
test "examples survive a CBOR round trip" {
  let files = ["showcase.jedf", "letter.jedf", "meeting-notes.jedf"]
  for name in files {
    let text = @fs.read_file_to_string("examples/" + name)
    let doc = @codec.parse(text)
    @debug.assert_eq(@codec_cbor.parse(@codec_cbor.to_bytes(doc)), doc)
  }
}
