"""
    FitHeader

Represents the header of a FIT file, which contains metadata about the file format and structure.
The header provides essential information for parsing the remainder of the FIT file correctly,
including version information and the size of the data section.

# Fields
- `header_size::UInt8` - Size of header in bytes (12 or 14). This determines whether a CRC value is present.
- `protocol_version::UInt8` - FIT protocol version that defines the basic structure and encoding rules.
- `profile_version::UInt16` - FIT profile version that defines the available messages and fields.
- `data_size::UInt32` - Size of data section in bytes, excluding the header and CRC.
- `data_type::Vector{UInt8}` - Data type signature (".FIT") that identifies this as a valid FIT file.
- `crc::Union{UInt16, Nothing}` - Header CRC (if header_size == 14) for verifying header integrity.

# Usage
The `FitHeader` is the first structure parsed when reading a FIT file. It's used to:
1. Validate that the file is a proper FIT file (by checking the data_type signature)
2. Determine how to parse the remaining data (using protocol and profile versions)
3. Know how much data to expect (via data_size)
4. Optionally verify header integrity with the CRC checksum

"""
struct FitHeader
    header_size::UInt8
    protocol_version::UInt8
    profile_version::UInt16
    data_size::UInt32
    data_type::Vector{UInt8}
    crc::UInt16
end


"""Read fit header from a fit file"""
function FitHeader(fit_file::AbstractString; 
    endianness::Endianness=LITTLE_ENDIAN, 
    validate_crc::Bool=true)
    
    stream = FitStream(fit_file)
    return FitHeader(stream; endianness=endianness, validate_crc=validate_crc)
end


"""Read fit header from FitStream"""
function FitHeader(stream::FitStream; 
    endianness::Endianness=LITTLE_ENDIAN, 
    validate_crc::Bool=true)

    # seek_back the stream to the original position after reading the header
    # because FitHeader should not mutate the input
    seek_back=true 

    res = read_file_header(stream; seek_back=seek_back, 
                endianness=endianness, validate_crc=validate_crc)
    return res
end



"""
    Base.show(io::IO, header::FitHeader)

Display a FitHeader in a human-readable format with key information highlighted.
"""
function Base.show(io::IO, header::FitHeader)
    data_type_str = String(copy(header.data_type))
    has_crc = header.header_size == HEADER_WITH_CRC_SIZE
    crc_str = has_crc ? @sprintf("0x%04X", header.crc) : "-"
    profile_major = header.profile_version ÷ 100
    profile_minor = header.profile_version % 100
    profile_str = @sprintf("%u.%02u", profile_major, profile_minor)
    print(io, "FitHeader(",
        "type=\"$data_type_str\", ",
        "hdr=$(header.header_size), ",
        "proto=$(header.protocol_version), ",
        "prof=$profile_str, ",
        "size=$(header.data_size)B, ",
        "crc=$crc_str)")
end


"""
    Base.show(io::IO, ::MIME"text/plain", header::FitHeader; verbose=false)

Display a FitHeader, with optional diagnostic information if `verbose=true`.

```julia-repl
julia> show(stdout, MIME"text/plain"(), h; verbose=true)
FitHeader(type=".FIT", hdr=14, proto=32, prof=211.58, size=94080B, crc=0xCC09)
  Diagnostics:
    Signature:      ✓ Valid
    Protocol:       ✓ Supported
    Data Size:      ✓ Non-empty
    Header CRC:     ✓ Present
```
"""
function Base.show(io::IO, ::MIME"text/plain", header::FitHeader; verbose::Bool=false)
    show(io, header)

    if verbose
        println(io)
        println(io, "  Diagnostics:")

        # Validate data type signature
        expected_signature = UInt8[0x2E, 0x46, 0x49, 0x54]  # ".FIT"
        signature_valid = header.data_type == expected_signature
        signature_status = signature_valid ? "✓ Valid" : "✗ Invalid"
        println(io, "    Signature:      $signature_status")

        # Protocol version info
        protocol_status = if header.protocol_version >= 10
            "✓ Supported"
        elseif header.protocol_version >= 1
            "⚠ Legacy"
        else
            "✗ Unknown"
        end
        println(io, "    Protocol:       $protocol_status")

        # Data size validation
        size_status = if header.data_size > 0
            "✓ Non-empty"
        else
            "⚠ Empty"
        end
        println(io, "    Data Size:      $size_status")

        # Header integrity
        if header.header_size == HEADER_WITH_CRC_SIZE
            println(io, "    Header CRC:     ✓ Present")
        else
            println(io, "    Header CRC:     - Not included")
        end
    end
end




"""
    read_file_header!(stream::FitStream, seek_back::Bool = true, validate_crc::Bool=true)::FitHeader

Function to read FIT file header from stream. By default the position of the pointer
to FitStream is moved unless seek_back is set to true.
"""
function read_file_header(stream::FitStream;
    seek_back::Bool=true,
    endianness::Endianness=LITTLE_ENDIAN,
    validate_crc::Bool=true)::FitHeader

    original_pos = position(stream)
    seekstart!(stream)

    try
        # Read header size
        header_size = read_byte!(stream)
        if header_size != HEADER_WITH_CRC_SIZE && header_size != HEADER_WITHOUT_CRC_SIZE
            throw(FitDecoderError("Invalid header size: $header_size @ $(position(stream))"))
        end

        # Read protocol version
        protocol_version = read_byte!(stream)

        # Read profile version (2 bytes, little endian)
        profile_version = read_uint16!(stream, endianness)

        # Read data size (4 bytes, little endian)
        data_size = read_uint32!(stream, endianness)

        # Read data type (4 bytes) (Should be ASCII Value of ".FIT")
        data_type = read_bytes!(stream, 4)

        # Read CRC if present
        header_crc = if header_size == HEADER_WITH_CRC_SIZE
            read_uint16!(stream, LITTLE_ENDIAN)
        else
            0x0000
        end

        
        # Validate CRC if validation is enabled
        if header_size == HEADER_WITH_CRC_SIZE && validate_crc
            # Save current position to read header bytes for CRC validation
            current_position = position(stream) 
            seekstart!(stream)
            header_bytes = peek_bytes(stream, Int(header_size))
            # Reset position of the stream to the original position
            seek!(stream, current_position) 

            computed_crc = _calculate_crc(header_bytes[1:end-2])
            if computed_crc != header_crc
                err_str = "Header CRC mismatch: computed $(computed_crc), expected $(header_crc)"
                throw(FitDecoderError(err_str))
            end
        end


        header = FitHeader(
            header_size,
            protocol_version,
            profile_version,
            data_size,
            data_type,
            header_crc
        )

        if seek_back
            seek!(stream, original_pos)
        end

        return header

    catch e
        if seek_back
            seek!(stream, original_pos)
        end
        throw(e)
    end
end