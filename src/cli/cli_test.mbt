///|
struct Capture {
  out : Array[String]
  err : Array[String]
  written : Array[(String, Bytes)]
  written_text : Array[(String, String)]
}

///|
fn fake_read_file(path : String) -> Result[String, String] {
  match path {
    "ok.jedf" =>
      Ok(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"T\"}]}]}",
      )
    "invalid.jedf" =>
      Ok(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":9,\"content\":[{\"text\":\"T\"}]}]}",
      )
    "bad.jedf" => Ok("not json")
    "schema.jedf" => Ok("{\"type\":\"document\",\"version\":9,\"blocks\":[]}")
    _ => Err("file not found")
  }
}

///|

///|
fn fake_read_bytes(path : String) -> Result[Bytes, String] {
  match path {
    "a.bin" => Ok(b"xy")
    "good.jedfc" => {
      let packed = @container.pack(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[]}",
        [("a.bin", b"xy")],
      ) catch {
        _ => b""
      }
      Ok(packed)
    }
    "bad.jedfc" => Ok(b"not a container at all")
    "v2.jedfc" => {
      let packed = @container.pack(
        "{\"type\":\"document\",\"version\":1,\"blocks\":[]}",
        [],
      ) catch {
        _ => b""
      }
      let arr : Array[Byte] = []
      for b in packed {
        arr.push(b)
      }
      if arr.length() > 4 {
        arr[4] = 0x02
      }
      Ok(Bytes::from_array(arr[:]))
    }
    _ => Err("file not found")
  }
}

