module SnapshotTesting

import DeepDiffs

using Test

include("snapshots.jl")
include("suite.jl")

export SnapshotTestSuite,
    snapshot_tests,
    snapshot_expected_dir,
    snapshot_produce,
    snapshot_test_extras,
    snapshot_allow_additions,
    run_snapshot_tests

end
