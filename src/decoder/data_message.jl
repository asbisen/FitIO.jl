struct DataMessage 
    definition::DefinitionMessage
    raw_values::Vector{Any}
end

function _read_single_numeric_field!(stream::FitStream, datatype::DataType; endianness=LITTLE_ENDIAN)
    data = read_bytes!(stream, sizeof(datatype))
    if endianness == BIG_ENDIAN
        result = reinterpret(datatype, data)[1] |> bswap
    else
        result = reinterpret(datatype, data)[1]
    end
    return result
end


function read_field_value!(stream::FitStream, f::FieldDefinition; endianness=LITTLE_ENDIAN)
    data_type = get_base_type_data_type(f.base_type)
    num_elements = f.num_field_elements

    
    if (num_elements == 1) && (data_type <: Number)
        result = _read_single_numeric_field!(stream, data_type; endianness=endianness)
        return result

    elseif (num_elements > 1) && (data_type <: Number)
        result = [
            _read_single_numeric_field!(stream, data_type; endianness=endianness) for _ in 1:num_elements
        ]

    elseif data_type == String
        result = read_string!(stream, f.num_field_elements)
    
    else 
        errmsg = "Unsupported data type $(data_type) for field $(f.field_id)"
        @error "$errmsg"
        throw(FitFile.FitDecoderError("$errmsg", stream.position))
    end
end

# TODO: Fix this to handle developer fields correctly
function read_developer_field_value!(stream::FitStream, f::DeveloperFieldDefinition; endianness=LITTLE_ENDIAN)
    result = read_bytes!(stream, Int(f.developer_field_size))
    if endianness == BIG_ENDIAN
        result = bswap.(result)
    end
    return result
end


function decode_data_message!(stream::FitStream, definition::DefinitionMessage)::DataMessage

    endianness = definition.header.endianness

    # Read raw values from the stream based on the definition
    raw_values = Vector{Any}(undef, length(definition.field_definitions) + length(definition.developer_field_defs))

    header_byte = read_byte!(stream)
    if message_type(header_byte) != RegularMsg
        errmsg = "Expected RegularMsg but got $(message_type(header_byte)) at position $(position(stream))"
        @error "$errmsg"
        throw(FitFile.FitDecoderError(errmsg, position(stream)))
    end

    for (i, field_def) in enumerate(definition.field_definitions)
        raw_values[i] = read_field_value!(stream, field_def; endianness=endianness)
    end

    for (i, dev_field_def) in enumerate(definition.developer_field_defs)
        raw_values[length(definition.field_definitions) + i] = read_developer_field_value!(stream, dev_field_def; endianness=endianness)
    end

    return DataMessage(definition, raw_values)
end