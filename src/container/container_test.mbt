///|
fn sample_asset() -> Bytes {
  let bytes : Array[Byte] = []
  for i in 0..<256 {
    bytes.push(i.to_byte())
  }
  Bytes::from_array(bytes[:])
}

///|
fn error_kind(data : Bytes) -> String {
  try {
    let _ = @container.unpack(data)
    "ok"
  } catch {
    @container.ContainerError::BadMagic => "bad_magic"
    @container.ContainerError::UnsupportedVersion(_) => "unsupported"
    @container.ContainerError::Invalid(_) => "invalid"
  }
}

///|
fn to_mutable_array(data : Bytes) -> Array[Byte] {
  let out : Array[Byte] = []
  for b in data {
    out.push(b)
  }
  out
}

///|
test "pack and unpack round trip" {
  let asset = sample_asset()
  let packed = @container.pack("{\"type\":\"document\"}", [
    ("img/a.png", asset),
    ("font.bin", b"abc"),
  ])
  let (document, assets) = @container.unpack(packed)
  @debug.assert_eq(document, "{\"type\":\"document\"}")
  @debug.assert_eq(assets.length(), 2)
  @debug.assert_eq(assets[0].0, "img/a.png")
  @debug.assert_eq(assets[0].1, asset)
  @debug.assert_eq(assets[1].0, "font.bin")
  @debug.assert_eq(assets[1].1, b"abc")
  @debug.assert_eq(@container.document(packed), "{\"type\":\"document\"}")
}

///|
test "unpack rejects bad containers" {
  let packed = @container.pack("doc", [("a.bin", b"xyz")])
  @debug.assert_eq(error_kind(packed), "ok")
  let bad_magic = to_mutable_array(packed)
  bad_magic[0] = 0x00
  @debug.assert_eq(error_kind(Bytes::from_array(bad_magic[:])), "bad_magic")
  let bad_version = to_mutable_array(packed)
  bad_version[4] = 0x02
  @debug.assert_eq(error_kind(Bytes::from_array(bad_version[:])), "unsupported")
  let corrupt = to_mutable_array(packed)
  let last = corrupt.length() - 1
  corrupt[last] = (corrupt[last].to_int() ^ 0xFF).to_byte()
  @debug.assert_eq(error_kind(Bytes::from_array(corrupt[:])), "invalid")
  let truncated = to_mutable_array(packed)
  ignore(truncated.pop())
  @debug.assert_eq(error_kind(Bytes::from_array(truncated[:])), "invalid")
  @debug.assert_eq(error_kind(b"short"), "invalid")
  @debug.assert_eq(error_kind(b""), "invalid")
}

///|
test "pack rejects bad asset names" {
  let duplicate : String? = try {
    let _ = @container.pack("doc", [("a", b"x"), ("a", b"y")])
    None
  } catch {
    @container.ContainerError::Invalid(message) => Some(message)
    _ => Some("other")
  }
  @debug.assert_eq(duplicate, Some("duplicate chunk: a"))
}

///|
test "container round trip property" {
  @quickcheck.check(fn(pair : (String, Array[Byte])) {
    let (document, asset_bytes) = pair
    let asset = Bytes::from_array(asset_bytes[:])
    let packed = Some(@container.pack(document, [("a.bin", asset)])) catch {
      _ => None
    }
    match packed {
      None => false
      Some(packed) => {
        let result = Some(@container.unpack(packed)) catch { _ => None }
        match result {
          None => false
          Some((text, assets)) =>
            text == document && assets.length() == 1 && assets[0].1 == asset
        }
      }
    }
  })
}

///|
/// Independent FNV-1a oracle, so crafted manifests can carry correct
/// hashes and the reader's own hash computation is cross-checked.
fn fnv_hex(data : Bytes) -> String {
  let mut hash : UInt64 = 0xcbf29ce484222325
  for b in data {
    hash = (hash ^ b.to_int().to_uint64()) * 0x100000001b3
  }
  let table : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let shifts = [60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4, 0]
  let out = StringBuilder()
  for shift in shifts {
    out.write_char(table[((hash >> shift) & 0xF).to_int()])
  }
  out.to_string()
}

///|
fn push_u32le_test(out : Array[Byte], value : Int32) -> Unit {
  for shift in [0, 8, 16, 24] {
    out.push(((value >> shift) & 0xFF).to_byte())
  }
}

///|
/// Build a container by hand from a manifest (as raw bytes) and the
/// chunk bytes, so tests can produce manifests `pack` never would.
fn craft(manifest : Bytes, body : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for b in b"JEDF" {
    out.push(b)
  }
  push_u32le_test(out, 1)
  push_u32le_test(out, manifest.length())
  for b in manifest {
    out.push(b)
  }
  for b in body {
    out.push(b)
  }
  Bytes::from_array(out[:])
}

///|
fn pack_error(document : String, assets : Array[(String, Bytes)]) -> String {
  try {
    let _ = @container.pack(document, assets)
    "ok"
  } catch {
    @container.ContainerError::Invalid(message) => message
    _ => "other"
  }
}

///|
test "pack rejects empty and reserved asset names" {
  @debug.assert_eq(pack_error("doc", [("", b"x")]), "empty chunk name")
  @debug.assert_eq(
    pack_error("doc", [("document", b"x")]),
    "duplicate chunk: document",
  )
}

