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