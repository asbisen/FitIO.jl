# Index

## Quick Start

### Reading & Decofing FIT File

Using [FitFile](@ref FitFile) constructor raw messages from a Garmin FIT file can be
read and iterated over as explained in the example below. These are raw messages as
stored in the FIT file and are not yet decoded into user-friendly structures. The
individual message can be one of two types [DefinitionMessage](@ref) or
[DataMessage](@ref), which are the core types that users will interact with when
working with FIT files.

```julia
using FitIO

fit = FitFile("path/to/your/file.fit")

# Collect all messages into an array
messages = collect(fit)  

# Filter only data messages
data_messages = filter(msg -> msg isa DataMessage, messages)  

# Filter only definition messages
definition_messages = filter(msg -> msg isa DefinitionMessage, messages)  
```
