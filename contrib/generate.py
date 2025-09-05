#!/usr/bin/env python3
"""
Convert Garmin FIT SDK profile and fit data to JSON format.
This utility extracts profile information and base type definitions from the Garmin FIT SDK
and saves them to JSON files in an organized directory structure.
"""

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path


def find_module(path, module_name):
    """Attempt to find and load a module from the given path."""
    if not os.path.exists(path):
        return None

    if os.path.isdir(path):
        # Try to find the module file in the directory
        module_path = os.path.join(path, f"{module_name}.py")
        if not os.path.exists(module_path):
            return None
        path = module_path

    # Load the module from the file path
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None:
        return None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extract_fit_objects(fit_module):
    """Extract the required objects from the fit module."""
    objects = {}

    if hasattr(fit_module, 'BASE_TYPE'):
        objects['BASE_TYPE'] = fit_module.BASE_TYPE

    if hasattr(fit_module, 'FIELD_TYPE_TO_BASE_TYPE'):
        objects['FIELD_TYPE_TO_BASE_TYPE'] = fit_module.FIELD_TYPE_TO_BASE_TYPE

    if hasattr(fit_module, 'BASE_TYPE_DEFINITIONS'):
        objects['BASE_TYPE_DEFINITIONS'] = fit_module.BASE_TYPE_DEFINITIONS

    if hasattr(fit_module, 'NUMERIC_FIELD_TYPES'):
        objects['NUMERIC_FIELD_TYPES'] = fit_module.NUMERIC_FIELD_TYPES

    return objects


def write_json_file(data, output_path, pretty=False):
    """Write data to a JSON file."""
    try:
        if pretty:
            json_str = json.dumps(data, indent=2)
        else:
            json_str = json.dumps(data)

        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, "w") as fd:
            fd.write(json_str)

        return True
    except (TypeError, ValueError, IOError) as e:
        print(f"Error: Failed to write {output_path}: {e}", file=sys.stderr)
        return False


def main():
    """Main entry point for the CLI utility."""
    parser = argparse.ArgumentParser(description="Convert Garmin FIT SDK profile and fit data to JSON")
    parser.add_argument(
        "-p", "--path",
        default="../FitSDKRelease_21.171.00/py/garmin_fit_sdk",
        help="Path to the Garmin FIT SDK directory containing profile.py and fit.py"
    )
    parser.add_argument(
        "-o", "--output",
        default="fit_data_export",
        help="Output directory name"
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print the JSON output"
    )

    args = parser.parse_args()

    # Find and load the profile module
    profile_module = find_module(args.path, "profile")
    if profile_module is None:
        print(f"Error: Could not find or load profile module at {args.path}", file=sys.stderr)
        sys.exit(1)

    # Check if Profile object exists in the module
    if not hasattr(profile_module, "Profile"):
        print(f"Error: The profile module does not contain a 'Profile' object", file=sys.stderr)
        sys.exit(1)

    # Find and load the fit module
    fit_module = find_module(args.path, "fit")
    if fit_module is None:
        print(f"Error: Could not find or load fit module at {args.path}", file=sys.stderr)
        sys.exit(1)

    # Extract fit objects
    fit_objects = extract_fit_objects(fit_module)

    if not fit_objects:
        print(f"Error: Could not extract required objects from fit module", file=sys.stderr)
        sys.exit(1)

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Write profile.json
    profile_path = output_dir / "profile.json"
    if not write_json_file(profile_module.Profile, profile_path, args.pretty):
        sys.exit(1)
    print(f"Successfully wrote profile data to {profile_path}")

    # Write individual fit object files
    fit_files = {
        "base_type.json": fit_objects.get('BASE_TYPE'),
        "field_type_to_base_type.json": fit_objects.get('FIELD_TYPE_TO_BASE_TYPE'),
        "base_type_definitions.json": fit_objects.get('BASE_TYPE_DEFINITIONS'),
        "numeric_field_types.json": fit_objects.get('NUMERIC_FIELD_TYPES')
    }

    success = True
    for filename, data in fit_files.items():
        if data is not None:
            file_path = output_dir / filename
            if write_json_file(data, file_path, args.pretty):
                print(f"Successfully wrote {filename} to {file_path}")
            else:
                success = False
        else:
            print(f"Warning: Could not find data for {filename}", file=sys.stderr)

    if success:
        print(f"\nAll files successfully exported to directory: {args.output}")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
