///|
/// The command line interface logic, separated from real IO so it can be
/// tested. `read_file` returns the file contents or an error message;
/// `out` and `err` each write one line. The return value is the process
/// exit code: 0 on success, 1 when the document is invalid, 2 on usage,
/// IO, or parse errors.
pub fn run(
  args : Array[String],
  read_file~ : (String) -> Result[String, String],
  read_bytes~ : (String) -> Result[Bytes, String],
  write_file~ : (String, String) -> Result[Unit, String],
  write_bytes~ : (String, Bytes) -> Result[Unit, String],
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
    ["pack", file, output, .. assets] =>
      cmd_pack(
        file,
        output,
        assets.to_owned(),
        read_file,
        read_bytes,
        write_bytes,
        out,
        err,
      )
    ["unpack", file, output] =>
      cmd_unpack(file, output, read_bytes, write_file, out, err)
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
  write("  pack <file> <output> [assets...]")
  write("                   Pack a document and asset files into a container")
  write("  unpack <file> <output>")
  write("                   Extract the document from a container")
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
fn describe_container_error(error : @container.ContainerError) -> String {
  match error {
    @container.ContainerError::BadMagic => "not a jedf container"
    @container.ContainerError::UnsupportedVersion(version) =>
      "unsupported container version: \{version}"
    @container.ContainerError::Invalid(message) => message
  }
}

///|
fn cmd_pack(
  file : String,
  output : String,
  assets : Array[String],
  read_file : (String) -> Result[String, String],
  read_bytes : (String) -> Result[Bytes, String],
  write_bytes : (String, Bytes) -> Result[Unit, String],
  out : (String) -> Unit,
  err : (String) -> Unit,
) -> Int32 {
  match load(file, read_file, err) {
    Err(code) => code
    Ok(doc) => {
      let issues = @validate.validate(doc)
      if !issues.is_empty() {
        print_issues(err, issues)
        return 1
      }
      let asset_data : Array[(String, Bytes)] = []
      for path in assets {
        match read_bytes(path) {
          Err(message) => {
            err("jedf: cannot read \{path}: \{message}")
            return 2
          }
          Ok(bytes) => asset_data.push((path, bytes))
        }
      }
      let packed : Result[Bytes, @container.ContainerError] = Ok(
        @container.pack(@codec.to_string(doc), asset_data),
      ) catch {
        e => Err(e)
      }
      match packed {
        Err(error) => {
          err("jedf: \{describe_container_error(error)}")
          2
        }
        Ok(bytes) =>
          match write_bytes(output, bytes) {
            Err(message) => {
              err("jedf: cannot write \{output}: \{message}")
              2
            }
            Ok(_) => {
              out("\{output}: packed")
              0
            }
          }
      }
    }
  }
}

///|
fn cmd_unpack(
  file : String,
  output : String,
  read_bytes : (String) -> Result[Bytes, String],
  write_file : (String, String) -> Result[Unit, String],
  out : (String) -> Unit,
  err : (String) -> Unit,
) -> Int32 {
  match read_bytes(file) {
    Err(message) => {
      err("jedf: cannot read \{file}: \{message}")
      2
    }
    Ok(data) => {
      let unpacked : Result[
        (String, Array[(String, Bytes)]),
        @container.ContainerError,
      ] = Ok(@container.unpack(data)) catch { e => Err(e) }
      match unpacked {
        Err(error) => {
          err("jedf: \{file}: \{describe_container_error(error)}")
          2
        }
        Ok((text, assets)) =>
          match write_file(output, text) {
            Err(message) => {
              err("jedf: cannot write \{output}: \{message}")
              2
            }
            Ok(_) => {
              out("\{output}: unpacked")
              for (name, _) in assets {
                out("asset not extracted: \{name}")
              }
              0
            }
          }
      }
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
