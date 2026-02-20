"""
  DecoderConfig

Config struct to control the decoding behavior in `decode` function. By
default, all transformations are enabled (i.e., `convert_datetime=true`,
`process_invalids=true`, `apply_scale_offset=true`), but users can customize
the decoding process by setting these options to `false` when creating a
`DecoderConfig` instance.

Example:
```
profile = load_global_profile()
cfg = DecoderConfig(convert_datetime=false, process_invalids=true, apply_scale_offset=false)
decoded_msg = decode(cfg, msg; profile=profile)
```
"""
struct DecoderConfig
  convert_datetime::Bool
  process_invalids::Bool
  apply_scale_offset::Bool
end

function DecoderConfig(; convert_datetime=true, process_invalids=true, apply_scale_offset=true)
  return DecoderConfig(convert_datetime, process_invalids, apply_scale_offset)
end



"""
  FieldData

Struct `FieldData` to represent the decoded field data, including the decoded value and its associated unit.
  - `value`: The decoded value of the field, which can be of any type (e.g., numeric, string, datetime).
  - `unit`: A string representing the unit of the decoded value (e.g., "seconds", "meters"). 
      This is typically derived from the profile information for the field. If the field does not 
      have an associated unit, this will be an empty string.

Usage:
```
msg.fields["timestamp"].value
msg.fields["timestamp"].unit
  ```
"""
struct FieldData{T}
  value::T
  unit::String
end



"""
  DecodedMessage

Struct `DecodedMessage` to represent the decoded FIT message, including the message name and a 
dictionary of decoded fields.
  - `name`: The name of the FIT message, derived from the profile if available, or generated 
    as "unknown_msg_[global_mesg_num]" if not in profile.
  - `fields`: A dictionary mapping field names (as strings) to their corresponding `FieldData` 
    instances, which contain the decoded value and unit for each field.

This struct also implements a dictionary-like interface for convenient access to fields by 
name, as well as pretty printing methods for easy visualization of the decoded message contents.
"""
struct DecodedMessage
  name::String
  fields::Dict{String, FieldData}
end


# Dictionary interface 
Base.getindex(msg::DecodedMessage, key::String) = msg.fields[key]
Base.keys(msg::DecodedMessage) = keys(msg.fields)
Base.values(msg::DecodedMessage) = values(msg.fields)

Base.haskey(msg::DecodedMessage, key::String) = haskey(msg.fields, key)
Base.get(msg::DecodedMessage, key::String, default) = get(msg.fields, key, default)
Base.length(msg::DecodedMessage) = length(msg.fields)
Base.iterate(msg::DecodedMessage) = iterate(msg.fields)
Base.iterate(msg::DecodedMessage, state) = iterate(msg.fields, state)
Base.in(key::String, msg::DecodedMessage) = haskey(msg.fields, key)
Base.pairs(msg::DecodedMessage) = pairs(msg.fields)
Base.collect(msg::DecodedMessage) = collect(msg.fields)

function Base.show(io::IO, msg::DecodedMessage)
    print(io, "DecodedMessage(\"$(msg.name)\", $(length(msg.fields)) fields)")
end

function Base.show(io::IO, ::MIME"text/plain", msg::DecodedMessage)
    println(io, "DecodedMessage: $(msg.name)")
    println(io, "  $(length(msg.fields)) fields:")
    for (name, data) in msg.fields
        unit_str = isempty(data.unit) ? "" : " $(data.unit)"
        println(io, "    $name: $(data.value)$unit_str")
    end
end



struct DecodedFitFile
  types::Vector{String}
  messages::Vector{DecodedMessage}
end

function DecodedFitFile(messages::Vector{DecodedMessage})
  types = unique(msg.name for msg in messages)
  return DecodedFitFile(types, messages)
end

function DecodedFitFile(fitfile::AbstractString)
  fitfile = FitFile(fitfile)
  return DecodedFitFile(fitfile)
end

function DecodedFitFile(fitfile::FitFile)
  records = [m for m in fitfile if isa(m, DataMessage)]
  profile = load_global_profile()
  cfg = DecoderConfig()
  decoded_messages = decode.(Ref(cfg), records; profile=profile)
  return DecodedFitFile(decoded_messages)
end


# Dictionary interface for DecodedFitFile
Base.getindex(file::DecodedFitFile, msg_type::String) = filter(msg -> msg.name == msg_type, file.messages)
Base.keys(file::DecodedFitFile) = file.types
Base.values(file::DecodedFitFile) = [file[msg_type] for msg_type in file.types]
Base.haskey(file::DecodedFitFile, msg_type::String) = msg_type ∈ file.types
Base.length(file::DecodedFitFile) = length(file.types)  
Base.iterate(file::DecodedFitFile) = iterate(file.types)  # Start iteration over message types
Base.iterate(file::DecodedFitFile, state) = iterate(file.types, state)  # Continue iteration over message types
Base.count(file::DecodedFitFile, msg_type::String) = length(file[msg_type])  # Count messages of a specific type

function Base.show(io::IO, file::DecodedFitFile)
  println(io, "DecodedFitFile with message types: ", join(file.types, ", "))
  for msg_type in file.types
    println(io, "  - $msg_type: ", length(file[msg_type]), " messages")
  end
end