# Global Fit Profile

Global fit profile is extracted from the Garmin Python SDK. A json structure
is extracted from the python code. 

## Features

- Extracts profile data from `profile.py`
- Extracts base type definitions from `fit.py`
- Organizes output into a structured directory
- Supports pretty-printed JSON output

## Usage

```bash
python3 generate.py [options]
```

### Options

- `-p, --path PATH`: Path to the Garmin FIT SDK directory containing `profile.py` and `fit.py` (default: `../FitSDKRelease_21.171.00/py/garmin_fit_sdk`)
- `-o, --output OUTPUT`: Output directory name (default: `fit_data_export`)
- `--pretty`: Pretty-print the JSON output

### Examples

```bash

# Clone Python SDK
git clone https://github.com/garmin/fit-python-sdk.git

# Basic usage with default settings
python3 generate.py -p fit-python-sdk/garmin_fit_sdk --pretty

# Custom output directory with pretty printing
python3 generate.py -p fit-python-sdk/garmin_fit_sdk -o my_fit_data --pretty
```

## Output Structure

The script creates a directory containing the following JSON files:

- `profile.json` - Complete profile data from the SDK
- `base_type.json` - Base type constants (`BASE_TYPE`)
- `field_type_to_base_type.json` - Field type mappings (`FIELD_TYPE_TO_BASE_TYPE`)
- `base_type_definitions.json` - Base type definitions with size and format info (`BASE_TYPE_DEFINITIONS`)
- `numeric_field_types.json` - List of numeric field types (`NUMERIC_FIELD_TYPES`)

## Requirements

- Python 3.6+
- Access to Garmin FIT SDK files (`profile.py` and `fit.py`)