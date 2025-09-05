"""
    _calculate_crc(data::Vector{UInt8}, start::Int = 1, length::Int = length(data))::UInt16

Calculate CRC-16 checksum for the given data using the FIT CRC algorithm.

# Arguments
- `data::Vector{UInt8}`: The data to calculate CRC for
- `start::Int`: Starting position in the data (1-based, default: 1)
- `byte_count::Int`: Number of bytes to include (default: all remaining bytes)

# Returns
- `UInt16`: The calculated CRC-16 checksum
"""
function _calculate_crc(data::Vector{UInt8},
    start::Int=1,
    byte_count::Int=length(data) - start + 1)::UInt16

    if isempty(data)
        return UInt16(0)
    end

    if start < 1 || start > length(data)
        throw(FitDecoderError("Invalid start position: $start"))
    end

    if start + byte_count - 1 > length(data)
        throw(FitDecoderError("Length extends beyond data bounds"))
    end

    crc = UInt16(0)

    for i in start:(start+byte_count-1)
        byte = data[i]

        # Process low nibble
        tmp = CRC_TABLE[((crc&0x000F)⊻(byte&0x0F))+1]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ⊻ tmp

        # Process high nibble
        tmp = CRC_TABLE[((crc&0x000F)⊻((byte>>4)&0x0F))+1]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ⊻ tmp
    end

    return crc
end



"""
    _extract_file_crc(data::Vector{UInt8})::UInt16
    _extract_file_crc(filename::String)::UInt16

Extract the CRC value from the last 2 bytes of FIT file data or file.

# Arguments
- `data::Union{Vector{UInt8}, String}`: The complete file data

# Returns
- `UInt16`: The CRC value from the file
"""
function _extract_file_crc(data::Vector{UInt8})::UInt16
    if length(data) < CRCSIZE
        throw(FitDecoderError("Data too short to contain CRC"))
    end

    crc_start = length(data) - CRCSIZE + 1
    return UInt16(data[crc_start]) | (UInt16(data[crc_start+1]) << 8)
end

_extract_file_crc(filename::String)::UInt16 = read(filename) |> _extract_file_crc


"""
    _validate_file_crc(data::Vector{UInt8})::Bool
    _validate_file_crc(filename::String)::Bool

Validate the CRC of FIT file data or file by comparing computed CRC with the stored CRC.
"""
function _validate_crc(data::Vector{UInt8})::Bool
    if length(data) < CRCSIZE
        throw(FitDecoderError("Data too short to contain CRC"))
    end

    computed_crc = _calculate_crc(data, 1, length(data) - CRCSIZE)
    file_crc = _extract_file_crc(data)

    return computed_crc == file_crc
end

_validate_crc(filename::String)::Bool = read(filename) |> _validate_crc