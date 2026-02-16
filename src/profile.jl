# FIT Profile data structure
struct FitProfile
    types::Config
    messages::Config
    common_fields::Config
    mesg_num::Config
    version::Config
end

# Load profile data (lazy loading to avoid memory issues)
const PROFILE = let
    profile_path = joinpath(@__DIR__, "msgpack", "profile.msg")
    if isfile(profile_path)
        msg_data = MsgPack.unpack(open(profile_path))
        msg = Config(msg_data)

        FitProfile(
            msg["types"],
            msg["messages"],
            msg["common_fields"],
            msg["mesg_num"],
            msg["version"],
        )
    else
        # Error out if the file profile.msg does not exists
        @error "Unable to load profile.msg."
    end
end