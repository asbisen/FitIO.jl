# FIT Profile data structure
struct FitProfile
    types::Dict{String,Any}
    messages::Dict{String,Any}
    common_fields::Dict{String,Any}
    mesg_num::Dict{String,Any}
    version::Dict{String,Any}
    # Performance lookup tables
    message_num_to_name::Dict{UInt16,String}
    message_field_lookups::Dict{String,Dict{UInt8,String}}
end

# Load profile data (lazy loading to avoid memory issues)
const PROFILE = let
    profile_path = joinpath(@__DIR__, "json", "profile.json")
    if isfile(profile_path)
        json_data = JSON.parsefile(profile_path)

        # Build performance lookup tables
        message_num_to_name = Dict{UInt16,String}()
        message_field_lookups = Dict{String,Dict{UInt8,String}}()

        # Build message number to name lookup
        for (msg_num_str, msg_data) in json_data["messages"]
            # The message number is the key, and also available as msg_data["num"]
            msg_num = parse(UInt16, msg_num_str)  # Convert string key to UInt16
            if haskey(msg_data, "name")
                message_num_to_name[msg_num] = msg_data["name"]
            end
        end

        # Build field number to name lookups for each message
        for (msg_name, msg_data) in json_data["messages"]
            if haskey(msg_data, "fields") && haskey(msg_data, "name")
                field_lookup = Dict{UInt8,String}()
                for (field_num_str, field_data) in msg_data["fields"]
                    # The field number is the key, and also available as field_data["num"]
                    field_num = parse(UInt8, field_num_str)  # Convert string key to UInt8
                    if haskey(field_data, "name")
                        field_lookup[field_num] = field_data["name"]
                    end
                end
                message_field_lookups[msg_data["name"]] = field_lookup  # Use message name as key
            end
        end

        FitProfile(
            json_data["types"],
            json_data["messages"],
            json_data["common_fields"],
            json_data["mesg_num"],
            json_data["version"],
            message_num_to_name,
            message_field_lookups
        )
    else
        # Error out if the file profile.json does not exists
        @error "Unable to load profile.json."
    end
end