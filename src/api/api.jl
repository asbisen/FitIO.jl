
# Struct for Base Decoded Fields
struct DecodedField
    name::String
    value::Any
    units::Any  # Union{String, Nothing} 
    original_raw_value::Any
    field_id::UInt8
    is_valid::Bool
    metadata::Dict{String, Any}
end



# Decoded Message Structure (Message Containes Many Fields)
# Holds all relevant information about a decoded FIT message
struct DecodedMessage
    message_name::String
    global_mesg_num::UInt16
    fields::Dict{String, DecodedField}
    timestamp::Union{DateTime, Nothing}
    developer_fields::Dict{String, Any}
    raw_message::DataMessage
    metadata::Dict{String, Any}  
end



# Collection of decoded messages
# Holds all decoded messages from a FIT file along with metadata
struct DecodedFitData
    messages::Vector{DecodedMessage}
    message_types::Dict{String, Vector{DecodedMessage}}
    metadata::Dict{String, Any}
end





# ----- Utility Functions for Decoded Structures -----
# ----- used internally                          ----- 
"""
    is_invalid_value(value, base_type::UInt8) -> Bool
    
Check if a single value represents an invalid/missing value according 
to FIT specification. For use with individual elements, not vectors.
"""
function is_invalid_value(value, base_type::UInt8)::Bool
    !is_valid_base_type(base_type) && return true
    invalid_val = get_base_type_invalid_value(base_type)
    return value == invalid_val
end

"""
    clean_invalid_values(raw_value, base_type::UInt8) -> Any
    
Convert invalid values to `nothing` while preserving valid values.
Handles both single values and vectors appropriately.
"""
function clean_invalid_values(raw_value, base_type::UInt8)
    !is_valid_base_type(base_type) && return nothing
    
    invalid_val = get_base_type_invalid_value(base_type)
    if raw_value isa Vector # Handle vectors element-wise
        return [v == invalid_val ? nothing : v for v in raw_value]
    else # Handle single values
        return raw_value == invalid_val ? nothing : raw_value
    end
end


"""
    has_any_valid_values(raw_value, base_type::UInt8) -> Bool
    
Check if there are any valid values (for vectors) or if the single value is valid.
"""
function has_any_valid_values(raw_value, base_type::UInt8)
    !is_valid_base_type(base_type) && return false
    
    invalid_val = get_base_type_invalid_value(base_type)    
    if raw_value isa Vector
        return any(v -> v != invalid_val, raw_value)
    else
        return raw_value != invalid_val
    end
end


"""
    count_valid_values(raw_value, base_type::UInt8) -> Int
    
Count the number of valid values in a vector, or return 1/0 for single values.
"""
function count_valid_values(raw_value, base_type::UInt8)
    !is_valid_base_type(base_type) && return 0
    
    invalid_val = get_base_type_invalid_value(base_type)    
    if raw_value isa Vector
        return count(v -> v != invalid_val, raw_value)
    else
        return raw_value != invalid_val ? 1 : 0
    end
end



"""
    apply_scale_and_offset_safe(value, scale, offset) -> Any
    
Apply scaling and offset to numeric values, preserving `nothing` values.
"""
function apply_scale_and_offset_safe(value, scale, offset)
    if value === nothing
        return nothing
    elseif value isa Vector
        return [v === nothing ? nothing : (v / scale) + offset for v in value]
    else
        return (value / scale) + offset
    end
end


"""
    lookup_enum_value(raw_value, enum_type::String, profile::FitProfile) -> Any
    
Look up enum value from profile types, handling nothing values.
"""
function lookup_enum_value(raw_value, enum_type::String, profile::FitProfile)
    if raw_value === nothing
        return nothing
    end
    
    # Check if the enum type exists in profile
    if haskey(profile.types, enum_type)
        enum_dict = profile.types[enum_type]
        raw_value_str = string(raw_value)
        
        # Check if the raw value exists in the enum
        if haskey(enum_dict, raw_value_str)
            enum_info = enum_dict[raw_value_str]
            
            # Handle different possible structures
            if enum_info isa Dict
                # If enum_info is a dictionary, look for "name" key
                return get(enum_info, "name", raw_value)
            elseif enum_info isa String
                # If enum_info is already a string, return it directly
                return enum_info
            else
                # If it's something else, return it as-is
                return enum_info
            end
        end
    end
    
    # Return raw value if enum not found
    return raw_value
