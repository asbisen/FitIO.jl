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

* reading raw messages without decoding

```julia
fit = FitFile("sample_fit_file.fit")
messages = [m for m in fit]
```

* reading and decoding messages

```julia
julia> decoded_data = decode_fit_file("Activity.fit")
julia> records = FitDecoder.get_records(decoded_data, "record")
julia> records[10]
record (9/9 valid fields) @ 2021-07-20T21:11:29
  1118.0 Any["m"] [✓]
  9.0 m [✓]
  1.0 Any["m/s"] [✓]
  965 semicircles [✓]
  9 rpm [✓]
  0 semicircles [✓]
  150 watts [✓]
  995749889 s [✓]
  195 bpm [✓]
```

