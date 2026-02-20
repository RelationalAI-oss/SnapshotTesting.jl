using SnapshotTesting
using Test

@testset "SnapshotTesting.jl" begin
    @testset "snapshots" begin
        include("snapshots.jl")
    end
    @testset "update modes" begin
        include("test_update_modes.jl")
    end
    @testset "scaffolding" begin
        include("scaffolding.jl")
    end
end
