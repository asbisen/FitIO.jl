using Test
using FitIO
using Dates

import FitIO: decode

include("test_utils.jl")


# Get the list of .fit files from the SDK directory
# handles the case to check for the existence of the directory
function get_sdk_fit_files()
    path = ""
    if isdir("data/sdk/")
        path = "data/sdk/"
    elseif isdir("../data/sdk/")
        path = "../data/sdk/"
    else
        throw(ArgumentError("Please provide a valid path or ensure the 'data/sdk/' directory exists."))
    end
    return scan_fit_files(path)
end


function decode_messages(f::AbstractString; verbose::Bool=false)
    fitfile = FitIO.FitFile(f)
    records = [m for m in fitfile if isa(m, FitIO.DataMessage)]
    profile = PROFILE
    decoded_messages = decode.(Ref(DecoderConfig()), records; profile=profile)
    decoded_messages
end



## Simple test to verify that all sdk .fit files can be decoded without errors and produce 
## at least one decoded message.
@testset "Decode SDK FitFiles            " begin
    fit_files = get_sdk_fit_files()
    for f in fit_files
        messages = decode_messages(f; verbose=false)
        @test length(messages) > 0
    end
end

@testset "Validate Edge1050 FitFile      " begin
    profile = PROFILE
    fitdata = DecodedFitFile("$(@__DIR__)/../data/custom/activity_edge_rally_hrm.fit")
    @test haskey(fitdata, "device_info")
    @test length(fitdata["device_info"]) == 20
    @test fitdata["device_info"][1]["manufacturer"]   == FieldData("garmin","")
    @test fitdata["device_info"][8]["manufacturer"]   == FieldData("sram","")
    @test fitdata["device_info"][1]["garmin_product"] == FieldData("edge_1050","")
    @test fitdata["activity"][1]["timestamp"] == FieldData(DateTime("2026-02-17T22:05:18"), "")
    @test fitdata["sport"][1]["sport"] == FieldData("cycling", "")
end