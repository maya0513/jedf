///|
test "render_document renders a valid document" {
  let html = @web.render_document(
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"Hi\"}]}]}",
  )
  @debug.assert_eq(html, "<h1>Hi</h1>\n")
}

///|
test "render_document reports parse failure" {
  let html = @web.render_document("not json")
  @debug.assert_eq(
    html, "<p class=\"jedf-error\">Could not parse the document.</p>",
  )
}

///|
test "render_document reports validation issues" {
  let html = @web.render_document(
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":9,\"content\":[{\"text\":\"Hi\"}]}]}",
  )
  @debug.assert_eq(html.contains("jedf-error"), true)
  @debug.assert_eq(html.contains("heading level"), true)
}

///|
test "render_container renders a packed document" {
  let packed = @container.pack(
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"Hi\"}]}]}",
    [],
  )
  @debug.assert_eq(@web.render_container(packed), "<h1>Hi</h1>\n")
}

///|
test "render_container reports a bad container" {
  @debug.assert_eq(
    @web.render_container(b"not a container"),
    "<p class=\"jedf-error\">Could not read the container.</p>",
  )
}