///|
test "unpack rejects malformed manifests" {
  let enc = fn(text : String) { @utf8.encode(text[:]) }
  // Hash field of the wrong length, then of the wrong characters.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":3,\"fnv1a\":\"abcd\"}]}",
        ),
        b"abc",
      ),
    ),
    "invalid",
  )
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":3,\"fnv1a\":\"zzzzzzzzzzzzzzzz\"}]}",
        ),
        b"abc",
      ),
    ),
    "invalid",
  )
  // Missing chunks field.
  @debug.assert_eq(error_kind(craft(enc("{\"version\":1}"), b"")), "invalid")
  // Manifest is not an object.
  @debug.assert_eq(error_kind(craft(enc("[]"), b"")), "invalid")
  // Chunks is not an array.
  @debug.assert_eq(
    error_kind(craft(enc("{\"version\":1,\"chunks\":{}}"), b"")),
    "invalid",
  )
  // Chunk name is not a string.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":1,\"length\":0,\"fnv1a\":\"0000000000000000\"}]}",
        ),
        b"",
      ),
    ),
    "invalid",
  )
  // Chunk length is not a number, then not an integer.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":\"x\",\"fnv1a\":\"0000000000000000\"}]}",
        ),
        b"",
      ),
    ),
    "invalid",
  )
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":1.5,\"fnv1a\":\"0000000000000000\"}]}",
        ),
        b"",
      ),
    ),
    "invalid",
  )
  // Manifest is not JSON, then not UTF-8.
  @debug.assert_eq(error_kind(craft(enc("hello"), b"")), "invalid")
  @debug.assert_eq(error_kind(craft(b"\xff\xfe", b"")), "invalid")
  // Manifest version differs from the header version.
  @debug.assert_eq(
    error_kind(craft(enc("{\"version\":2,\"chunks\":[]}"), b"")),
    "unsupported",
  )
}

///|
test "unpack rejects structurally wrong containers" {
  let enc = fn(text : String) { @utf8.encode(text[:]) }
  let hash_a = fnv_hex(b"a")
  let hash_empty = fnv_hex(b"")
  let hash_ff = fnv_hex(b"\xff")
  // Duplicate chunk names on the read side.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":1,\"fnv1a\":\"\{hash_a}\"},{\"name\":\"document\",\"length\":1,\"fnv1a\":\"\{hash_a}\"}]}",
        ),
        b"aa",
      ),
    ),
    "invalid",
  )
  // Empty chunk name.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"\",\"length\":0,\"fnv1a\":\"\{hash_empty}\"}]}",
        ),
        b"",
      ),
    ),
    "invalid",
  )
  // Chunk length beyond the end of the container.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":100,\"fnv1a\":\"\{hash_a}\"}]}",
        ),
        b"abc",
      ),
    ),
    "invalid",
  )
  // The first chunk is not the document.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"x\",\"length\":1,\"fnv1a\":\"\{hash_a}\"}]}",
        ),
        b"a",
      ),
    ),
    "invalid",
  )
  // The document chunk is not valid UTF-8.
  @debug.assert_eq(
    error_kind(
      craft(
        enc(
          "{\"version\":1,\"chunks\":[{\"name\":\"document\",\"length\":1,\"fnv1a\":\"\{hash_ff}\"}]}",
        ),
        b"\xff",
      ),
    ),
    "invalid",
  )
  // A manifest length that runs past the end of the container.
  let packed = @container.pack("doc", [])
  let bad_length = to_mutable_array(packed)
  bad_length[8] = 0xFF
  bad_length[9] = 0xFF
  @debug.assert_eq(error_kind(Bytes::from_array(bad_length[:])), "invalid")
  // Trailing bytes after the last chunk.
  let trailing = to_mutable_array(packed)
  trailing.push(0x00)
  @debug.assert_eq(error_kind(Bytes::from_array(trailing[:])), "invalid")
}

///|
fn large_document_text() -> String {
  let out = StringBuilder()
  out.write_string("{\"type\":\"document\",\"version\":1,\"blocks\":[")
  for i in 0..<1000 {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(
      "{\"type\":\"paragraph\",\"content\":[{\"text\":\"Paragraph number \{i} with some plain text.\"}]}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
test (b : @bench.T) {
  let asset = sample_asset()
  let packed = @container.pack("{\"type\":\"document\"}", [("img/a.png", asset)])
  b.bench(name="pack sample", fn() {
    b.keep(
      Ok(@container.pack("{\"type\":\"document\"}", [("img/a.png", asset)])) catch {
        e => Err(e)
      },
    )
  })
  b.bench(name="unpack sample", fn() {
    b.keep(Ok(@container.unpack(packed)) catch { e => Err(e) })
  })
}

///|
test (b : @bench.T) {
  let text = large_document_text()
  let bytes : Array[Byte] = []
  for i in 0..<65536 {
    bytes.push((i % 251).to_byte())
  }
  let asset = Bytes::from_array(bytes[:])
  let packed = @container.pack(text, [("data.bin", asset)])
  b.bench(name="pack large (1000 blocks, 64 KiB asset)", fn() {
    b.keep(
      Ok(@container.pack(text, [("data.bin", asset)])) catch {
        e => Err(e)
      },
    )
  })
  b.bench(name="unpack large (1000 blocks, 64 KiB asset)", fn() {
    b.keep(Ok(@container.unpack(packed)) catch { e => Err(e) })
  })
}
