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

# Additional helper function to reset the iterator
function reset!(fit::FitFile)
    # Reset the stream position to the start of the data section
    seek!(fit.stream, Int(fit.header.header_size) + 1)
    empty!(fit.definition_messages)
    return fit
end