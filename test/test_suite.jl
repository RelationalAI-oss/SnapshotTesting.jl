using SnapshotTesting
using Test

# --- Test suite types ---

struct BasicSuite <: SnapshotTestSuite
    cases::Vector{Pair{String,String}}
    expected_dir::String
end
SnapshotTesting.snapshot_tests(s::BasicSuite) = s.cases
SnapshotTesting.snapshot_expected_dir(s::BasicSuite) = s.expected_dir
function SnapshotTesting.snapshot_produce(::BasicSuite, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

mutable struct ExtrasSuite <: SnapshotTestSuite
    cases::Vector{Pair{String,String}}
    expected_dir::String
    extras_called::Vector{String}
    ExtrasSuite(cases, dir) = new(cases, dir, String[])
end
SnapshotTesting.snapshot_tests(s::ExtrasSuite) = s.cases
SnapshotTesting.snapshot_expected_dir(s::ExtrasSuite) = s.expected_dir
function SnapshotTesting.snapshot_test_extras(s::ExtrasSuite, name, _path)
    push!(s.extras_called, name)
end
function SnapshotTesting.snapshot_produce(::ExtrasSuite, name, _path, dir)
    write(joinpath(dir, "out.txt"), "extras output for $name")
end

struct StrictSuite <: SnapshotTestSuite
    cases::Vector{Pair{String,String}}
    expected_dir::String
end
SnapshotTesting.snapshot_tests(s::StrictSuite) = s.cases
SnapshotTesting.snapshot_expected_dir(s::StrictSuite) = s.expected_dir
SnapshotTesting.snapshot_allow_additions(::StrictSuite) = false
function SnapshotTesting.snapshot_produce(::StrictSuite, name, _path, dir)
    write(joinpath(dir, "out.txt"), "output for $name")
end

# --- Helper to pre-create expected snapshot directories ---

function setup_expected!(expected_dir, name, content)
    d = joinpath(expected_dir, name)
    mkpath(d)
    write(joinpath(d, "out.txt"), content)
end

# --- Tests ---

@testset "SnapshotTestSuite" begin

    @testset "basic suite runs all tests" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a from /path/test_a")
            setup_expected!(expected, "test_b", "output for test_b from /path/test_b")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            suite = BasicSuite(cases, expected)
            run_snapshot_tests(suite)
        end
    end

    @testset "filter by exact string" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a from /path/test_a")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            suite = BasicSuite(cases, expected)
            run_snapshot_tests(suite; filter="test_a")
            # test_b should not have been run (no directory created)
            @test !isdir(joinpath(expected, "test_b"))
        end
    end

    @testset "filter by predicate function" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "csv_one", "output for csv_one from /path/csv_one")
            setup_expected!(expected, "csv_two", "output for csv_two from /path/csv_two")

            cases = [
                "csv_one" => "/path/csv_one",
                "csv_two" => "/path/csv_two",
                "bin_one" => "/path/bin_one",
            ]
            suite = BasicSuite(cases, expected)
            run_snapshot_tests(suite; filter=n -> startswith(n, "csv_"))
            @test !isdir(joinpath(expected, "bin_one"))
        end
    end

    @testset "skip list" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_b", "output for test_b from /path/test_b")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            suite = BasicSuite(cases, expected)
            run_snapshot_tests(suite; skip=["test_a"])
            @test !isdir(joinpath(expected, "test_a"))
        end
    end

    @testset "empty suite does not error" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            suite = BasicSuite(Pair{String,String}[], expected)
            run_snapshot_tests(suite)
        end
    end

    @testset "filter matching nothing emits warning" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            cases = ["test_a" => "/path/test_a"]
            suite = BasicSuite(cases, expected)
            @test_logs (:warn, "No snapshot tests matched the filter") run_snapshot_tests(
                suite; filter="nonexistent"
            )
        end
    end

    @testset "snapshot_test_extras is called before produce" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "extras output for test_a")
            setup_expected!(expected, "test_b", "extras output for test_b")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            suite = ExtrasSuite(cases, expected)
            run_snapshot_tests(suite)
            @test suite.extras_called == ["test_a", "test_b"]
        end
    end

    @testset "snapshot_allow_additions=false is respected" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a")

            cases = ["test_a" => "/path/test_a"]
            suite = StrictSuite(cases, expected)
            run_snapshot_tests(suite)
        end
    end

end
