using Test
using FitIO

include("test_utils.jl")


@testset "Decode Files" begin
    fit_files = get_sdk_fit_files()

    for f in fit_files
        # contains(f, "activity_poolswim_with_hr") && continue  # Skip this file due to known issues
        decoded_data = decode_fit_file(f)
        @test isa(decoded_data, DecodedFitData)
    end
end