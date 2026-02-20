

"""
  decode(cfg, msg, [profile])

Decode raw FIT message by performing necessary transformations defined in `cfg`,

# Logic:

Iterate over the field definitions in the message and decode each field
  - handle messages that are not in the profile by performing limited processing 
  - handle the fields that are not in the profile by performing limited processing
  - for messages/fields in the profile, apply the appropriate decoding based on the field type and base type

# Limited Processing 
  - if message is not in profile (or field is not in profile), perform limited processing by:
    - use the global message number as the message name "unknown_msg_[global_mesg_num]"
    - for each field, use the field definition number as the field name "unknown_field_[field_def_num]"
    - process invalid values by replacing them with `nothing` using the base type definition
    - promote numeric values to a higher precision type (e.g., Int or Float64) to ensure sufficient precision
""" 
function decode(cfg::DecoderConfig, msg::FitIO.DataMessage; profile=PROFILE)
  _global_mesg_num = msg.definition.header.global_mesg_num

  # if message is defined in global profile use the name from the profile,
  # otherwise use "unknown_msg_[global_mesg_num]"
  _message_in_profile = _isinprofile(msg)
  _message_name = _message_in_profile ? 
    profile.messages[_global_mesg_num].name : 
    "unknown_msg_$_global_mesg_num"

  # Initialize a dictionary to store the decoded fields
  decoded_fields = Dict{String, FieldData}()

  # iterate over the field definitions in the message and decode each field
  for (idx, field) in enumerate(msg.definition.field_definitions)
    _field_in_profile = _isinprofile(field)
    field_profile = _field_in_profile ? 
            profile.messages[_global_mesg_num].fields[field.field_id] : 
            nothing

    # Check for sub-field mapping
    sub_field = _field_in_profile ? 
      _resolve_subfield(field, msg; profile=profile) : 
      nothing
    
    # Use sub-field properties if matched, otherwise use main field
    # Ensure unit is a single value if it's a vector of identical values
    if !isnothing(sub_field)
      _field_name = sub_field[:name]
      _field_unit = _normalize_unit(sub_field[:units]) 
      # Note: sub_field has its own scale/offset that might differ
    elseif _field_in_profile
      _field_name = field_profile[:name]
      _field_unit = _normalize_unit(field_profile[:units])
    else
      _field_name = "unknown_field_$(field.field_id)"
      _field_unit = ""
    end

    _decoded_value = msg.raw_values[idx]

    # process invalids even if message/field is not in profile, 
    # since it can be determined based on the base type definition in the profile
    if cfg.process_invalids
      _decoded_value = _process_invalid(field, _decoded_value)
    end

    # process enumerated types for the fields that are in the profile
    # and the "type" is defined in `profile[:types]`. In which case the 
    # decoded value is determined by looking up the raw value in the type 
    # definition mapping in the profile
    _decoded_value = _field_in_profile ? 
      _decode_enum(msg, field, _decoded_value; profile=profile) : 
      _decoded_value


    if cfg.apply_scale_offset && _field_in_profile
      _decoded_value = _apply_scale_offset(msg, field, _decoded_value; profile=profile)
    end


    if cfg.convert_datetime && _field_in_profile
      # convert to datetime if the field is of type "date_time" in the profile
      # and change the unit to "" to reflect the conversion to datetime
      if field_profile[:type] == "date_time"
        _decoded_value = convert_garmin_datetime(_decoded_value)
        _field_unit = ""
      end
    end


    # promote the numeric values to a higher precision type to ensure 
    # sufficient precision and proper textual representation of the decoded value
    _decoded_value = _promote(_decoded_value)

    decoded_fields[_field_name] = FieldData(_decoded_value, _field_unit)
  end

  return DecodedMessage(_message_name, decoded_fields)
end



"""
  Helper function to normalize unit values. If the unit is a vector of identical values, 
  it returns the single unique value. Otherwise, it returns the unit as is.
"""
_normalize_unit(unit::String) = unit

function _normalize_unit(unit::Vector)::String
  valid_units = filter(x -> !isempty(x) && !isnothing(x), unique(unit))
  isempty(valid_units) && return ""
  if length(valid_units) > 1
    @warn "Multiple unique units found: $valid_units. Returning the first one."
    return first(valid_units)
  end
  return only(valid_units)
end



""" 
  Process invalid values by replacing them with `nothing`. The invalid value
  is determined based on the base type definition in the profile.
"""
function _process_invalid(def::FitIO.FieldDefinition, val)
  invalid_val = FitIO.get_base_type_invalid_value(def.base_type)
  return _replace_invalid(val, invalid_val)
