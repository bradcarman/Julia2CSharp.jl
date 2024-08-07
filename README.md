# How to use Julia2CSharp.jl
1. Copy Julia.cs to your C# project
2. To generate code for a struct use 

```julia
using <--Module-->: <--Struct-->
using Julia2CSharp

code = Julia2CSharp.generate_csharp("<--C# Namespace-->", <--Struct-->, "path/to/outputclass.cs"); 
```

3. To generate code for a method use `Func` to describe the function with:

- name    :: Symbol - choose a name for the function in c#
- args    :: Vector{Tuple{Symbol, Type}} - vector of tuples, each tuple has (argument name, type)
- ret     :: Union{Nothing, Type} - give the return type of the function
- async   :: Bool - run in async mode?
- protect :: Bool - protect the output from garbage collection?

Then call `generate_csharp_methods`...

```julia

funs = [
    Julia2CSharp.Func(:funciton_name, [(:pars,SystemParams)], nothing, false, false)
    Julia2CSharp.Func(:duplicate_params, [(:pars,SystemParams)], SystemParams, false, true)
    Julia2CSharp.Func(:run, [(:pars,SystemParams), (:vars, String)], Matrix{Float64}, false, false)
]

Julia2CSharp.generate_csharp_methods("<--C# Namespace-->", :<--Module-->, funs, "path/to/ouputmethods.cs")
```

See https://github.com/bradcarman/ActiveSuspensionModel for an example of Julia2CSharp applied.

# Version History
- v0.3.0: fixed `generate_csharp_methods`, now using global `usings` variable to support adding "using statements" 

- v0.2.0: c# classes are now properly initialized either by pointer or struct.  If by pointer, garbage collection is implemented first to ensure Julia cannot delete the pointer before it is marshalled to c#
