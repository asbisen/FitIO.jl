# IO Stream

"""
    FitStream

A stream wrapper for reading FIT file data from various sources. This struct provides a consistent interface
for parsing FIT files regardless of whether the data comes from a file, byte array, or IO stream.

The FitStream handles tracking the current position during parsing and provides methods for navigating
through the binary data. It's a core component that other parts of the library use to sequentially read
structured data according to the FIT file format specification.

# Fields
- `data::Vector{UInt8}`: The raw byte data of the FIT file
- `position::Int`: Current position in the stream (1-based indexing)
- `length::Int`: Total length of the stream in bytes

# Usage
FitStream can be created from:
- A file path: `FitStream("workout.fit")`
- A byte array: `FitStream(data::Vector{UInt8})`
- An IO object: `FitStream(io::IO)`

The stream maintains its position as data is read, allowing for sequential parsing of the file structure.
"""
mutable struct FitStream
    data::Vector{UInt8}
    position::Int
    length::Int

    function FitStream(data::Vector{UInt8})
        new(data, 1, length(data))
    end
end


"""Create a FitStream from a file."""
function FitStream(filename::String)
    if !isfile(filename)
        throw(FitStreamError("File not found: $filename"))
    end

    try
        data = read(filename)
        return FitStream(data)
    catch e
        throw(FitStreamError("Failed to read file $filename: $e"))
    end
end


"""Create a FitStream from an IO object."""
function FitStream(io::IO)
    try
        data = read(io)
        return FitStream(data)
    catch e
        throw(FitStreamError("Failed to read from IO: $e"))
    end
end


function Base.show(io::IO, stream::FitStream)
    preview_len = min(8, stream.length)
    preview = stream.data[1:preview_len]
    print(io, "FitStream(position=$(stream.position), length=$(stream.length), data[1:$preview_len]=$(preview))")
end


"""Get the current position in the stream."""
position(stream::FitStream)::Int = stream.position


"""Get the total length of the stream."""
Base.length(stream::FitStream)::Int = stream.length


"""Get the number of remaining bytes in the stream."""
remaining_bytes(stream::FitStream)::Int = max(0, length(stream) - position(stream) + 1)


"""Check if the stream is at the end. Accounts for last 2 bytes reserved for CRC."""
at_end(stream::FitStream)::Bool = position(stream) > (length(stream) - CRCSIZE)


"""
    peek_byte(stream::FitStream)::UInt8

Peek at the next byte without advancing position.
"""
function peek_byte(stream::FitStream)::UInt8
    if position(stream) > length(stream)
        throw(FitStreamError("attempt to peek beyond end of stream", position(stream)))
    end

    return stream.data[position(stream)]
end


"""
    peek_bytes(stream::FitStream, count::Int)::Vector{UInt8}

Peek at multiple bytes without advancing position.
"""
function peek_bytes(stream::FitStream, count::Int)::Vector{UInt8}
    if count <= 0
        return UInt8[]
    end

    if position(stream) + count - 1 > length(stream)
        throw(FitStreamError("Attempt to peek $count bytes beyond end of stream", position(stream)))
    end

    return stream.data[position(stream):position(stream)+count-1]
end



"""
    slice(stream::FitStream, start::Int, length::Int)::Vector{UInt8}

Get a slice of data from the stream without affecting position.
"""
function slice(stream::FitStream, start::Int, length::Int)::Vector{UInt8}
    if start < 1 || start > stream.length
        throw(FitStreamError("Invalid slice start position: $start"))
    end

    if start + length - 1 > stream.length
        throw(FitStreamError("Slice extends beyond stream length"))
    end

    return stream.data[start:start+length-1]
end


"""
    seek!(stream::FitStream, pos::Int)

Seek to a specific position in the stream.
"""
function seek!(stream::FitStream, pos::Int)::FitStream
    if pos < 1 || pos > stream.length + 1
        throw(FitStreamError("Invalid seek position: $pos", position(stream)))
    end

    stream.position = pos
    stream
end



"""
    seekstart!(stream::FitStream)

Seek to the begining in the stream.
"""
function seekstart!(stream::FitStream)::FitStream
    stream.position = 1
    stream
end


"""
    read_byte!(stream::FitStream)::UInt8

Read a single byte from the stream and advance position.
"""
function read_byte!(stream::FitStream)::UInt8
    if position(stream) > stream.length
        throw(FitStreamError("Attempt to read beyond end of stream", stream.position))
    end

    byte = stream.data[position(stream)]
    stream.position += 1
    return byte
end


"""
    read_bytes!(stream::FitStream, count::Int)::Vector{UInt8}

Read multiple bytes from the stream and advance position.
"""
function read_bytes!(stream::FitStream, count::Int)::Vector{UInt8}
    if count <= 0
        return UInt8[]
    end

    if position(stream) + count - 1 > stream.length
        throw(FitStreamError("Attempt to read $count bytes beyond end of stream", position(stream)))
    end

    bytes = stream.data[position(stream):position(stream)+count-1]
    stream.position += count
    return bytes
end


"""
    read_string!(stream::FitStream, string_length::Int)::String

Read a string from the stream with the given string length.
"""
function read_string!(stream::FitStream, string_length::Int)::String
    if string_length <= 0
        return ""
    end

    # Read the specified number of bytes
    bytes = read_bytes!(stream, string_length)

    # Convert bytes to string, handling null-terminated strings
    # Find the first null byte (0x00) if it exists
    null_index = findfirst(==(0x00), bytes)
    if null_index !== nothing
        bytes = bytes[1:null_index-1]
    end

    return String(bytes)
end


"""
    read_uint16!(stream::FitStream, endian::Endianness = LITTLE_ENDIAN)::UInt16

Read a 16-bit unsigned integer from the stream.
"""
function read_uint16!(stream::FitStream, endian::Endianness=LITTLE_ENDIAN)::UInt16
    bytes = read_bytes!(stream, 2)

    # Read as little-endian using reinterpret, then convert if needed
    value = reinterpret(UInt16, bytes)[1]
    return endian == LITTLE_ENDIAN ? value : bswap(value)
end


"""
    read_uint32!(stream::FitStream, endian::Endianness = LITTLE_ENDIAN)::UInt32

Read a 32-bit unsigned integer from the stream.
"""
function read_uint32!(stream::FitStream, endian::Endianness=LITTLE_ENDIAN)::UInt32
    bytes = read_bytes!(stream, 4)

    # Read as little-endian using reinterpret, then convert if needed
    value = reinterpret(UInt32, bytes)[1]
    return endian == LITTLE_ENDIAN ? value : bswap(value)
end
