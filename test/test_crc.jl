using Test
using FitIO: _extract_file_crc, _calculate_crc

include("test_utils.jl")


@testset "CRC Tests                      " begin
    # Test cases for CRC calculations
    fit_files = get_sdk_fit_files()
    
    for f in fit_files
        extracted_crc = _extract_file_crc(f)
        data = read(f)[1:end-2] # Read the file excluding the last 2 bytes (CRC bytes)
        @test extracted_crc == _calculate_crc(data)
    end
end