end

# Helper functions using dispatch instead of branching
_replace_invalid(val, invalid_val) = val == invalid_val ? nothing : val
_replace_invalid(val::Vector, invalid_val) = [_replace_invalid(v, invalid_val) for v in val]




"""
  Decode enumerated types by looking up the raw value in the type definition 
  mapping in the profile. Returns the decoded enum value if found, otherwise 
  returns the raw value unchanged.
"""
function _decode_enum(msg::FitIO.DataMessage, def::FitIO.FieldDefinition, raw_val; profile=PROFILE)
  _field_in_profile = _isinprofile(def; profile=profile)
  _global_mesg_num = msg.definition.header.global_mesg_num

  field_profile = _field_in_profile ? 
    profile.messages[_global_mesg_num].fields[def.field_id] : 
    nothing

  # Check for sub-field mapping
  sub_field = _field_in_profile ? 
    _resolve_subfield(def, msg; profile=profile) : 
    nothing

  # Determine the effective field profile to use for decoding
  # (sub_field takes precedence over main field)
  effective_field_profile = !isnothing(sub_field) ? sub_field : field_profile

  # Get field type
  field_type_sym = Symbol(effective_field_profile[:type])

  # Check if this field type has an enum mapping in the profile
  haskey(profile.types, field_type_sym) || return raw_val
  
  # Look up the raw value in the enum mapping
  type_profile = profile.types[field_type_sym]
  return get(type_profile, raw_val, raw_val)
end





"""
  Apply scale factor to numeric field values. Returns the value unchanged if:
  - Field is not in profile
  - Field is not numeric
  - Scale factor is 1
"""
function _apply_scale_offset(msg::FitIO.DataMessage, def::FitIO.FieldDefinition, val; profile=PROFILE)
  _field_in_profile = _isinprofile(def; profile=profile)
  _global_mesg_num = msg.definition.header.global_mesg_num

  field_profile = _field_in_profile ? 
    profile.messages[_global_mesg_num][:fields][def.field_id] : 
    nothing

  # Check for sub-field mapping
  sub_field = _field_in_profile ? 
    _resolve_subfield(def, msg; profile=profile) : 
    nothing

  # Determine the effective field profile to use for decoding
  # (sub_field takes precedence over main field)
  effective_field_profile = !isnothing(sub_field) ? sub_field : field_profile

  # Check if value is numeric-like (handles Nothing, Numbers, Vectors)
  !_is_numeric_value(val) && return val

  scale_val = _extract_scale_value(effective_field_profile[:scale])

  # - Scale value should not be 0
  if scale_val == 0
    errmsg = "Invalid scale value 0 for field $(def.field_id); cannot divide by zero"
    throw(FitDecoderError(errmsg))
  end

  # - If it is 1 do nothing
  scale_val == 1 && return val
  
  return _apply_scale(val, scale_val)
end

function _extract_scale_value(scale::Vector)
  vals = unique(scale)
  @assert length(vals) == 1 "Scale must have uniform values, got $vals"
  return only(vals)
end

_apply_scale(::Nothing, scale) = nothing
_apply_scale(val::Number, scale) = val / scale
_apply_scale(val::Vector, scale) = map(v -> _apply_scale(v, scale), val)

# Helper to check if a value is numeric or a vector of numerics
_is_numeric_value(::Nothing) = false
_is_numeric_value(::Number) = true
_is_numeric_value(v::Vector) = !isempty(v) && all(x -> x isa Number || isnothing(x), v)
_is_numeric_value(::Any) = false



"""
  Resolve sub-field based on mapping conditions. Returns the appropriate sub-field
  configuration if mapping conditions match, otherwise returns nothing.
"""
function _resolve_subfield(def::FitIO.FieldDefinition, msg::FitIO.DataMessage; profile::FitProfile=PROFILE)
  !_isinprofile(def; profile=profile) && return nothing
  
  field_profile = profile.messages[def.global_mesg_num][:fields][def.field_id]
  sub_fields = field_profile[:sub_fields]
  
  isempty(sub_fields) && return nothing
  
  # Check each sub-field for matching conditions
  for sub_field in sub_fields
    if _subfield_matches(sub_field, msg)
      return sub_field
    end
  end
  
  return nothing
end




