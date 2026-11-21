///|
/// jedf command line tool. All logic lives in the `cli` package; this entry
/// point only wires it to the real file system and standard streams.
fn main {
  let args = @env.args()[1:].to_owned()
  let code = @cli.run(
    args,
    read_file=fn(path) {
      Ok(@fs.read_file_to_string(path)) catch {
        _ => Err("I/O error")
      }
    },
    out=fn(line) { println(line) },
    err=fn(line) { eprintln(line) },
  )
  if code != 0 {
    @env.exit(code)
  }
}