end

"""
    convert_string_field(raw_value) -> String
    
Convert raw bytes to string, handling null termination and nothing values.
"""
function convert_string_field(raw_value)
    if raw_value === nothing
        return nothing
    elseif raw_value isa Vector{Union{UInt8, Nothing}}
        # Handle mixed vector with some nothing values
        if all(v -> v === nothing, raw_value)
            return nothing
        end
        
        # Filter out nothing values and convert
        valid_bytes = filter(v -> v !== nothing, raw_value)
        if isempty(valid_bytes)
            return nothing
        end
        
        # Find null terminator and convert to string
        null_idx = findfirst(x -> x == 0x00, valid_bytes)
        if null_idx !== nothing
            return String(valid_bytes[1:null_idx-1])
        else
            return String(valid_bytes)
        end
    elseif raw_value isa Vector{UInt8}
        # Standard byte vector handling
        null_idx = findfirst(x -> x == 0x00, raw_value)
        if null_idx !== nothing
            return String(raw_value[1:null_idx-1])
        else
            return String(raw_value)
        end
    else
        return string(raw_value)
    end
end


"""
    process_components(raw_value, components::Vector, profile::FitProfile) -> Dict
    
Process component fields that are packed into a single value.
Conservative approach.

TODO: Implement bit extraction properly.
"""
function process_components(raw_value, components::Vector, profile::FitProfile)
    component_values = Dict{String, Any}()
    
    for (i, component) in enumerate(components)
        try
            if isa(component, Dict)
                # Handle dictionary-style components
                if haskey(component, "bits") && !isempty(component["bits"])
                    component_name = get(component, "name", "component_$i")
                    # Store the raw value and bit specification for now
                    component_values[component_name] = Dict(
                        "raw_value" => raw_value,
                        "bits" => component["bits"],
                        "needs_implementation" => true
                    )
                end
            elseif isa(component, Number) && isa(raw_value, Number)
                # Only do bit extraction for numeric raw values with numeric components
                component_name = "component_$i"
                extracted_value = (raw_value >> component) & 1
                component_values[component_name] = extracted_value
            else
                # For all other cases, just store the component info
                component_name = "component_$i"
                component_values[component_name] = Dict(
                    "raw_value" => raw_value,
                    "component" => component,
                    "raw_value_type" => typeof(raw_value),
                    "component_type" => typeof(component),
                    "needs_implementation" => true
                )
            end
        catch e
            @debug "Error processing component $i: $e" component=component raw_value=raw_value
            # Store debug info instead of failing
            component_values["component_$i"] = Dict(
                "error" => string(e),
                "component" => component,
                "raw_value" => raw_value
            )
        end
    end
    
    return component_values
end


"""
    process_subfields(raw_value, field_def::FieldDefinition, subfields::Vector, 
                     decoded_fields::Dict, profile::FitProfile) -> Any
    
Process subfields based on conditions and return appropriate value.
"""
function process_subfields(raw_value, field_def::FieldDefinition, subfields::Vector, 
                          decoded_fields::Dict, profile::FitProfile)
    
    for subfield in subfields
        # Check subfield conditions
        if haskey(subfield, "ref_fields") && !isempty(subfield["ref_fields"])
            conditions_met = true
            
            for ref_field in subfield["ref_fields"]
                ref_field_name = ref_field["name"]
                ref_field_value = ref_field["value"]
                
                # Check if condition is met
                if haskey(decoded_fields, ref_field_name)
                    field_val = decoded_fields[ref_field_name].value
                    if field_val != ref_field_value
                        conditions_met = false
                        break
                    end
                else
                    conditions_met = false
                    break
                end
            end
            
            if conditions_met
                # Use this subfield for decoding
                scale = get(subfield, "scale", [1])[1]
                offset = get(subfield, "offset", [0])[1]
                
                decoded_value = apply_scale_and_offset(raw_value, scale, offset)
                
                # Handle enum lookup for subfield
                if haskey(subfield, "type") && haskey(profile.types, subfield["type"])
                    decoded_value = lookup_enum_value(decoded_value, subfield["type"], profile)
                end
                
                return decoded_value
            end
        end
    end
    
    # No subfield conditions met, return original processing
    return raw_value
