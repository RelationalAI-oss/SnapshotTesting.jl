using SnapshotTesting
using Test

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
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:basic_all}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:basic_all}) = expected
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:basic_all}, name, path, dir)
                write(joinpath(dir, "out.txt"), "output for $name from $path")
            end

            run_snapshot_tests(SnapshotTestSuite{:basic_all}())
        end
    end

    @testset "filter by exact string" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a from /path/test_a")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_str}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_str}) = expected
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:filter_str}, name, path, dir)
                write(joinpath(dir, "out.txt"), "output for $name from $path")
            end

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

            cases = [
                "csv_one" => "/path/csv_one",
                "csv_two" => "/path/csv_two",
                "bin_one" => "/path/bin_one",
            ]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_pred}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_pred}) = expected
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:filter_pred}, name, path, dir)
                write(joinpath(dir, "out.txt"), "output for $name from $path")
            end

            run_snapshot_tests(SnapshotTestSuite{:filter_pred}(); filter=n -> startswith(n, "csv_"))
            @test !isdir(joinpath(expected, "bin_one"))
        end
    end

    @testset "skip list" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_b", "output for test_b from /path/test_b")

            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:skip_list}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:skip_list}) = expected
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:skip_list}, name, path, dir)
                write(joinpath(dir, "out.txt"), "output for $name from $path")
            end

            run_snapshot_tests(SnapshotTestSuite{:skip_list}(); skip=["test_a"])
            @test !isdir(joinpath(expected, "test_a"))
        end
    end

    @testset "empty suite does not error" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:empty_suite}) = Pair{String,String}[]
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:empty_suite}) = expected

            run_snapshot_tests(SnapshotTestSuite{:empty_suite}())
        end
    end

    @testset "filter matching nothing emits warning" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            cases = ["test_a" => "/path/test_a"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:filter_warn}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:filter_warn}) = expected

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

            extras_called = String[]
            cases = ["test_a" => "/path/test_a", "test_b" => "/path/test_b"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:extras_test}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:extras_test}) = expected
            function SnapshotTesting.snapshot_test_extras(::SnapshotTestSuite{:extras_test}, name, _path)
                push!(extras_called, name)
            end
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:extras_test}, name, _path, dir)
                write(joinpath(dir, "out.txt"), "extras output for $name")
            end

            run_snapshot_tests(SnapshotTestSuite{:extras_test}())
            @test extras_called == ["test_a", "test_b"]
        end
    end

    @testset "snapshot_allow_additions=false is respected" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "test_a", "output for test_a")

            cases = ["test_a" => "/path/test_a"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:strict_suite}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:strict_suite}) = expected
            SnapshotTesting.snapshot_allow_additions(::SnapshotTestSuite{:strict_suite}) = false
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:strict_suite}, name, _path, dir)
                write(joinpath(dir, "out.txt"), "output for $name")
            end

            run_snapshot_tests(SnapshotTestSuite{:strict_suite}())
        end
    end

    @testset "run_snapshot_test singular convenience" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)
            setup_expected!(expected, "only_this", "output for only_this from /path/only_this")

            cases = ["only_this" => "/path/only_this", "not_this" => "/path/not_this"]
            SnapshotTesting.snapshot_tests(::SnapshotTestSuite{:singular_test}) = cases
            SnapshotTesting.snapshot_expected_dir(::SnapshotTestSuite{:singular_test}) = expected
            function SnapshotTesting.snapshot_produce(::SnapshotTestSuite{:singular_test}, name, path, dir)
                write(joinpath(dir, "out.txt"), "output for $name from $path")
            end

            run_snapshot_test(SnapshotTestSuite{:singular_test}(), "only_this")
            # not_this should not have been run
            @test !isdir(joinpath(expected, "not_this"))
        end
    end

end
