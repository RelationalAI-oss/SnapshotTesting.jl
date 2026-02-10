"""
    SnapshotTestSuite

Abstract type for dispatch-based snapshot test suites. Packages define a concrete
subtype and overload the interface functions to get automatic test iteration,
filtering, and plumbing.

# Required methods
- `snapshot_tests(suite)` — return a `Vector{Pair{String,String}}` of `(name, path)` pairs
- `snapshot_expected_dir(suite)` — return the path to the expected snapshots directory
- `snapshot_produce(suite, name, path, dir)` — produce output files in `dir`

# Optional methods (have defaults)
- `snapshot_test_extras(suite, name, path)` — run assertions before the snapshot comparison (default: no-op)
- `snapshot_allow_additions(suite)` — whether to allow new files in snapshots (default: `true`)

# Example

```julia
struct MySnapshots <: SnapshotTestSuite end

SnapshotTesting.snapshot_tests(::MySnapshots) = [("test1" => "path/to/test1"), ...]
SnapshotTesting.snapshot_expected_dir(::MySnapshots) = joinpath(@__DIR__, "expected")
function SnapshotTesting.snapshot_produce(::MySnapshots, name, path, dir)
    write(joinpath(dir, "out.txt"), run_my_code(path))
end

run_snapshot_tests(MySnapshots())
run_snapshot_tests(MySnapshots(); filter="test1")  # run single test
```
"""
abstract type SnapshotTestSuite end

"""
    snapshot_tests(suite::SnapshotTestSuite) -> Vector{Pair{String,String}}

Return the list of test cases as `name => path` pairs.
"""
function snapshot_tests end

"""
    snapshot_expected_dir(suite::SnapshotTestSuite) -> String

Return the path to the directory containing expected snapshot outputs.
"""
function snapshot_expected_dir end

"""
    snapshot_produce(suite::SnapshotTestSuite, name::String, path::String, dir::String)

Produce snapshot output files in `dir`.
"""
function snapshot_produce end

"""
    snapshot_test_extras(suite::SnapshotTestSuite, name::String, path::String)

Run additional assertions before the snapshot comparison. Defaults to no-op.
"""
snapshot_test_extras(::SnapshotTestSuite, name, path) = nothing

"""
    snapshot_allow_additions(suite::SnapshotTestSuite) -> Bool

Whether to allow new files in snapshot output that aren't in the expected directory.
Defaults to `true`.
"""
snapshot_allow_additions(::SnapshotTestSuite) = true

"""
    run_snapshot_tests(suite::SnapshotTestSuite; filter=nothing, skip=String[])

Run all snapshot tests defined by `suite`, with optional filtering and skipping.

- `filter=nothing`: run all tests
- `filter="name"`: run only the test with exactly this name
- `filter=f::Function`: run tests where `f(name)` returns `true`
- `skip=["name1", ...]`: skip tests with these names
"""
function run_snapshot_tests(suite::SnapshotTestSuite; filter=nothing, skip=String[])
    cases = snapshot_tests(suite)
    expected = snapshot_expected_dir(suite)
    allow = snapshot_allow_additions(suite)
    pred = _make_filter(filter)
    skip_set = Set{String}(skip)

    matched = false
    for (name, path) in cases
        pred(name) || continue
        name in skip_set && continue
        matched = true
        @testset "$name" begin
            snapshot_test_extras(suite, name, path)
            test_snapshot(expected, name; allow_additions=allow) do dir
                snapshot_produce(suite, name, path, dir)
            end
        end
    end

    if !matched && filter !== nothing
        @warn "No snapshot tests matched the filter" filter
    end
end

_make_filter(::Nothing) = _ -> true
_make_filter(name::AbstractString) = n -> n == name
_make_filter(f::Function) = f