end


"""
    countmap(itr) -> Dict{T, Int} where T
    
Count occurrences of each unique element in an iterable.
Returns a dictionary mapping each unique element to its count.
"""
function countmap(itr)
    T = eltype(itr)
    counts = Dict{T, Int}()
    for item in itr
        counts[item] = get(counts, item, 0) + 1
    end
    return counts
end


# ----- End of Utility Functions for Decoded Structures -----

# ----- Decode Message and Fields Functions -----


"""
    decode_field_value(raw_value, field_def::FieldDefinition, profile_field::Dict, 
                      decoded_fields::Dict, profile::FitProfile) -> DecodedField
    
Decode a single raw field value using the profile information.
"""
function decode_field_value(raw_value, field_def::FieldDefinition, profile_field::Dict, 
                           decoded_fields::Dict, profile::FitProfile)
    
    field_name = get(profile_field, "name", "unknown_$(field_def.field_id)")
    field_type = get(profile_field, "type", "")
    units = get(profile_field, "units", nothing)
    scale = get(profile_field, "scale", [1])[1]
    offset = get(profile_field, "offset", [0])[1]
    
    # Clean invalid values first (convert invalid elements to nothing)
    cleaned_value = clean_invalid_values(raw_value, field_def.base_type)
    
    # Check if we have any valid values
    has_valid_data = has_any_valid_values(raw_value, field_def.base_type)
    
    # Count valid values for metadata
    valid_count = count_valid_values(raw_value, field_def.base_type)
    total_count = raw_value isa Vector ? length(raw_value) : 1
    
    if !has_valid_data
        return DecodedField(
            field_name, 
            nothing, 
            units, 
            raw_value, 
            field_def.field_id, 
            false, 
            Dict(
                "reason" => "no_valid_values",
                "total_elements" => total_count,
                "valid_elements" => 0
            )
        )
    end
    
    decoded_value = cleaned_value
    metadata = Dict{String, Any}(
        "total_elements" => total_count,
        "valid_elements" => valid_count
    )
    
    # Add partial validity info for vectors
    if raw_value isa Vector && valid_count < total_count
        metadata["partially_valid"] = true
        metadata["invalid_elements"] = total_count - valid_count
    end
    
    # Step 1: Handle string conversion
    if get_base_type_data_type(field_def.base_type) == String
        decoded_value = convert_string_field(cleaned_value)
    
    # Step 2: Handle enum types
    elseif field_type != "" && haskey(profile.types, field_type)
        if decoded_value isa Vector
            # Handle vector of enums, preserving nothing values
            decoded_value = [v === nothing ? nothing : lookup_enum_value(v, field_type, profile) for v in decoded_value]
        else
            decoded_value = lookup_enum_value(decoded_value, field_type, profile)
        end
        metadata["enum_type"] = field_type
    
    # Step 3: Handle subfields
    elseif haskey(profile_field, "sub_fields") && !isempty(profile_field["sub_fields"])
        decoded_value = process_subfields(cleaned_value, field_def, profile_field["sub_fields"], 
                                        decoded_fields, profile)
        metadata["has_subfields"] = true
    
    # Step 4: Handle components
    elseif haskey(profile_field, "components") && !isempty(profile_field["components"]) && 
           get(profile_field, "has_components", false)
        component_values = process_components(cleaned_value, profile_field["components"], profile)
        metadata["components"] = component_values
    end
    
    # Step 5: Apply scale and offset (for numeric values, preserving nothing)
    if (scale != 1 || offset != 0) && decoded_value !== nothing
        decoded_value = apply_scale_and_offset_safe(decoded_value, scale, offset)
        metadata["scaled"] = true
        metadata["scale"] = scale
        metadata["offset"] = offset
    end
    
    return DecodedField(
        field_name,
        decoded_value,
        units,
        raw_value,
        field_def.field_id,
        has_valid_data,
        metadata
    )
