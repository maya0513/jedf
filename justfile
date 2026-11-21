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

# Run all tests
test:
    moon test

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
