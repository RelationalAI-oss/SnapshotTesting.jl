
"""
    create_expectation_snapshot(f::Function, expected_dir, subpath)
    create_expectation_snapshot(expected_dir, subpath) do dir
        ...
    end

Run the provided function, which should write files to the `dir` it gets as an argument,
creating a snapshot of the current state of the code at the supplied path.
"""
function create_expectation_snapshot(func, expected_dir, subpath)
    snapshot_dir = joinpath(expected_dir, subpath)

    mkpath(snapshot_dir)

    func(snapshot_dir)
end

function test_snapshot(func, expected_dir, subpath; allow_additions = true)
    expected_path = joinpath(expected_dir, subpath)

    if !isdir(expected_path)
        mkpath(expected_path)
        func(expected_path)
        @info """Snapshot for \"$subpath\" did not exist. It has been created at:
        $expected_path
        """
        @info "Please run the tests again for any changes to take effect"
        return nothing
    end

    output_path = mktempdir()
    snapshot_dir = joinpath(output_path, subpath)
    mkpath(snapshot_dir)
    func(snapshot_dir)

    @testset "$subpath" begin
        has_failures = _recursive_diff_dirs(expected_path, snapshot_dir; allow_additions)

        if has_failures
            if isinteractive() || force_update()
                if force_update() || input_bool("Replace snapshot with actual result (in $subpath)?")
                    rm(expected_path; recursive=true, force=true)
                    cp(snapshot_dir, expected_path; force=true)
                    @info "Snapshot updated at $expected_path"
                    @info "Please run the tests again for any changes to take effect"
                end
            else
                @error """
                Snapshot test failed for \"$subpath\".
                To update the snapshots either run the tests interactively with 'include(\"test/runtests.jl\")',
                or to force-update all failing snapshots set the environment variable `JULIA_SNAPSHOTTESTS_UPDATE`
                to "true" and re-run the tests via Pkg.
                """
            end
        end
    end
end
function _recursive_diff_dirs(expected_dir, new_dir; allow_additions)
    has_failures = false

    # Collect new files
    new_files = Set(String[])
    for (root, _, files) in walkdir(new_dir)
        for file in files
            subpath = _chopprefix(_chopprefix(file, new_dir), "/")
            push!(new_files, subpath)
        end
    end

    # Walk the expected files and make sure they are all present in the new directory
    for (root, _, files) in walkdir(expected_dir)
        for file in files
            expected_path = joinpath(root, file)
            expected_content = read(expected_path, String)
            subpath = _chopprefix(_chopprefix(expected_path, expected_dir), "/")
            @test subpath in new_files
            if !(subpath in new_files)
                has_failures = true
                @error("New snapshot is missing file `$subpath`. Expected contents:\n",
                        expected_content)
            else
                delete!(new_files, subpath)
                new_path = joinpath(new_dir, subpath)
                new_content = read(new_path, String)
                @test new_content == expected_content
                if new_content != expected_content
                    has_failures = true
                    println("Found non-matching content in `$file`.")
                    display(DeepDiffs.deepdiff(expected_content, new_content))
                end
            end
        end
    end

    # Any remaining files were newly produced by the snapshot, and aren't part of the
    # expected content.
    if !allow_additions
        # Report test failures for the new files if requested
        if !isempty(new_files)
            has_failures = true
            @error("New snapshot contains unexpected files. If this is not an error in your
                case, pass `allow_additions = true`.")
            for path in new_files
                @test false  # report one test failure per unexpected file

                new_path = joinpath(new_dir, path)
                new_content = read(new_path, String)
                @error("File: `$path` contents:\n",
                        new_content)
            end
        end
    end

    return has_failures
end


# Based on `chopprefix` from julia 1.8+
function _chopprefix(s::AbstractString, prefix::AbstractString)
    k = firstindex(s)
    i, j = iterate(s), iterate(prefix)
    while true
        j === nothing && i === nothing && return SubString(s, 1, 0) # s == prefix: empty result
        j === nothing && return @inbounds SubString(s, k) # ran out of prefix: success!
        i === nothing && return SubString(s) # ran out of source: failure
        i[1] == j[1] || return SubString(s) # mismatch: failure
        k = i[2]
        i, j = iterate(s, k), iterate(prefix, j[2])
    end
end

"""
    force_update()

Check if the environment variable `JULIA_SNAPSHOTTESTS_UPDATE` is set to "true".
When true, all failing snapshot tests will automatically update their references.
"""
force_update() = tryparse(Bool, get(ENV, "JULIA_SNAPSHOTTESTS_UPDATE", "false")) === true

"""
    input_bool(prompt)

Display an interactive y/n prompt and return true for 'y', false for 'n'.
Loops until a valid response is given.
"""
function input_bool(prompt)
    while true
        println(prompt, " [y/n]")
        response = readline()
        length(response) == 0 && continue
        reply = lowercase(first(strip(response)))
        if reply == 'y'
            return true
        elseif reply == 'n'
            return false
        end
        # Otherwise loop and repeat the prompt
    end
end
