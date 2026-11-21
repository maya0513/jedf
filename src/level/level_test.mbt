///|
test "clamp_heading_level" {
  @debug.assert_eq(@level.clamp_heading_level(-5), 1)
  @debug.assert_eq(@level.clamp_heading_level(0), 1)
  @debug.assert_eq(@level.clamp_heading_level(1), 1)
  @debug.assert_eq(@level.clamp_heading_level(3), 3)
  @debug.assert_eq(@level.clamp_heading_level(6), 6)
  @debug.assert_eq(@level.clamp_heading_level(7), 6)
  @debug.assert_eq(@level.clamp_heading_level(100), 6)
}

///|
test "clamp_heading_level stays in range" {
  @quickcheck.check(fn(level : Int32) {
    let result = @level.clamp_heading_level(level)
    result >= 1 && result <= 6
  })
}
