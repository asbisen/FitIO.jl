
"""
    message_type(header_byte::UInt8)::MessageType

Determine the type of message based on the provided header byte.

Returns one of: DefinitionMsg, RegularMsg, or CompressedMsg.
Throws FitDecoderError if the header byte doesn't match any known message type.
"""
function message_type(header_byte::UInt8)::MessageType
    if (header_byte & MESG_DEFINITION_MASK) != 0
        return DefinitionMsg
    elseif (header_byte & MESG_DEFINITION_MASK) == MESG_HEADER_MASK
        return RegularMsg
    elseif (header_byte & COMPRESSED_HEADER_MASK) != 0
        return CompressedMsg
    else
        errmsg = "ERROR: unknown message header type"
        throw(FitDecoderError(errmsg))
    end
end
