using Test
using FitIO
using FitIO: read_file_header, position, peek_byte, message_type, DefinitionMsg, RegularMsg, LOCAL_MESG_NUM_MASK

include("test_utils.jl")



function read_all_messages(f::AbstractString; verbose::Bool=false)
    stream = FitStream(f)
    header = read_file_header(stream; seek_back=false)
    messages = []

    local definition_messages = Dict{UInt8, FitIO.DefinitionMessage}()

    local def_msg
    while position(stream) < header.data_size + header.header_size
        header_byte = peek_byte(stream)
        record_type = message_type(header_byte)
        if verbose
            println("Record Type: $record_type at position $(position(stream))")
        end
    
        if record_type == DefinitionMsg
            def_msg = decode_definition_message!(stream)
            definition_messages[def_msg.header.local_mesg_num] = def_msg

        elseif record_type == RegularMsg
            local_msg_number = header_byte & FitIO.LOCAL_MESG_NUM_MASK # Get the local message number
            def_msg = get(definition_messages, local_msg_number, nothing)
            if def_msg === nothing
                error("Data message encountered before definition message at position $(position(stream))")
            end
            data_msg = decode_data_message!(stream, def_msg)
            push!(messages, data_msg)
        else
            error("Unexpected record type $record_type at position $(position(stream))")
        end
    end
    return messages
end


@testset "Read Files                     " begin
    fit_files = get_sdk_fit_files()

    for f in fit_files
        messages = read_all_messages(f; verbose=false)
        @test length(messages) > 0
    end
end
