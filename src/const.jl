#  Fit files contains three types of messages
# - Definition Message: Contains the definition of data fields
# - Regular Message: Contains data that conforms to the definition
# - Compressed Message: Contains data that is compressed to save space
@enum MessageType DefinitionMsg RegularMsg CompressedMsg

#  Endianness for FIT files
# FIT files can be in either little-endian or big-endian format.
@enum Endianness LITTLE_ENDIAN BIG_ENDIAN

#  Fit file header constants
const CRCSIZE = 2
const HEADER_WITH_CRC_SIZE = 14
const HEADER_WITHOUT_CRC_SIZE = 12

# CRC lookup table
const CRC_TABLE = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400
]

# Message Masks
const COMPRESSED_HEADER_MASK = 0x80
const MESG_DEFINITION_MASK = 0x40
const MESG_HEADER_MASK = 0x00
const LOCAL_MESG_NUM_MASK = 0x0F
const DEV_DATA_MASK = 0x20

const FIT_EPOCH_OFFSET = 631065600  # seconds from Unix epoch to Dec 31, 1989 UTC
const FIT_GPS_FACTOR = 11930465 # GPS time factor for converting FIT time to seconds

const PROFILE_PATH = joinpath(@__DIR__, "msgpack", "profile.msg")