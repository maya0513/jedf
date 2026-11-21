///|
/// Parse a document in the standard format, validate it, and render
/// it to HTML. On any failure, returns an HTML fragment describing
/// the problem instead of rendered content. This is the browser
/// viewer entry point into the library.
pub fn render_document(json_text : String) -> String {
  let doc : @ast.Document? = Some(@codec.parse(json_text)) catch { _ => None }
  match doc {
    None => "<p class=\"jedf-error\">Could not parse the document.</p>"
    Some(doc) => {
      let issues = @validate.validate(doc)
      if issues.length() == 0 {
        @render_html.render(doc)
      } else {
        let out = StringBuilder()
        out.write_string(
          "<p class=\"jedf-error\">The document is not valid:</p><ul>",
        )
        for issue in issues {
          out.write_string("<li>")
          out.write_string(
            @render_html.escape("\{issue.path}: \{issue.message}"),
          )
          out.write_string("</li>")
        }
        out.write_string("</ul>")
        out.to_string()
      }
    }
  }
}

///|
/// Read a container (.jedfc), extract its document, and render it
/// like `render_document`. On any failure, returns an HTML fragment
/// describing the problem.
pub fn render_container(data : Bytes) -> String {
  let text : String? = Some(@container.document(data)) catch { _ => None }
  match text {
    None => "<p class=\"jedf-error\">Could not read the container.</p>"
    Some(text) => render_document(text)
  }
}
