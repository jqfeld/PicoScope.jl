module PicoScope

abstract type AbstractScope end
include("status.jl")
include("ps5000a.jl")

export PS5000A
end
