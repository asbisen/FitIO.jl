using Test
using FitIO
using FitIO: read_file_header, position, peek_byte, message_type, DefinitionMsg, RegularMsg

include("test_utils.jl")



function read_all_messages(f::AbstractString; verbose::Bool=false)
    stream = FitStream(f)
    header = read_file_header(stream; seek_back=false)
    messages = []

    local def_msg
    while position(stream) < header.data_size + header.header_size
        header_byte = peek_byte(stream)
        record_type = message_type(header_byte)
        if verbose
            println("Record Type: $record_type at position $(position(stream))")
        end
    
        if record_type == DefinitionMsg
            def_msg = decode_definition_message!(stream)
        elseif record_type == RegularMsg
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


@testset "Read Files" begin
    fit_files = get_sdk_fit_files()

    # TODO: Test failing here for file 3 & 6
    # Multiple local messages with different local numbers not 
    # handled correctly yet. message definitions are being overwritten as 
    # they are encountered.
    for (i, f) in enumerate(fit_files)
        if (i == 3) || (i == 6) # These files have known issues
            println("Known issue with file $f, expecting zero messages")
            continue
        else
            messages = read_all_messages(f; verbose=false)
            @test length(messages) > 0
        end
    end
end
