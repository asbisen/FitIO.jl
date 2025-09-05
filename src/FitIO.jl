module FitIO

using JSON
using Printf
using Dates

include("const.jl")
include("profile.jl")
export FitProfile, PROFILE

include("base_types.jl")
include("crc.jl")

include("exceptions.jl")
export FitDecoderError, FitStreamError

include("stream.jl")
export FitStream

include("decoder/utils.jl")
include("decoder/header.jl")
export FitHeader

include("decoder/definition_message.jl")
export decode_definition_message!


end # module FitIO
