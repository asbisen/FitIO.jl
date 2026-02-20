module FitIO

using Printf
using Dates

import EasyConfig: Config
using MsgPack

include("const.jl")
include("profile.jl")
export FitProfile, PROFILE

include("base_types.jl")
include("crc.jl")

include("exceptions.jl")
export FitDecoderError, FitStreamError

include("stream.jl")
export FitStream

include("parser/utils.jl")
include("parser/header.jl")
export FitHeader

include("parser/definition_message.jl")
export decode_definition_message!, DefinitionMessage

include("parser/data_message.jl")
export decode_data_message!, DataMessage

include("iterator.jl")
export FitFile

include("api/decoder.jl")
export load_global_profile,
       DecodedFitFile,
       DecoderConfig,
       FieldData


end # module FitIO
