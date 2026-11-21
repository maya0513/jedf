///|
/// Error raised when a byte sequence is not a valid jedf container,
/// or when a container fails an integrity check.
pub suberror ContainerError {
  BadMagic
  UnsupportedVersion(Int32)
  Invalid(String)
}

///|
/// The container format version that `pack` writes and `unpack`
/// requires.
pub fn format_version() -> Int32 {
  1
}

///|
/// FNV-1a (64-bit) over a byte range. This detects accidental
/// corruption only; it is not a cryptographic hash.
fn fnv1a64(data : Bytes, start : Int32, length : Int32) -> UInt64 {
  let mut hash : UInt64 = 0xcbf29ce484222325
  let prime : UInt64 = 0x100000001b3
  for i in 0..<length {
    hash = (hash ^ data[start + i].to_int().to_uint64()) * prime
  }
  hash
}

///|
fn hex64(value : UInt64) -> String {
  let table : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let shifts = [60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4, 0]
  let out = StringBuilder()
  for shift in shifts {
    let nibble = ((value >> shift) & 0xF).to_int()
    out.write_char(table[nibble])
  }
  out.to_string()
}

///|
fn parse_hex64(text : String) -> UInt64 raise ContainerError {
  if text.length() != 16 {
    raise ContainerError::Invalid("bad chunk hash: \{text}")
  }
  let mut value : UInt64 = 0
  for c in text {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else {
      raise ContainerError::Invalid("bad chunk hash: \{text}")
    }
    value = (value << 4) | digit.to_uint64()
  }
  value
}

///|
fn push_u32le(out : Array[Byte], value : Int32) -> Unit {
  for shift in [0, 8, 16, 24] {
    out.push(((value >> shift) & 0xFF).to_byte())
  }
}

///|
fn read_u32le(data : Bytes, at : Int32) -> Int32 {
  let mut value : Int32 = 0
  for shift in [0, 8, 16, 24] {
    value = value | (data[at + shift / 8].to_int() << shift)
  }
  value
}

///|
fn object(fields : Array[(String, @json.Json)]) -> @json.Json {
  let map : Map[String, @json.Json] = Map([])
  for (key, value) in fields {
    map[key] = value
  }
  @json.Json::object(map)
}

///|
fn get(
  fields : Map[String, @json.Json],
  key : String,
) -> @json.Json raise ContainerError {
  match fields.get(key) {
    Some(value) => value
    None => raise ContainerError::Invalid("missing field: \{key}")
  }
}

///|
fn as_object(
  value : @json.Json,
  what : String,
) -> Map[String, @json.Json] raise ContainerError {
  match value {
    @json.Json::Object(fields) => fields
    _ => raise ContainerError::Invalid("\{what} must be an object")
  }
}

///|
fn as_array(
  value : @json.Json,
  what : String,
) -> Array[@json.Json] raise ContainerError {
  match value {
    @json.Json::Array(items) => items
    _ => raise ContainerError::Invalid("\{what} must be an array")
  }
}

///|
fn as_string(value : @json.Json, what : String) -> String raise ContainerError {
  match value {
    @json.Json::String(text) => text
    _ => raise ContainerError::Invalid("\{what} must be a string")
  }
}

///|
fn as_int(value : @json.Json, what : String) -> Int32 raise ContainerError {
  match value {
    @json.Json::Number(number, ..) =>
      if number == number.floor() &&
        number >= -2147483648.0 &&
        number <= 2147483647.0 {
        number.to_int()
      } else {
        raise ContainerError::Invalid("\{what} must be a 32-bit integer")
      }
    _ => raise ContainerError::Invalid("\{what} must be a number")
  }
}

