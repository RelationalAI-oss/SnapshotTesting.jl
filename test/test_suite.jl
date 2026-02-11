using SnapshotTesting
using Test

# --- Helper to pre-create expected snapshot directories ---

function setup_expected!(expected_dir, name, content)
    d = joinpath(expected_dir, name)
    mkpath(d)
    write(joinpath(d, "out.txt"), content)
end

# --- Suite definitions at top level (required by Julia scoping rules) ---

# :basic_all — basic suite that runs all tests
const _basic_all_cases = Ref{Vector{Pair{String,String}}}()
const _basic_all_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:basic_all}) = _basic_all_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:basic_all}) = _basic_all_expected[]
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:basic_all}, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

# :filter_str — filter by exact string
const _filter_str_cases = Ref{Vector{Pair{String,String}}}()
const _filter_str_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_str}) = _filter_str_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_str}) = _filter_str_expected[]
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:filter_str}, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

# :filter_pred — filter by predicate function
const _filter_pred_cases = Ref{Vector{Pair{String,String}}}()
const _filter_pred_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_pred}) = _filter_pred_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_pred}) = _filter_pred_expected[]
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:filter_pred}, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

# :skip_list — skip list
const _skip_list_cases = Ref{Vector{Pair{String,String}}}()
const _skip_list_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:skip_list}) = _skip_list_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:skip_list}) = _skip_list_expected[]
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:skip_list}, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

# :empty_suite — empty suite
const _empty_suite_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:empty_suite}) = Pair{String,String}[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:empty_suite}) = _empty_suite_expected[]

# :filter_warn — filter matching nothing emits warning
const _filter_warn_cases = Ref{Vector{Pair{String,String}}}()
const _filter_warn_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_warn}) = _filter_warn_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_warn}) = _filter_warn_expected[]

# :extras_test — snapshot_test_extras is called
const _extras_test_cases = Ref{Vector{Pair{String,String}}}()
const _extras_test_expected = Ref{String}()
const _extras_test_called = String[]
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:extras_test}) = _extras_test_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:extras_test}) = _extras_test_expected[]
function SnapshotTesting.snapshot_test_extras(::SnapshotTestSuite{:extras_test}, name, _path)
    push!(_extras_test_called, name)
end
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:extras_test}, name, _path, dir)
    write(joinpath(dir, "out.txt"), "extras output for $name")
end

# :strict_suite — snapshot_allow_additions=false
const _strict_suite_cases = Ref{Vector{Pair{String,String}}}()
const _strict_suite_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:strict_suite}) = _strict_suite_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:strict_suite}) = _strict_suite_expected[]
SnapshotTesting.snapshot_allow_additions(::SnapshotTestSuite{:strict_suite}) = false
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:strict_suite}, name, _path, dir)
    write(joinpath(dir, "out.txt"), "output for $name")
end

# :singular_test — run_snapshot_test singular convenience
const _singular_test_cases = Ref{Vector{Pair{String,String}}}()
const _singular_test_expected = Ref{String}()
SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:singular_test}) = _singular_test_cases[]
SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:singular_test}) = _singular_test_expected[]
function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:singular_test}, name, path, dir)
    write(joinpath(dir, "out.txt"), "output for $name from $path")
end

# --- Tests ---

@testset "SnapshotTestSuite" begin

    @testset "basic suite runs all tests" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a from /path/test_a")
            setup_expected!(expected, "test_b", "output for test_b from /path/test_b")

            _basic_all_cases[] = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            _basic_all_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:basic_all}())
        end
    end

    @testset "filter by exact string" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a from /path/test_a")

            _filter_str_cases[] = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            _filter_str_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:filter_str}(); filter="test_a")
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

            _filter_pred_cases[] = [
                "csv_one" => "/path/csv_one",
                "csv_two" => "/path/csv_two",
                "bin_one" => "/path/bin_one",
            ]
            _filter_pred_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:filter_pred}(); filter=n -> startswith(n, "csv_"))
            @test !isdir(joinpath(expected, "bin_one"))
        end
    end

    @testset "skip list" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_b", "output for test_b from /path/test_b")

            _skip_list_cases[] = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            _skip_list_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:skip_list}(); skip=["test_a"])
            @test !isdir(joinpath(expected, "test_a"))
        end
    end

    @testset "empty suite does not error" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            _empty_suite_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:empty_suite}())
        end
    end

    @testset "filter matching nothing emits warning" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            _filter_warn_cases[] = ["test_a" => "/path/test_a"]
            _filter_warn_expected[] = expected
            @test_logs (:warn, "No snapshot tests matched the filter") run_snapshot_tests(
                SnapshotTestSuite{:filter_warn}(); filter="nonexistent"
            )
        end
    end

    @testset "snapshot_test_extras is called before produce" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "extras output for test_a")
            setup_expected!(expected, "test_b", "extras output for test_b")

            empty!(_extras_test_called)
            _extras_test_cases[] = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            _extras_test_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:extras_test}())
            @test _extras_test_called == ["test_a", "test_b"]
        end
    end

    @testset "snapshot_allow_additions=false is respected" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a")

            _strict_suite_cases[] = ["test_a" => "/path/test_a"]
            _strict_suite_expected[] = expected
            run_snapshot_tests(SnapshotTestSuite{:strict_suite}())
        end
    end

    @testset "run_snapshot_test singular convenience" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "only_this", "output for only_this from /path/only_this")

            _singular_test_cases[] = ["only_this" => "/path/only_this", "not_this" => "/path/not_this"]
            _singular_test_expected[] = expected
            run_snapshot_test(SnapshotTestSuite{:singular_test}(), "only_this")
            # not_this should not have been run
            @test !isdir(joinpath(expected, "not_this"))
        end
    end

end