"""
  Check if a sub-field's mapping conditions are satisfied.
  Compares against raw values from the message.
  
  Logic: 
  - Multiple map conditions for the SAME field use OR logic (any value matches)
  - Multiple map conditions for DIFFERENT fields use AND logic (all fields must match)
"""
function _subfield_matches(sub_field, msg::FitIO.DataMessage)
  maps = sub_field[:map]
  isempty(maps) && return false
  
  # Group map conditions by field number
  field_groups = Dict{UInt8, Vector{Any}}()
  for map_condition in maps
    field_num = map_condition[:num]
    if !haskey(field_groups, field_num)
      field_groups[field_num] = []
    end
    push!(field_groups[field_num], map_condition)
  end
  
  # For each field group, check if ANY condition matches (OR logic)
  # Between groups, ALL must match (AND logic)
  for (ref_field_num, conditions) in field_groups
    # Find the reference field in the message
    ref_field_idx = findfirst(f -> f.field_id == ref_field_num, 
                              msg.definition.field_definitions)
    
    # If reference field not present in message, this group fails
    isnothing(ref_field_idx) && return false
    
    # Get the actual raw value from the message
    actual_raw_value = msg.raw_values[ref_field_idx]
    
    # Check if ANY condition in this group matches (OR logic)
    group_matched = false
    for condition in conditions
      if actual_raw_value == condition[:raw_value]
        group_matched = true
        break
      end
    end
    
    # If no condition matched in this group, sub_field doesn't match
    !group_matched && return false
  end
  
  # All field groups matched
  return true
end



"""
  Flatten a FieldData object to a string, optionally including units.
"""
function flatten(o::FieldData; include_units::Bool=true)
  result = (include_units && !isempty(o.unit)) ? "$(o.value) $(o.unit)" : o.value
  return result
end


"""
  Convert a vector of DecodedMessage objects into a DataFrame, 
  optionally including units in the values. Ensure all messages are of
  the same type. 
"""
function to_dataframe(messages::Vector{DecodedMessage}; include_units::Bool=true)
    # Check if vector is empty
    isempty(messages) && return DataFrame()
    
    # Get all unique field names across all messages
    all_fields = Set{String}()
    for msg in messages
        union!(all_fields, keys(msg.fields))
    end
    all_fields = sort(collect(all_fields))
    
    # Collect data first
    temp_data = Dict{String, Vector{Any}}()
    for field in all_fields
        temp_data[field] = []
    end
    
    for msg in messages, field in all_fields
      value = haskey(msg, field) ? 
        flatten(msg[field]; include_units=include_units) : 
        missing
      push!(temp_data[field], value)
    end
    
    # Create and return DataFrame (DataFrame will infer types automatically)
    return DataFrame(temp_data)
end


"""
  Check if a message or field is defined in the global profile. This is used to determine
  if a message or field can be decoded using the profile.

"""
_isinprofile(global_mesg_num::Unsigned; profile::FitProfile=PROFILE)::Bool = 
  haskey(profile.messages, global_mesg_num)

function _isinprofile(global_mesg_num::Unsigned, field_id::Unsigned; profile::FitProfile=PROFILE)::Bool
  # message number must be in profile
  if _isinprofile(global_mesg_num; profile=profile) == false
    return false
  end
  # check if field_id is in the message's fields. Return (True or False)
  return haskey(profile.messages[global_mesg_num].fields, field_id)
end

function _isinprofile(msg::DataMessage; profile::FitProfile=PROFILE)::Bool
  _global_mesg_num = msg.definition.header.global_mesg_num
  return _isinprofile(_global_mesg_num; profile=profile)
end

function _isinprofile(field::FieldDefinition; profile::FitProfile=PROFILE)::Bool
  _global_mesg_num = field.global_mesg_num
  _field_id = field.field_id
  return _isinprofile(_global_mesg_num, _field_id; profile=profile)
end


"""
  Promote values to higher-precision types for numeric values, pass through others.
  This is used to ensure that numeric values are decoded with sufficient precision, especially
  when the raw value is stored in a smaller type (e.g., UInt16) but the decoded value is expected
  to be a larger type (e.g., Int or Float64).
"""
_promote(val) = val # Default: return as-is for non-promotable types

# Override: promote numeric types
_promote(val::Integer) = Int(val)
_promote(val::AbstractFloat) = Float64(val)

# Override: handle vectors recursively
_promote(val::Vector) = map(_promote, val)



"""
    convert_garmin_datetime(raw_value::Union{Number, Nothing}) -> Union{DateTime, Nothing}

Convert Garmin FIT timestamp (seconds since FIT epoch) to Julia DateTime.
"""
function convert_garmin_datetime(raw_value::Union{Number, Nothing})
    # Handle nothing/invalid values
    if raw_value === nothing
        return nothing
    end

    fit_epoch = Dates.unix2datetime(FitIO.FIT_EPOCH_OFFSET)
    return fit_epoch + Second(raw_value)
end