///|
/// Pack a document (in the standard format) and any number of named
/// binary assets into a single container. The document is stored as
/// the first chunk, under the name `document`; asset names must be
/// non-empty, unique, and different from `document`.
///
/// Layout: the magic `JEDF`, the format version and the manifest
/// length as little-endian UInt32, the manifest as JSON, then the
/// chunk bytes in manifest order. The manifest lists each chunk's
/// name, length, and FNV-1a hash.
pub fn pack(
  document : String,
  assets : Array[(String, Bytes)],
) -> Bytes raise ContainerError {
  let chunks : Array[(String, Bytes)] = [
    ("document", @utf8.encode(document[:])),
  ]
  for (name, bytes) in assets {
    if name == "" {
      raise ContainerError::Invalid("empty chunk name")
    }
    if name == "document" {
      raise ContainerError::Invalid("duplicate chunk: document")
    }
    for (existing, _) in chunks {
      if existing == name {
        raise ContainerError::Invalid("duplicate chunk: \{name}")
      }
    }
    chunks.push((name, bytes))
  }
  let entries = chunks.map(fn(chunk) {
    let (name, bytes) = chunk
    object([
      ("name", @json.Json::string(name)),
      ("length", @json.Json::number(bytes.length().to_double())),
      ("fnv1a", @json.Json::string(hex64(fnv1a64(bytes, 0, bytes.length())))),
    ])
  })
  let manifest = object([
    ("version", @json.Json::number(format_version().to_double())),
    ("chunks", @json.Json::array(entries)),
  ])
  let manifest_bytes = @utf8.encode(manifest.stringify()[:])
  let out : Array[Byte] = []
  for b in b"JEDF" {
    out.push(b)
  }
  push_u32le(out, format_version())
  push_u32le(out, manifest_bytes.length())
  for b in manifest_bytes {
    out.push(b)
  }
  for (_, bytes) in chunks {
    for b in bytes {
      out.push(b)
    }
  }
  Bytes::from_array(out[:])
}

///|
fn read_chunks(data : Bytes) -> Array[(String, Bytes)] raise ContainerError {
  if data.length() < 12 {
    raise ContainerError::Invalid("container is too short")
  }
  if data[0].to_int() != 0x4A ||
    data[1].to_int() != 0x45 ||
    data[2].to_int() != 0x44 ||
    data[3].to_int() != 0x46 {
    raise ContainerError::BadMagic
  }
  let version = read_u32le(data, 4)
  if version != format_version() {
    raise ContainerError::UnsupportedVersion(version)
  }
  let manifest_length = read_u32le(data, 8)
  if manifest_length < 0 || 12 + manifest_length > data.length() {
    raise ContainerError::Invalid("manifest is out of range")
  }
  let manifest_text = @utf8.decode(data[12:12 + manifest_length]) catch {
    _ => raise ContainerError::Invalid("manifest is not valid UTF-8")
  }
  let manifest = @json.parse(manifest_text[:], reject_duplicate_keys=true) catch {
    _ => raise ContainerError::Invalid("manifest is not valid JSON")
  }
  let fields = as_object(manifest, "manifest")
  let manifest_version = as_int(get(fields, "version"), "manifest version")
  if manifest_version != format_version() {
    raise ContainerError::UnsupportedVersion(manifest_version)
  }
  let entries = as_array(get(fields, "chunks"), "chunks")
  let chunks : Array[(String, Bytes)] = []
  let seen : Map[String, Bool] = Map([])
  let mut pos = 12 + manifest_length
  for entry in entries {
    let efields = as_object(entry, "chunk")
    let name = as_string(get(efields, "name"), "chunk name")
    let length = as_int(get(efields, "length"), "chunk length")
    let hash_text = as_string(get(efields, "fnv1a"), "chunk hash")
    if name == "" {
      raise ContainerError::Invalid("empty chunk name")
    }
    match seen.get(name) {
      Some(_) => raise ContainerError::Invalid("duplicate chunk: \{name}")
      None => ()
    }
    seen[name] = true
    if length < 0 || pos + length > data.length() {
      raise ContainerError::Invalid("chunk is out of range: \{name}")
    }
    if fnv1a64(data, pos, length) != parse_hex64(hash_text) {
      raise ContainerError::Invalid("hash mismatch: \{name}")
    }
    chunks.push((name, data[pos:pos + length].to_owned()))
    pos += length
  }
  if pos != data.length() {
    raise ContainerError::Invalid("trailing bytes after the chunks")
  }
  if chunks.length() == 0 || chunks[0].0 != "document" {
    raise ContainerError::Invalid("the first chunk must be the document")
  }
  chunks
}

///|
/// Unpack a container into its document (in the standard format) and
/// its named assets. Every chunk's hash is verified.
pub fn unpack(
  data : Bytes,
) -> (String, Array[(String, Bytes)]) raise ContainerError {
  let chunks = read_chunks(data)
  let text = @utf8.decode(chunks[0].1) catch {
    _ => raise ContainerError::Invalid("the document chunk is not valid UTF-8")
  }
  let assets : Array[(String, Bytes)] = []
  for i = 1; i < chunks.length(); i = i + 1 {
    assets.push(chunks[i])
  }
  (text, assets)
}

///|
/// Read only the document (in the standard format) out of a
/// container, verifying every chunk's hash on the way.
pub fn document(data : Bytes) -> String raise ContainerError {
  unpack(data).0
}
