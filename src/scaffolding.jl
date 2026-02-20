"""
    SnapshotConfig{name}

Parametric marker type for configuring snapshot test suites. `name` should be a Symbol
identifying your test suite (e.g., `:LQPValidator`).

Create a const instance and implement the required methods to define your snapshot test suite.

# Required methods
- `expected_dir(config)::String` — path to directory containing expected snapshots

# Snapshot production (implement one)
- `produce_snapshot_text(config, name, source_path)::String` — return text content (written to `out.txt`)
- `produce_snapshot(config, name, source_path, dir)` — write files directly to `dir`

# Case discovery (implement one)
- `cases_dir(config)::String` + optionally `cases_ext(config)::String` — scan a directory
- `list_cases(config)::Vector{Pair{String,String}}` — provide cases directly

# Example
```julia
const MySnapshots = SnapshotConfig{:MyTests}()
SnapshotTesting.expected_dir(::typeof(MySnapshots)) = joinpath(@__DIR__, "expected")
SnapshotTesting.cases_dir(::typeof(MySnapshots)) = joinpath(@__DIR__, "testcases")
SnapshotTesting.cases_ext(::typeof(MySnapshots)) = ".bin"

function SnapshotTesting.produce_snapshot_text(::typeof(MySnapshots), name, source_path)
    return process(read(source_path))
end

# In test:
run_all(MySnapshots; excluded=Set(["broken_test"]))

# In REPL:
run_test(MySnapshots, "specific_test")
```
"""
struct SnapshotConfig{name} end

"""
    expected_dir(config::SnapshotConfig)::String

Return the path to the directory containing expected snapshot subdirectories.
"""
function expected_dir end

"""
    cases_dir(config::SnapshotConfig)::String

Return the path to the directory containing test case source files.
Used by the default `list_cases` implementation.
"""
function cases_dir end

"""
    cases_ext(config::SnapshotConfig)::String

File extension to filter by when scanning `cases_dir` (e.g. `".bin"`).
Defaults to `""` (match all files).
"""
cases_ext(::SnapshotConfig) = ""

"""
    list_cases(config::SnapshotConfig)::Vector{Pair{String,String}}

Return a vector of `name => source_path` pairs for all test cases.
Default implementation scans `cases_dir(config)` filtered by `cases_ext(config)`.
"""
function list_cases(config::SnapshotConfig)
    dir = cases_dir(config)
    ext = cases_ext(config)
    sort!([
        splitext(basename(f))[1] => f
        for f in readdir(dir; join=true)
        if ext == "" || endswith(f, ext)
    ])
end

"""
    produce_snapshot_text(config::SnapshotConfig, name::String, source_path::String)::String

Produce snapshot content as a string. The framework writes it to `out.txt`.
Implement this for the common single-file text snapshot case.
"""
function produce_snapshot_text end

"""
    produce_snapshot(config::SnapshotConfig, name::String, source_path::String, dir::String)

Produce snapshot files by writing directly to `dir`.
Default implementation calls `produce_snapshot_text` and writes the result to `out.txt`.
Override this for multi-file snapshots.
"""
function produce_snapshot(config::SnapshotConfig, name::String, source_path::String, dir::String)
    content = produce_snapshot_text(config, name, source_path)
    write(joinpath(dir, "out.txt"), content)
end

"""
    run_all(config::SnapshotConfig; excluded=Set{String}(), allow_additions=true)

Run all snapshot test cases. Creates a `@testset` per case, skipping names in `excluded`.
"""
function run_all(config::SnapshotConfig; excluded=Set{String}(), allow_additions=true)
    cases = list_cases(config)
    for (name, source_path) in cases
        name in excluded && continue
        @testset "$name" begin
            _run_snapshot(config, name, source_path; allow_additions)
        end
    end
end

"""
    run_test(config::SnapshotConfig, name::String; allow_additions=true)

Run a single snapshot test case by name. Looks up the source path from `list_cases`.
This is the primary REPL entry point for re-running individual failing tests.
"""
function run_test(config::SnapshotConfig, name::String; allow_additions=true)
    cases = list_cases(config)
    idx = findfirst(c -> first(c) == name, cases)
    source_path = idx !== nothing ? last(cases[idx]) : ""
    _run_snapshot(config, name, source_path; allow_additions)
end

function _run_snapshot(config::SnapshotConfig, name::String, source_path::String; allow_additions=true)
    test_snapshot(expected_dir(config), name; allow_additions) do dir
        produce_snapshot(config, name, source_path, dir)
    end
end
