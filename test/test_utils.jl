
# Generate a list of sample .fit files for testing
function scan_fit_files(path::String)
    files = readdir(path; join=true)
    fit_files = filter(f -> endswith(f, ".fit"), files)
    isempty(fit_files) && error("No .fit files found in the specified path: $path")
    return fit_files
end

# Get the list of .fit files from the SDK directory
# handles the case to check for the existence of the directory
function get_sdk_fit_files()
    path = ""
    if isdir("data/sdk/")
        path = "data/sdk/"
    elseif isdir("../data/sdk/")
        path = "../data/sdk/"
    else
        throw(ArgumentError("Please provide a valid path or ensure the 'data/sdk/' directory exists."))
    end
    return scan_fit_files(path)
end