end




function decode_message(data_message::DataMessage, profile::FitProfile = PROFILE)
    global_mesg_num = data_message.definition.header.global_mesg_num
    global_mesg_num_str = string(global_mesg_num)
    
    # Get message info from profile
    message_name = get(profile.message_num_to_name, global_mesg_num, "unknown_$global_mesg_num")
    
    decoded_fields = Dict{String, DecodedField}()
    timestamp = nothing
    
    # Initialize metadata
    metadata = Dict{String, Any}(
        "decoded_at" => now(),
        "has_profile_definition" => haskey(profile.messages, global_mesg_num_str),
        "profile_version" => get(profile.version, "version", "unknown"),
        "field_count" => length(data_message.definition.field_definitions),
        "developer_field_count" => length(data_message.definition.developer_field_defs)
    )
    
    # Check if we have profile information for this message
    has_profile = haskey(profile.messages, global_mesg_num_str)
    
    if has_profile
        profile_message = profile.messages[global_mesg_num_str]
        metadata["profile_message_name"] = get(profile_message, "name", "unknown")
        profile_fields = get(profile_message, "fields", Dict())
        
        # Decode each field using profile information
        for (i, field_def) in enumerate(data_message.definition.field_definitions)
            if i <= length(data_message.raw_values)
                raw_value = data_message.raw_values[i]
                field_id_str = string(field_def.field_id)
                
                if haskey(profile_fields, field_id_str)
                    profile_field = profile_fields[field_id_str] |> Dict
                else
                    # Create minimal profile field for unknown fields
                    profile_field = Dict(
                        "name" => "field_$(field_def.field_id)",
                        "type" => "",
                        "scale" => [1],
                        "offset" => [0],
                        "units" => nothing
                    )
                end
                
                decoded_field = decode_field_value(raw_value, field_def, profile_field, 
                                                 decoded_fields, profile)
                decoded_fields[decoded_field.name] = decoded_field
                
                # Check for timestamp field
                if decoded_field.name == "timestamp" && decoded_field.is_valid && decoded_field.value !== nothing
                    # Convert FIT timestamp to DateTime
                    # FIT timestamps are seconds since Dec 31, 1989 00:00:00 UTC
                    try
                        fit_epoch = DateTime(1989, 12, 31, 0, 0, 0)
                        timestamp = fit_epoch + Second(decoded_field.value)
                    catch e
                        @warn "Failed to convert timestamp: $(decoded_field.value)" exception=e
                    end
                end
            end
        end
    else
        # Handle messages without profile information - decode as raw values
        metadata["decoding_method"] = "raw_only"
        metadata["warning"] = "No profile definition found"
        
        for (i, field_def) in enumerate(data_message.definition.field_definitions)
            if i <= length(data_message.raw_values)
                raw_value = data_message.raw_values[i]
                
                # Clean invalid values
                cleaned_value = clean_invalid_values(raw_value, field_def.base_type)
                has_valid_data = has_any_valid_values(raw_value, field_def.base_type)
                valid_count = count_valid_values(raw_value, field_def.base_type)
                total_count = raw_value isa Vector ? length(raw_value) : 1
                
                # Create basic decoded field
                field_name = "field_$(field_def.field_id)"
                
                decoded_field = DecodedField(
                    field_name,
                    has_valid_data ? cleaned_value : nothing,
                    nothing,  # no units info
                    raw_value,
                    field_def.field_id,
                    has_valid_data,
                    Dict(
                        "no_profile" => true,
                        "base_type" => field_def.base_type,
                        "total_elements" => total_count,
                        "valid_elements" => valid_count
                    )
                )
                
                decoded_fields[field_name] = decoded_field
            end
        end
    end
    
    # Handle developer fields (simplified - just store raw values)
    developer_fields = Dict{String, Any}()
    dev_field_start = length(data_message.definition.field_definitions) + 1
    
    for (i, dev_field_def) in enumerate(data_message.definition.developer_field_defs)
        idx = dev_field_start + i - 1
        if idx <= length(data_message.raw_values)
            developer_fields["dev_field_$(i)_$(dev_field_def.field_definition_number)"] = data_message.raw_values[idx]
        end
    end
    
    # Add field statistics to metadata
    valid_field_count = count(f -> f.is_valid, values(decoded_fields))
    metadata["valid_fields"] = valid_field_count
    metadata["invalid_fields"] = length(decoded_fields) - valid_field_count
    
    # Add some useful statistics
    if !isempty(decoded_fields)
        field_types = [typeof(f.value) for f in values(decoded_fields) if f.is_valid]
        metadata["field_type_summary"] = countmap(string.(field_types))
    end

    return DecodedMessage(
        message_name,
        global_mesg_num,
        decoded_fields,
        timestamp,
        developer_fields,
        data_message,
        metadata 
    )
