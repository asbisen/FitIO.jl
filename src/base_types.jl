
## Base Types
# Base type information struct
struct BaseTypeInfo
    id::UInt8
    size::UInt8
    signed::Bool
    numeric::Bool
    type_code::String
    type_name::Symbol
    data_type::DataType
    invalid::UInt64
end

# Hardcoded base type definitions
const BASE_TYPE_NUM = Dict{UInt8,BaseTypeInfo}(
    0x00 => BaseTypeInfo(0x00, 1, false, true, "B", :enum, UInt8, 0xFF),                   # ENUM
    0x01 => BaseTypeInfo(0x01, 1, true, true, "b", :sint8, Int8, 0x7F),                    # SINT8
    0x02 => BaseTypeInfo(0x02, 1, false, true, "B", :uint8, UInt8, 0xFF),                  # UINT8
    0x83 => BaseTypeInfo(0x83, 2, true, true, "h", :sint16, Int16, 0x7FFF),                # SINT16
    0x84 => BaseTypeInfo(0x84, 2, false, true, "H", :uint16, UInt16, 0xFFFF),              # UINT16
    0x85 => BaseTypeInfo(0x85, 4, true, true, "i", :sint32, Int32, 0x7FFFFFFF),            # SINT32
    0x86 => BaseTypeInfo(0x86, 4, false, true, "I", :uint32, UInt32, 0xFFFFFFFF),          # UINT32
    0x07 => BaseTypeInfo(0x07, 1, false, false, "s", :string, String, 0x00),               # STRING
    0x88 => BaseTypeInfo(0x88, 4, true, true, "f", :float32, Float32, 0xFFFFFFFF),         # FLOAT32
    0x89 => BaseTypeInfo(0x89, 8, true, true, "d", :float64, Float64, 0xFFFFFFFFFFFFFFFF), # FLOAT64
    0x0A => BaseTypeInfo(0x0A, 1, false, true, "B", :uint8z, UInt8, 0x00),                 # UINT8Z
    0x8B => BaseTypeInfo(0x8B, 2, false, true, "H", :uint16z, UInt16, 0x0000),             # UINT16Z
    0x8C => BaseTypeInfo(0x8C, 4, false, true, "I", :uint32z, UInt32, 0x00000000),         # UINT32Z
    0x0D => BaseTypeInfo(0x0D, 1, false, true, "B", :byte, UInt8, 0xFF),                   # BYTE
    0x8E => BaseTypeInfo(0x8E, 8, true, true, "q", :sint64, Int64, 0x7FFFFFFFFFFFFFFF),    # SINT64
    0x8F => BaseTypeInfo(0x8F, 8, false, true, "Q", :uint64, UInt64, 0xFFFFFFFFFFFFFFFF),  # UINT64
    0x90 => BaseTypeInfo(0x90, 8, false, true, "L", :uint64z, UInt64, 0x0000000000000000), # UINT64Z
)

# Dynamically create the reverse dictionary
const BASE_TYPE_NAME = Dict{Symbol,BaseTypeInfo}(
    info.type_name => info for info in values(BASE_TYPE_NUM)
)


"""
    base_type(id::UInt8) :: BaseTypeInfo
    base_type(name::Symbol) :: BaseTypeInfo
    
Get base type information by id or name. 

Returns a `BaseTypeInfo` object if found, otherwise throws an `ArgumentError`.
"""
function base_type(id::UInt8)
    get(BASE_TYPE_NUM, id) do 
        throw(ArgumentError("Invalid base type id: $id"))
    end
end

function base_type(name::Symbol)
    get(BASE_TYPE_NAME, name) do
        throw(ArgumentError("Invalid base type name: $name"))
    end
end

# Validation function - this one doesn't throw, just returns true/false
# For validation, create a separate non-throwing function
is_valid_base_type(key::Union{UInt8,Symbol}) = haskey(key isa UInt8 ? BASE_TYPE_NUM : BASE_TYPE_NAME, key)

# Property accessors that throw exceptions for invalid keys
get_base_type_size(key::Union{UInt8,Symbol}) = base_type(key).size
get_base_type_data_type(key::Union{UInt8,Symbol}) = base_type(key).data_type
get_base_type_code(key::Union{UInt8,Symbol}) = base_type(key).type_code
get_base_type_invalid_value(key::Union{UInt8,Symbol}) = base_type(key).invalid
get_base_type_id(key::Union{UInt8,Symbol}) = base_type(key).id
