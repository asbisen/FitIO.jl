using Test
using FitIO

include("test_utils.jl")

@testset "FitHeader" begin
    # Test cases for CRC calculations
    fit_files = get_sdk_fit_files()

    for f in fit_files
        header = FitHeader(f)
        # simple check to see if the data_type is set correctly
        @test copy(header.data_type) |> String == ".FIT"
    end
end