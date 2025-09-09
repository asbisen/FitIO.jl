

# helper structs for better organization
struct DefinitionHeader
    record_header::UInt8
    local_mesg_num::UInt8
    reserved::UInt8
    architecture::UInt8
    endianness::Endianness
    global_mesg_num::UInt16
    num_fields::UInt8
end


"""
    read_definition_header(stream::FitStream) -> DefinitionHeader

Reads and parses a FIT definition message header from the given `stream`. 
Extracts relevant fields such as record header, local message number, reserved byte, 
architecture, endianness, global message number, and number of fields, and returns 
a `DefinitionHeader` struct containing this information.
"""
function read_definition_header!(stream::FitStream)::DefinitionHeader
    record_header = read_byte!(stream)
    local_mesg_num = record_header & LOCAL_MESG_NUM_MASK
    reserved = read_byte!(stream)
    @assert reserved == 0 "Reserved byte should be zero, got $(reserved)"
    architecture = read_byte!(stream)
    endianness = architecture == 0 ? LITTLE_ENDIAN : BIG_ENDIAN
    global_mesg_num = read_uint16!(stream, endianness)
    num_fields = read_byte!(stream)

    return DefinitionHeader(record_header, local_mesg_num, reserved, 
        architecture, endianness, global_mesg_num, num_fields)
end






struct FieldDefinition
    field_id::UInt8
    field_size::UInt8
    base_type::UInt8
    num_field_elements::Int
    local_mesg_num::UInt8
    global_mesg_num::UInt16
end


"""
    validate_base_type(base_type::UInt8, field_size::UInt8) -> UInt8

Validates whether the provided `base_type` is a recognized type and checks if `field_size` 
is a multiple of the base type's size. If the base type is invalid or the field size is not 
compatible, it falls back to returning the type ID for `:uint8`.
"""
# Helper function to validate and adjust base type
function validate_base_type(base_type::UInt8, field_size::UInt8)::UInt8

    if !is_valid_base_type(base_type) 
        @warn "Invalid base type $base_type for field size $field_size, falling back to UINT8"
        return get_base_type_id(:uint8)
    end

    def_size = get_base_type_size(base_type)
    if field_size % def_size != 0
        @debug "Field size $field_size is not a multiple of base type size $def_size"
        return get_base_type_id(:uint8) # fallback to UINT8
    end

    return base_type
end


"""
    get_field_format_string(base_type::UInt8, num_elements::Int) -> String

Constructs a format string for a field based on its base type and the number of elements.
The format string is used for binary parsing, where `type_code` represents the data type
and is repeated according to `num_elements` if greater than one.

TODO: Eventually this should not be required if we end up using a more flexible approach
"""
function get_field_format_string(base_type::UInt8, num_elements::Int)::String
    type_code = get_base_type_code(base_type)
    return num_elements > 1 ? string(num_elements) * type_code : type_code
end


""" build struct format string for a message based on its header and field definitions"""
function build_struct_format_string(header::DefinitionHeader, field_defs::Vector{FieldDefinition})::String
    endianness = header.endianness
    struct_format_string = endianness == LITTLE_ENDIAN ? "<" : ">"
    
    for field_def in field_defs
        struct_format_string *= get_field_format_string(field_def.base_type, field_def.num_field_elements)
    end
    
    return struct_format_string
end


"""
    read_field_definitions!(stream::FitStream, header::DefinitionHeader)

Reads and parses a specified number of field definitions from the given FIT data stream, 
taking into account the specified endianness. Returns a tuple containing the list of parsed 
`FieldDefinition` objects, the corresponding struct format string, and the total message size in bytes.
"""
function read_field_definitions!(stream::FitStream, header::DefinitionHeader)
    num_fields = header.num_fields
    endianness = header.endianness

    field_defs = Vector{FieldDefinition}(undef, num_fields)

    for x in 1:num_fields
        field_id = read_byte!(stream)
        field_size = read_byte!(stream)
        base_type = read_byte!(stream)

        # validate and potentially adjust base type
        validated_base_type = validate_base_type(base_type, field_size)
        if validated_base_type != base_type
            @warn "Adjusted base type from $base_type to $validated_base_type for field size $field_size"
            base_type = validated_base_type
        end

        # Calculate field elements and build format string
        def_size = get_base_type_size(base_type)
        num_field_elements = trunc(Int, field_size / def_size)

        local_mesg_num = header.local_mesg_num
        global_mesg_num = header.global_mesg_num
        field_defs[x] = FieldDefinition(field_id, field_size, base_type, 
                                    num_field_elements, local_mesg_num, global_mesg_num)
    end
    return field_defs
end




struct DeveloperFieldDefinition
    field_definition_number::UInt8
    developer_field_size::UInt8
    developer_data_index::UInt8
    endianness::Endianness
end


"""Return true if message has developer field"""
function hasdeveloperfield(header_byte::UInt8)::Bool
    return (header_byte & DEV_DATA_MASK != DEV_DATA_MASK) ? false : true
end

"""
    read_developer_fields(stream::FitStream, header::DefinitionHeader) -> Tuple{Vector{DeveloperFieldDefinition}, Int}

Reads and parses developer field definitions from a FIT file stream based on the provided header.
Returns a tuple containing a vector of `DeveloperFieldDefinition` objects and the total size of 
developer data fields. If no developer fields are present, returns an empty vector and zero size.
"""
function read_developer_fields!(stream::FitStream, header::DefinitionHeader)

    developer_field_defs = DeveloperFieldDefinition[]
    developer_data_size = 0

    if !hasdeveloperfield(header.record_header)
        return developer_field_defs
    end

    num_dev_fields = read_byte!(stream)

    for _ in 1:num_dev_fields
        field_definition_number = read_byte!(stream)
        developer_field_size = read_byte!(stream)
        developer_data_index = read_byte!(stream)
        endianness = header.architecture == 0 ? LITTLE_ENDIAN : BIG_ENDIAN

        push!(developer_field_defs, DeveloperFieldDefinition(
            field_definition_number, developer_field_size,
            developer_data_index, endianness))
    end

    return developer_field_defs
end




struct DefinitionMessage
    header::DefinitionHeader
    field_definitions::Vector{FieldDefinition}
    developer_field_defs::Vector{DeveloperFieldDefinition}
    struct_format_string::String
end


function decode_definition_message!(stream::FitStream)::DefinitionMessage
    header = read_definition_header!(stream)

    # Read field definitions
    field_defs = read_field_definitions!(stream, header)

    # Build struct format string for the message
    struct_format_string = build_struct_format_string(header, field_defs)

    # Read developer fields if present (not implemented in this snippet)
    developer_field_defs = read_developer_fields!(stream, header) 

    return DefinitionMessage(header, field_defs, developer_field_defs, struct_format_string)
end



""" Returns the total size of a message based on its field definitions"""
function compute_message_size(msg::DefinitionMessage)::Int
    message_size = 0
    if !isempty(msg.field_definitions)
        message_size += sum(field_def.field_size for field_def in msg.field_definitions)
    end
    if !isempty(msg.developer_field_defs)
        message_size += sum(dev_field_def.developer_field_size for dev_field_def in msg.developer_field_defs)
    end
    return message_size
end