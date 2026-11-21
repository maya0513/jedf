///|
/// The 8-byte argument form cannot be reached through documents
/// (their integers and lengths are small), so it is exercised
/// directly on the writer.
test "write_header uses the 8-byte form for large arguments" {
  let out : Array[Byte] = []
  write_header(out, 0, 4294967296)
  @debug.assert_eq(out, [0x1B, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
}
