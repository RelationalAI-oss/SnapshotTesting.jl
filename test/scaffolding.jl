using SnapshotTesting
using SnapshotTesting: SnapshotConfig, expected_dir, cases_dir, cases_ext,
    list_cases, produce_snapshot_text, produce_snapshot, run_all, run_test
using Test

# --- Test config: directory scanning ---
const DirScanConfig = SnapshotConfig{:DirScan}()
const _dir_scan = Dict{Symbol, String}()

SnapshotTesting.expected_dir(::typeof(DirScanConfig)) = _dir_scan[:expected_dir]
SnapshotTesting.cases_dir(::typeof(DirScanConfig)) = _dir_scan[:cases_dir]
SnapshotTesting.cases_ext(::typeof(DirScanConfig)) = ".txt"

function SnapshotTesting.produce_snapshot_text(::typeof(DirScanConfig), name::String, source_path::String)
    return read(source_path, String) * " processed"
end

# --- Test config: manual case list ---
const ManualConfig = SnapshotConfig{:Manual}()
const _manual = Dict{Symbol, Any}()

SnapshotTesting.expected_dir(::typeof(ManualConfig)) = _manual[:expected_dir]::String
SnapshotTesting.list_cases(::typeof(ManualConfig)) = _manual[:cases]::Vector{Pair{String,String}}

function SnapshotTesting.produce_snapshot_text(::typeof(ManualConfig), name::String, ::String)
    return "output for $name"
end

# --- Test config: multi-file (general produce_snapshot) ---
const MultiFileConfig = SnapshotConfig{:MultiFile}()
const _multi = Dict{Symbol, Any}()

SnapshotTesting.expected_dir(::typeof(MultiFileConfig)) = _multi[:expected_dir]::String
SnapshotTesting.list_cases(::typeof(MultiFileConfig)) = ["multi" => ""]

function SnapshotTesting.produce_snapshot(::typeof(MultiFileConfig), ::String, ::String, dir::String)
    write(joinpath(dir, "file1.txt"), "content 1")
    write(joinpath(dir, "file2.txt"), "content 2")
end

# --- Tests ---

@testset "list_cases: directory scanning" begin
    mktempdir() do tmpdir
        cases = joinpath(tmpdir, "cases")
        mkpath(cases)
        write(joinpath(cases, "alpha.txt"), "a")
        write(joinpath(cases, "beta.txt"), "b")
        write(joinpath(cases, "gamma.bin"), "filtered out")

        _dir_scan[:cases_dir] = cases
        _dir_scan[:expected_dir] = joinpath(tmpdir, "expected")
        mkpath(_dir_scan[:expected_dir])

        result = list_cases(DirScanConfig)
        @test length(result) == 2
        @test result[1].first == "alpha"
        @test result[2].first == "beta"
        @test endswith(result[1].second, "alpha.txt")
        @test endswith(result[2].second, "beta.txt")
    end
end

@testset "list_cases: manual case list" begin
    _manual[:expected_dir] = mktempdir()
    _manual[:cases] = ["foo" => "/path/to/foo", "bar" => "/path/to/bar"]

    result = list_cases(ManualConfig)
    @test length(result) == 2
    @test result[1] == ("foo" => "/path/to/foo")
end

@testset "produce_snapshot delegates to produce_snapshot_text" begin
    mktempdir() do tmpdir
        _manual[:expected_dir] = tmpdir
        _manual[:cases] = ["test1" => ""]

        dir = joinpath(tmpdir, "output")
        mkpath(dir)
        produce_snapshot(ManualConfig, "test1", "", dir)
        @test read(joinpath(dir, "out.txt"), String) == "output for test1"
    end
end

@testset "run_all creates snapshots for all cases" begin
    mktempdir() do tmpdir
        cases = joinpath(tmpdir, "cases")
        mkpath(cases)
        write(joinpath(cases, "case_a.txt"), "hello")
        write(joinpath(cases, "case_b.txt"), "world")

        expected = joinpath(tmpdir, "expected")
        mkpath(expected)

        _dir_scan[:cases_dir] = cases
        _dir_scan[:expected_dir] = expected

        # First run creates snapshots
        redirect_stdout(devnull) do
            run_all(DirScanConfig)
        end

        @test isdir(joinpath(expected, "case_a"))
        @test isdir(joinpath(expected, "case_b"))
        @test read(joinpath(expected, "case_a", "out.txt"), String) == "hello processed"
        @test read(joinpath(expected, "case_b", "out.txt"), String) == "world processed"

        # Second run should pass (matching content)
        @testset "re-run matches" begin
            run_all(DirScanConfig)
        end
    end
end

@testset "run_all with excluded" begin
    mktempdir() do tmpdir
        cases = joinpath(tmpdir, "cases")
        mkpath(cases)
        write(joinpath(cases, "include_me.txt"), "yes")
        write(joinpath(cases, "exclude_me.txt"), "no")

        expected = joinpath(tmpdir, "expected")
        mkpath(expected)

        _dir_scan[:cases_dir] = cases
        _dir_scan[:expected_dir] = expected

        redirect_stdout(devnull) do
            run_all(DirScanConfig; excluded=Set(["exclude_me"]))
        end

        @test isdir(joinpath(expected, "include_me"))
        @test !isdir(joinpath(expected, "exclude_me"))
    end
end

@testset "run_test runs a single case" begin
    mktempdir() do tmpdir
        _manual[:expected_dir] = joinpath(tmpdir, "expected")
        mkpath(_manual[:expected_dir])
        _manual[:cases] = ["foo" => "", "bar" => ""]

        redirect_stdout(devnull) do
            run_test(ManualConfig, "foo")
        end

        @test isdir(joinpath(tmpdir, "expected", "foo"))
        @test !isdir(joinpath(tmpdir, "expected", "bar"))
    end
end

@testset "general produce_snapshot (multi-file)" begin
    mktempdir() do tmpdir
        _multi[:expected_dir] = joinpath(tmpdir, "expected")
        mkpath(_multi[:expected_dir])

        redirect_stdout(devnull) do
            run_test(MultiFileConfig, "multi")
        end

        @test read(joinpath(tmpdir, "expected", "multi", "file1.txt"), String) == "content 1"
        @test read(joinpath(tmpdir, "expected", "multi", "file2.txt"), String) == "content 2"
    end
end
