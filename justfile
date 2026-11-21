# jedf task bundle. The substance of every gate is a moon subcommand;
# just only ties them together (MoonBit has no built-in task runner).

# Type-check everything, treating warnings as errors
check:
    moon check --deny-warn --target all

# Format all sources
fmt:
    moon fmt

# Check formatting without changing files
fmt-check:
    moon fmt --check

# Run all tests: the full suite on native, and the library packages on
# wasm and wasm-gc (the examples test reads files from disk and the
# executable is native-only, so those two run on native only)
test:
    moon test --target native
    moon test --target wasm -p maya0513/jedf/src/ast -p maya0513/jedf/src/validate -p maya0513/jedf/src/codec -p maya0513/jedf/src/render_html -p maya0513/jedf/src/render_typst -p maya0513/jedf/src/cli
    moon test --target wasm-gc -p maya0513/jedf/src/ast -p maya0513/jedf/src/validate -p maya0513/jedf/src/codec -p maya0513/jedf/src/render_html -p maya0513/jedf/src/render_typst -p maya0513/jedf/src/cli

# Run tests and report any uncovered lines (must be none in library packages)
coverage:
    moon coverage clean
    moon test
    moon coverage analyze

# Run benchmarks (native target)
bench:
    moon bench --target native

# Regenerate package interface files
info:
    moon info

# Verify the generated interface files are unchanged
info-check: info
    git diff --exit-code -- ':(glob)**/pkg.generated.mbti'

# Build the jedf command line tool (native)
build:
    moon build src/cmd/jedf --target native

# Everything CI runs
ci: fmt-check check test coverage info-check
