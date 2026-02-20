# FitIO.jl

Julia library for reading binary 'FIT' files produced by Garmin devices.

**Note:** This library is a work in progress and currently incomplete.

FitIO.jl provides functionality to read messages recorded in Garmin FIT files. The FIT file format is documented in the [Garmin Developer documentation](https://developer.garmin.com/fit/overview/).

## Current Features

The library currently supports:

- Reading all messages in a FIT file as either `DefinitionMessage` or `DataMessage` objects:
  - `DefinitionMessage`: Contains the structure definitions for subsequent messages
  - `DataMessage`: Contains `raw_values::Vector` (data from a record) and a reference to its `definition::DefinitionMessage`

- Access to a global `PROFILE::FitProfile` constant that describes all supported record structures, which can be used to interpret and transform `DataMessage` records

## Example

### Reading a FIT File

```julia
using FitIO
using DataFrames

# Load a FIT file
fitfile = FitFile("path/to/file.fit")
decoded_messages = DecodedFitFile(fitfile)

# show types of decoded messages
keys(decoded_messages)

# read specific message types to a DataFrame
df = decoded_messages["record"] |> to_dataframe
```
