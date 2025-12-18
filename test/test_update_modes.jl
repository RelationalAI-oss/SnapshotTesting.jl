using SnapshotTesting
using Test

@testset "Snapshot Update Modes" begin

    @testset "Environment variable force_update" begin
        # Test that force_update returns false by default (clear env var first)
        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => nothing) do
            @test SnapshotTesting.force_update() == false
        end

        # Test that force_update returns true when env var is set
        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => "true") do
            @test SnapshotTesting.force_update() == true
        end

        # Test that it returns false for other values
        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => "false") do
            @test SnapshotTesting.force_update() == false
        end

        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => "1") do
            @test SnapshotTesting.force_update() == true  # "1" parses as true
        end

        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => "0") do
            @test SnapshotTesting.force_update() == false  # "0" parses as false
        end

        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => "invalid") do
            @test SnapshotTesting.force_update() == false  # invalid string returns false
        end

        withenv("JULIA_SNAPSHOTTESTS_UPDATE" => nothing) do
            @test SnapshotTesting.force_update() == false
        end
    end

    @testset "Interactive input_bool" begin
        # Helper to test input_bool with simulated input
        function test_input(input_string)
            # Create a temporary file with the input
            mktempdir() do tmpdir
                input_file = joinpath(tmpdir, "input.txt")
                write(input_file, input_string)

                open(input_file, "r") do input_io
                    redirect_stdin(input_io) do
                        redirect_stdout(devnull) do
                            SnapshotTesting.input_bool("Test prompt")
                        end
                    end
                end
            end
        end

        # Test 'y' response
        @test test_input("y\n") == true

        # Test 'n' response
        @test test_input("n\n") == false

        # Test case insensitivity with uppercase Y
        @test test_input("Y\n") == true

        # Test case insensitivity with uppercase N
        @test test_input("N\n") == false

        # Test that invalid input is retried
        @test test_input("invalid\ny\n") == true

        # Test empty input is retried
        @test test_input("\n\nn\n") == false
    end

    @testset "Auto-creation of missing snapshots" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)

            test_path = joinpath(expected, "autocreate")
            @test !isdir(test_path)

            # Run test - should auto-create snapshot
            redirect_stdout(devnull) do
                SnapshotTesting.test_snapshot(expected, "autocreate") do dir
                    write(joinpath(dir, "newfile.txt"), "auto-created content")
                end
            end

            # Verify snapshot was created
            @test isdir(test_path)
            @test isfile(joinpath(test_path, "newfile.txt"))
            @test read(joinpath(test_path, "newfile.txt"), String) == "auto-created content"
        end
    end

    @testset "Successful snapshot test (no changes needed)" begin
        mktempdir() do tmpdir
            expected = joinpath(tmpdir, "expected")
            mkpath(expected)

            # Create initial snapshot
            test_path = joinpath(expected, "nochange")
            mkpath(test_path)
            write(joinpath(test_path, "file.txt"), "same content")

            # Run test with same content - should pass without prompts
            @testset "matching content" begin
                SnapshotTesting.test_snapshot(expected, "nochange") do dir
                    write(joinpath(dir, "file.txt"), "same content")
                end
            end
        end
    end

end