end




"""
    decode_fit_file(filename::AbstractString) -> DecodedFitData
    
High-level function to decode an entire FIT file into structured data.
"""
function decode_fit_file(filename::AbstractString)
    fit_file = FitFile(filename)
    return decode_fit_file(fit_file)
end

function decode_fit_file(fit_file::FitFile)
    messages = Vector{DecodedMessage}()
    message_types = Dict{String, Vector{DecodedMessage}}()
    
    for message in fit_file
        if message isa DataMessage
            decoded_msg = decode_message(message)
            push!(messages, decoded_msg)
            
            # Group by message type
            if !haskey(message_types, decoded_msg.message_name)
                message_types[decoded_msg.message_name] = Vector{DecodedMessage}()
            end
            push!(message_types[decoded_msg.message_name], decoded_msg)
        end
    end
    
    # Generate metadata
    metadata = Dict{String, Any}(
        "total_messages" => length(messages),
        "message_type_counts" => Dict(name => length(msgs) for (name, msgs) in message_types),
        "decoded_at" => now()
    )
    
    return DecodedFitData(messages, message_types, metadata)
end



# =============================================================================
# Convenience Functions for Data Analysis
# =============================================================================

"""
    get_records(decoded_data::DecodedFitData, message_type::String) -> Vector{DecodedMessage}
"""
function get_records(decoded_data::DecodedFitData, message_type::String)
    get(decoded_data.message_types, message_type, DecodedMessage[])
end

"""
    extract_timeseries(decoded_data::DecodedFitData, fields::Vector{String}; 
                      message_type::String = "record") -> NamedTuple
    
Extract time-series data for specific fields from record messages.
"""
function extract_timeseries(decoded_data::DecodedFitData, fields::Vector{String}; 
                           message_type::String = "record")
    
    records = get_records(decoded_data, message_type)
    
    # Extract timestamps
    timestamps = [r.timestamp for r in records if r.timestamp !== nothing]
    
    # Extract field values
    field_data = Dict{Symbol, Vector{Any}}()
    
    for field_name in fields
        field_symbol = Symbol(field_name)
        values = []
        
        for record in records
            if record.timestamp !== nothing && haskey(record.fields, field_name)
                field = record.fields[field_name]
                push!(values, field.is_valid ? field.value : missing)
            else
                push!(values, missing)
            end
        end
        
        field_data[field_symbol] = values
    end
    
    return (timestamps = timestamps, field_data...)
