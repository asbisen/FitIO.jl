"""
    FitFile

This struct represents a FIT file and provides and iterator interface for
sequentially reading messages from the file. It is supposed to be called
using the `FitFile(filename::String)` constructor, which initializes the 
underlying `FitStream` and reads the file header. The iterator interface 
allows users to loop through the messages in the FIT file without needing 
to manage the stream position manually.

FIT file consists of two types of messages:
1. **[Definition Messages](@ref DefinitionMessage)**: These messages define the 
   structure of subsequent data messages. They specify the fields, their types, 
   and sizes for a particular local message number.
2. **[Data Messages](@ref DataMessage)**: These messages contain the actual 
   data values and are structured according to the most recent definition message 
   for their local message number.

Data messages are mostly meaningful for users, while definition messages are 
more relevant for internal parsing logic. In the example usage, we filter 
the messages to only include data messages for user consumption.

# Fields
- `path::AbstractString`: The file path of the FIT file
- `stream::FitStream`: The underlying stream for reading the FIT file data
- `header::FitHeader`: The parsed file header containing metadata about the FIT file
- `definition_messages::Dict{UInt8, DefinitionMessage}`: A dictionary to store 
  definition messages indexed by their local message number

# Example Usage
```julia
fit_file = FitFile("path/to/fitfile.fit")
messages = filter(m -> isa(m, DataMessage), fit_file) # filter data messages
```

"""
struct FitFile
    path::AbstractString
    stream::FitStream
    header::FitHeader
    definition_messages::Dict{UInt8, DefinitionMessage}
    
    function FitFile(f::AbstractString)
        stream = FitStream(f)
        header = read_file_header(stream; seek_back=false)
        return new(f, stream, header, Dict{UInt8, DefinitionMessage}())
    end
end

# Define the iterator interface for FitFile
function Base.iterate(fit::FitFile, state=nothing)
    if state === nothing
        # Initialize state
        pos = position(fit.stream)
    else
        pos = state
    end
    
    # Check if we've reached the end of the data section
    if pos >= fit.header.data_size + fit.header.header_size
        return nothing
    end
    
    # Set stream position
    seek!(fit.stream, pos)
    
    # Read the next message
    header_byte = peek_byte(fit.stream)
    record_type = message_type(header_byte)
    
    local message = nothing
    local next_position = 0
    
    if record_type == DefinitionMsg
        def_msg = decode_definition_message!(fit.stream)
        fit.definition_messages[def_msg.header.local_mesg_num] = def_msg
        message = def_msg
        next_position = position(fit.stream)
    elseif record_type == RegularMsg
        local_msg_number = header_byte & LOCAL_MESG_NUM_MASK
        def_msg = get(fit.definition_messages, local_msg_number, nothing)
        if def_msg === nothing
            error("Data message encountered before definition message at position $(position(fit.stream))")
        end
        data_msg = decode_data_message!(fit.stream, def_msg)
        message = data_msg
        next_position = position(fit.stream)
    else
        error("Unexpected record type $record_type at position $(position(fit.stream))")
    end
    
    return (message, next_position)
end

# Define length and eltype for the iterator
Base.IteratorSize(::Type{FitFile}) = Base.SizeUnknown()

function Base.eltype(::Type{FitFile})
    return Union{DefinitionMessage, DataMessage}
end

# reset the iterator
function reset!(fit::FitFile)
    # Reset the stream position to the start of the data section
    seek!(fit.stream, Int(fit.header.header_size) + 1)
    empty!(fit.definition_messages)
    return fit
end