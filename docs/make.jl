using Documenter
using FitIO

makedocs(
  sitename="FitIO.jl",
  authors="Anand Bisen",

  format = Documenter.HTML(;
    prettyurls = get(ENV, "CI", "false") == "true",
    canonical  = "https://asbisen.github.io/FitIO.jl",
    edit_link  = "doc",
    assets     = String["assets/favicon.ico"],
    collapselevel = 1
  )
)

# makedocs(
#     sitename = "FitIO.jl",
#     authors  = "Anand Bisen",
#     modules  = [FitIO],

#     format = Documenter.HTML(;
#         prettyurls = get(ENV, "CI", "false") == "true",
#         canonical  = "https://asbisen.github.io/FitIO.jl",
#         edit_link  = "main",
#         assets     = String["assets/favicon.ico"],
#         collapselevel = 1,
#         highlights   = ["yaml", "julia", "julia-repl"],
#     ),

#     pages = [
#         # "Home"            => "index.md",
#         # "Tutorial"        => "tutorial.md",
#         "API Reference"   => "api.md",
#         # "Developer docs"  => "devdocs.md",
#     ],

#     # very common & useful in 2025+
#     doctest   = false,           # runs your jldoctest blocks
#     linkcheck = true,           # checks external URLs
# )


# deploydocs(
#     repo         = "github.com/asbisen/FitIO.jl.git",
#     devbranch    = "doc",      # or "main"
#     push_preview = true,       # optional: preview PRs
# )