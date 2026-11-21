///|
struct Capture {
  out : Array[String]
  err : Array[String]
}

///|
fn fake_read_file(path : String) -> Result[String, String] {
  match path {
    "ok.json" =>
      Ok(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"T\"}]}]}",
      )
    "invalid.json" =>
      Ok(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":9,\"content\":[{\"text\":\"T\"}]}]}",
      )
    "bad.json" => Ok("not json")
    "schema.json" => Ok("{\"type\":\"document\",\"version\":9,\"blocks\":[]}")
    _ => Err("file not found")
  }
}

///|
fn run_capture(args : Array[String]) -> (Int32, Capture) {
  let capture = Capture::{ out: [], err: [], }
  let code = @cli.run(
    args,
    read_file=fake_read_file,
    out=fn(line) { capture.out.push(line) },
    err=fn(line) { capture.err.push(line) },
  )
  (code, capture)
}

///|
test "no args is a usage error" {
  let (code, capture) = run_capture([])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err[0], "jedf: no command given")
}

///|
test "help" {
  let (code, capture) = run_capture(["--help"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out[0], "Usage: jedf <command> <file>")
  let (code2, _) = run_capture(["help"])
  @debug.assert_eq(code2, 0)
}

///|
test "unknown command" {
  let (code, capture) = run_capture(["frobnicate", "x.json"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err[0], "jedf: unknown command: frobnicate")
}

///|
test "validate ok" {
  let (code, capture) = run_capture(["validate", "ok.json"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["ok.json: ok"])
}

///|
test "validate reports issues and exits 1" {
  let (code, capture) = run_capture(["validate", "invalid.json"])
  @debug.assert_eq(code, 1)
  @debug.assert_eq(capture.out.length(), 1)
}

///|
test "validate missing file exits 2" {
  let (code, capture) = run_capture(["validate", "missing.json"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err, [
    "jedf: cannot read missing.json: file not found",
  ])
}

///|
test "validate parse errors exit 2" {
  let (code, capture) = run_capture(["validate", "bad.json"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err.length(), 1)
  let (code2, capture2) = run_capture(["validate", "schema.json"])
  @debug.assert_eq(code2, 2)
  @debug.assert_eq(capture2.err, [
    "jedf: schema.json: unsupported format version: 9",
  ])
}

///|
test "to-html renders" {
  let (code, capture) = run_capture(["to-html", "ok.json"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["<h1>T</h1>"])
}

///|
test "to-html refuses an invalid document" {
  let (code, capture) = run_capture(["to-html", "invalid.json"])
  @debug.assert_eq(code, 1)
  @debug.assert_eq(capture.err.length(), 1)
  @debug.assert_eq(capture.out, [])
}

///|
test "to-typst renders" {
  let (code, capture) = run_capture(["to-typst", "ok.json"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["= T"])
}

///|
test "render and fmt propagate load errors" {
  let (code, _) = run_capture(["to-html", "missing.json"])
  @debug.assert_eq(code, 2)
  let (code2, _) = run_capture(["to-typst", "missing.json"])
  @debug.assert_eq(code2, 2)
  let (code3, _) = run_capture(["fmt", "bad.json"])
  @debug.assert_eq(code3, 2)
}

///|
test "fmt prints canonical JSON" {
  let (code, capture) = run_capture(["fmt", "ok.json"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, [
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"T\"}]}]}",
  ])
}
