///|
/// Clamp a heading level to the valid range 1..6. Both renderers use
/// this rule; the contract is discharged by `moon prove` (see
/// `just prove`), so the range guarantee does not rest on tests alone.
pub fn clamp_heading_level(
  level : Int32,
) -> Int32 where {
  proof_ensure: result => clamped_level(result),
} {
  if level < 1 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
}
