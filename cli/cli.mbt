///|
/// The command line interface logic, separated from real IO so it can be
/// tested. `read_file` returns the file contents or an error message;
/// `out` and `err` each write one line. The return value is the process
/// exit code: 0 on success, 1 when the document is invalid, 2 on usage,
/// IO, or parse errors.
pub fn run(
  args : Array[String],
  read_file~ : (String) -> Result[String, String],
  out~ : (String) -> Unit,
  err~ : (String) -> Unit,
) -> Int32 {
  match args {
    [] => {
      err("jedf: no command given")
      print_usage(err)
      2
    }
    ["--help"] | ["help"] => {
      print_usage(out)
      0
    }
    ["validate", file] => cmd_validate(file, read_file, out, err)
    ["to-html", file] => cmd_render(file, true, read_file, out, err)
    ["to-typst", file] => cmd_render(file, false, read_file, out, err)
    ["fmt", file] => cmd_fmt(file, read_file, out, err)
    [command, ..] => {
      err("jedf: unknown command: \{command}")
      print_usage(err)
      2
    }
  }
}

///|
fn print_usage(write : (String) -> Unit) -> Unit {
  write("Usage: jedf <command> <file>")
  write("Commands:")
  write("  validate <file>  Check a document against the format rules")
  write("  to-html <file>   Render a document as an HTML fragment")
  write("  to-typst <file>  Render a document as Typst source")
  write("  fmt <file>       Print the document in canonical JSON form")
}

///|
fn emit_text(out : (String) -> Unit, text : String) -> Unit {
  let lines = text.split("\n")
  for i, line in lines {
    if i < lines.count() - 1 || line != "" {
      out(line.to_owned())
    }
  }
}

///|
fn load(
  file : String,
  read_file : (String) -> Result[String, String],
  err : (String) -> Unit,
) -> Result[@ast.Document, Int32] {
  match read_file(file) {
    Err(message) => {
      err("jedf: cannot read \{file}: \{message}")
      Err(2)
    }
    Ok(text) =>
      match (Ok(@codec.parse(text)) catch { e => Err(e) }) {
        Err(@codec.CodecError::InvalidJson(message)) => {
          err("jedf: \{file}: invalid JSON: \{message}")
          Err(2)
        }
        Err(@codec.CodecError::Schema(message)) => {
          err("jedf: \{file}: \{message}")
          Err(2)
        }
        Ok(doc) => Ok(doc)
      }
  }
}

///|
fn cmd_validate(
  file : String,
  read_file : (String) -> Result[String, String],
  out : (String) -> Unit,
  err : (String) -> Unit,
) -> Int32 {
  match load(file, read_file, err) {
    Err(code) => code
    Ok(doc) => {
      let issues = @validate.validate(doc)
      if issues.is_empty() {
        out("\{file}: ok")
        0
      } else {
        print_issues(out, issues)
        1
      }
    }
  }
}

///|
fn cmd_render(
  file : String,
  html : Bool,
  read_file : (String) -> Result[String, String],
  out : (String) -> Unit,
  err : (String) -> Unit,
) -> Int32 {
  match load(file, read_file, err) {
    Err(code) => code
    Ok(doc) => {
      let issues = @validate.validate(doc)
      if issues.is_empty() {
        emit_text(
          out,
          if html {
            @render_html.render(doc)
          } else {
            @render_typst.render(doc)
          },
        )
        0
      } else {
        print_issues(err, issues)
        1
      }
    }
  }
}

///|
fn cmd_fmt(
  file : String,
  read_file : (String) -> Result[String, String],
  out : (String) -> Unit,
  err : (String) -> Unit,
) -> Int32 {
  match load(file, read_file, err) {
    Err(code) => code
    Ok(doc) => {
      out(@codec.to_string(doc))
      0
    }
  }
}

///|
fn print_issues(
  write : (String) -> Unit,
  issues : Array[@validate.Issue],
) -> Unit {
  for issue in issues {
    write("\{issue.path}: [\{issue.code}] \{issue.message}")
  }
}
