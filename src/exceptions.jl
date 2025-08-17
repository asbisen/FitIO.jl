abstract type FitError <: Exception end

struct FitStreamError <: FitError
    message::String
    position::Union{Int,Nothing}
    FitStreamError(msg::String, pos::Union{Int,Nothing}=nothing) = new(msg, pos)
end

struct FitDecoderError <: FitError
    message::String
    position::Union{Int,Nothing}
    FitDecoderError(msg::String, pos::Union{Int,Nothing}=nothing) = new(msg, pos)
end