end

"""
    get_session_summary(decoded_data::DecodedFitData) -> Dict{String, Any}
    
Extract summary information from session messages.
"""
function get_session_summary(decoded_data::DecodedFitData)
    sessions = get_records(decoded_data, "session")
    
    if isempty(sessions)
        return Dict{String, Any}("error" => "No session data found")
    end
    
    session = sessions[1]  # Usually only one session
    summary = Dict{String, Any}()
    
    # Extract common session fields
    for (field_name, field) in session.fields
        if field.is_valid
            summary[field_name] = field.value
        end
    end
    
    return summary
end




# Eye Candy :) 

"""
    Base.show(io::IO, field::DecodedField)
    
Pretty printing for DecodedField.
"""
function Base.show(io::IO, field::DecodedField)
    status = field.is_valid ? "✓" : "✗"
    units_str = field.units !== nothing ? " $(field.units)" : ""
    print(io, "$(field.name): $(field.value)$units_str [$status]")
end

"""
    Base.show(io::IO, message::DecodedMessage)
    
Pretty printing for DecodedMessage.
"""
function Base.show(io::IO, message::DecodedMessage)
    valid_fields = count(f -> f.is_valid, values(message.fields))
    total_fields = length(message.fields)
    timestamp_str = message.timestamp !== nothing ? " @ $(message.timestamp)" : ""
    
    println(io, "$(message.message_name) ($valid_fields/$total_fields valid fields)$timestamp_str")
    
    # Show first few fields
    field_names = collect(keys(message.fields))
    show_count = min(15, length(field_names))
    
    for i in 1:show_count
        field_name = field_names[i]
        field = message.fields[field_name]
        println(io, "  $(field)")
    end
    
    if length(field_names) > show_count
        println(io, "  ... and $(length(field_names) - show_count) more fields")
    end
end



"""
    filter_valid_fields(message::DecodedMessage) -> Dict{String, Any}
    
Extract only valid field values as a simple dictionary.
"""
function filter_valid_fields(message::DecodedMessage)
    valid_fields = Dict{String, Any}()
    
    for (name, field) in message.fields
        if field.is_valid
            valid_fields[name] = field.value
        end
    end
    
    return valid_fields
end



"""
    export_csv(decoded_data::DecodedFitData, filename::String; 
               message_type::String = "record", fields::Vector{String} = String[])
    
Export decoded data to CSV format (requires CSV.jl).
"""
function export_csv(decoded_data::DecodedFitData, filename::String; 
                    message_type::String = "record", fields::Vector{String} = String[])
    
    records = get_records(decoded_data, message_type)
    
    if isempty(records)
        @warn "No records found for message type: $message_type"
        return false
    end
    
    # Determine fields to export
    if isempty(fields)
        # Use all common fields
        all_field_names = Set{String}()
        for record in records
            union!(all_field_names, keys(record.fields))
        end
        fields = collect(all_field_names)
    end
    
    # Create data matrix
    data = []
    headers = ["timestamp"; fields]
    
    for record in records
        row = [record.timestamp]
        
        for field_name in fields
            if haskey(record.fields, field_name)
                field = record.fields[field_name]
                push!(row, field.is_valid ? field.value : missing)
            else
                push!(row, missing)
            end
        end
        
        push!(data, row)
    end
    
    # This would require CSV.jl to be loaded
    # CSV.write(filename, Tables.table(data, header=headers))
    
    @info "Would export $(length(data)) records to $filename"
    return true
end



# Macro for easy field access
"""
    @field(message, field_name)
    
Convenient macro to access field values with automatic validity checking.
Returns `missing` if field is invalid or doesn't exist.
"""
macro field(message, field_name)
    quote
        msg = $(esc(message))
        fname = string($(esc(field_name)))
        if haskey(msg.fields, fname) && msg.fields[fname].is_valid
            msg.fields[fname].value
        else
            missing
        end
    end
end