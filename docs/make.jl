using PicoScope
using Documenter

DocMeta.setdocmeta!(PicoScope, :DocTestSetup, :(using PicoScope); recursive=true)

makedocs(;
    modules=[PicoScope],
    authors="Jan Kuhfeld <jan.kuhfeld@rub.de> and contributors",
    sitename="PicoScope.jl",
    format=Documenter.HTML(;
        canonical="https://jqfeld.github.io/PicoScope.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jqfeld/PicoScope.jl",
    devbranch="main",
)