///|
fn run_capture(args : Array[String]) -> (Int32, Capture) {
  let capture = Capture::{ out: [], err: [], written: [], written_text: [], }
  let code = @cli.run(
    args,
    read_file=fake_read_file,
    read_bytes=fake_read_bytes,
    write_file=fn(path, text) {
      if path == "nowhere/out.jedf" {
        Err("disk full")
      } else {
        capture.written_text.push((path, text))
        Ok(())
      }
    },
    write_bytes=fn(path, bytes) {
      if path == "nowhere/out.jedfc" {
        Err("disk full")
      } else {
        capture.written.push((path, bytes))
        Ok(())
      }
    },
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
  let (code, capture) = run_capture(["frobnicate", "x.jedf"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err[0], "jedf: unknown command: frobnicate")
}

///|
test "validate ok" {
  let (code, capture) = run_capture(["validate", "ok.jedf"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["ok.jedf: ok"])
}

///|
test "validate reports issues and exits 1" {
  let (code, capture) = run_capture(["validate", "invalid.jedf"])
  @debug.assert_eq(code, 1)
  @debug.assert_eq(capture.out.length(), 1)
}

///|
test "validate missing file exits 2" {
  let (code, capture) = run_capture(["validate", "missing.jedf"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err, [
    "jedf: cannot read missing.jedf: file not found",
  ])
}

///|
test "validate parse errors exit 2" {
  let (code, capture) = run_capture(["validate", "bad.jedf"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err.length(), 1)
  let (code2, capture2) = run_capture(["validate", "schema.jedf"])
  @debug.assert_eq(code2, 2)
  @debug.assert_eq(capture2.err, [
    "jedf: schema.jedf: unsupported format version: 9",
  ])
}

///|
test "to-html renders" {
  let (code, capture) = run_capture(["to-html", "ok.jedf"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["<h1>T</h1>"])
}

///|
test "to-html refuses an invalid document" {
  let (code, capture) = run_capture(["to-html", "invalid.jedf"])
  @debug.assert_eq(code, 1)
  @debug.assert_eq(capture.err.length(), 1)
  @debug.assert_eq(capture.out, [])
}

///|
test "to-typst renders" {
  let (code, capture) = run_capture(["to-typst", "ok.jedf"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, ["= T"])
}

///|
test "render and fmt propagate load errors" {
  let (code, _) = run_capture(["to-html", "missing.jedf"])
  @debug.assert_eq(code, 2)
  let (code2, _) = run_capture(["to-typst", "missing.jedf"])
  @debug.assert_eq(code2, 2)
  let (code3, _) = run_capture(["fmt", "bad.jedf"])
  @debug.assert_eq(code3, 2)
}

///|
test "fmt prints canonical JSON" {
  let (code, capture) = run_capture(["fmt", "ok.jedf"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.out, [
    "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"T\"}]}]}",
  ])
}

///|
/// End to end through the CLI: whatever the file content is, each
/// command must finish with one of the documented exit codes. A panic
/// anywhere in parse, validate, or render fails the test run itself.
test "commands never panic on arbitrary file content" {
  @quickcheck.check(fn(pair : (Int32, String)) {
    let (seed, text) = pair
    let commands = ["validate", "to-html", "to-typst", "fmt"]
    let command = commands[(seed % 4 + 4) % 4]
    let code = @cli.run(
      [command, "x.jedf"],
      read_file=fn(_) { Ok(text) },
      read_bytes=fn(_) { Err("no bytes") },
      write_file=fn(_, _) { Ok(()) },
      write_bytes=fn(_, _) { Ok(()) },
      out=fn(_) { () },
      err=fn(_) { () },
    )
    code == 0 || code == 1 || code == 2
  })
}

///|
test "pack writes a container" {
  let (code, capture) = run_capture(["pack", "ok.jedf", "out.jedfc", "a.bin"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.written.length(), 1)
  let (document, assets) = @container.unpack(capture.written[0].1)
  @debug.assert_eq(
    document, "{\"type\":\"document\",\"version\":1,\"blocks\":[{\"type\":\"heading\",\"level\":1,\"content\":[{\"text\":\"T\"}]}]}",
  )
  @debug.assert_eq(assets, [("a.bin", b"xy")])
}

///|
test "pack refuses an invalid document and a missing asset" {
  let (code, _) = run_capture(["pack", "invalid.jedf", "out.jedfc"])
  @debug.assert_eq(code, 1)
  let (code2, capture2) = run_capture([
    "pack", "ok.jedf", "out.jedfc", "missing.bin",
  ])
  @debug.assert_eq(code2, 2)
  @debug.assert_eq(
    capture2.err[0],
    "jedf: cannot read missing.bin: file not found",
  )
}

///|
test "unpack extracts the document" {
  let (code, capture) = run_capture(["unpack", "good.jedfc", "out.jedf"])
  @debug.assert_eq(code, 0)
  @debug.assert_eq(capture.written_text, [
    ("out.jedf", "{\"type\":\"document\",\"version\":1,\"blocks\":[]}"),
  ])
  @debug.assert_eq(capture.out, [
    "out.jedf: unpacked", "asset not extracted: a.bin",
  ])
}

///|
test "unpack rejects a non-container" {
  let (code, capture) = run_capture(["unpack", "bad.jedfc", "out.jedf"])
  @debug.assert_eq(code, 2)
  @debug.assert_eq(capture.err[0], "jedf: bad.jedfc: not a jedf container")
}

///|
test "pack and unpack error paths" {
  // The document file cannot be read.
  let (code, _) = run_capture(["pack", "missing.jedf", "out.jedfc"])
  @debug.assert_eq(code, 2)
  // Duplicate asset names reach the container error path.
  let (code2, capture2) = run_capture([
    "pack", "ok.jedf", "out.jedfc", "a.bin", "a.bin",
  ])
  @debug.assert_eq(code2, 2)
  @debug.assert_eq(capture2.err[0], "jedf: duplicate chunk: a.bin")
  // The container cannot be written.
  let (code3, capture3) = run_capture(["pack", "ok.jedf", "nowhere/out.jedfc"])
  @debug.assert_eq(code3, 2)
  @debug.assert_eq(
    capture3.err[0],
    "jedf: cannot write nowhere/out.jedfc: disk full",
  )
  // The container file cannot be read.
  let (code4, capture4) = run_capture(["unpack", "missing.jedfc", "out.jedf"])
  @debug.assert_eq(code4, 2)
  @debug.assert_eq(
    capture4.err[0],
    "jedf: cannot read missing.jedfc: file not found",
  )
  // The extracted document cannot be written.
  let (code5, capture5) = run_capture([
    "unpack", "good.jedfc", "nowhere/out.jedf",
  ])
  @debug.assert_eq(code5, 2)
  @debug.assert_eq(
    capture5.err[0],
    "jedf: cannot write nowhere/out.jedf: disk full",
  )
  // An unsupported container version is reported as such.
  let (code6, capture6) = run_capture(["unpack", "v2.jedfc", "out.jedf"])
  @debug.assert_eq(code6, 2)
  @debug.assert_eq(
    capture6.err[0],
    "jedf: v2.jedfc: unsupported container version: 2",
  )
}
