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
- args    :: Vector{Tuple{Symbol, Type}} - vector of tuples, each tuple has (argument name, argument type)
- ret     :: Union{Nothing, Type} - give the return type of the function
- async   :: Bool - run in async mode?
- protect :: Bool - protect the output from garbage collection?

Then call `generate_csharp_methods`...

```julia

funs = [
    Julia2CSharp.Func(:funciton_name, [(:argument_name, ArgumentType)], nothing, false, false)    
]

Julia2CSharp.generate_csharp_methods("<--C# Namespace-->", :<--Module-->, funs, "path/to/ouputmethods.cs")
```

Note, if the `ArgumentType` is not a standard type then it needs to be defined.  For example, let's say the c# for MyType is definied using 

```julia
Julia2CSharp.generate_csharp("MyNamespace", Mytype, "path/to/mytype.cs")
```

However, the argument type to a function is a `Vector{MyType}`, in this case the following can be done.  First, define the following in c#

```c#
public static IntPtr SendMyTypeVector(MyType[] x)
{
    try
    {
        
        int n = x.Length;
        IntPtr hdata = Marshal.AllocHGlobal(IntPtr.Size * n);
        for (int i = 0; i < n; i++)
        {
            IntPtr ptr = new IntPtr(hdata.ToInt64() + IntPtr.Size * i);

            IntPtr shot = x[i].Pointer;

            Marshal.WriteIntPtr(ptr, shot);

        }

        return Julia.MakeArray1D(MyType, hdata, n);

    }
    catch (Exception) { throw; }

}
```

Then in Julia, define the following method:

```julia
Julia2CSharp.get_csharp_pointer(name::Symbol, ::Type{T}) where T <: Vector{MyType} = "SendMyTypeVector($name)"
```

Now when generating code for the following function `Julia2CSharp.Func(:funciton_name, [(:arg1, Vector{MyType})], nothing, false, false)` the input type will be handled correctly.


See https://github.com/bradcarman/ActiveSuspensionModel for an example of Julia2CSharp applied.

# Version History
- v0.4.0: improved `get_csharp_arg_to_pointer` so that `get_csharp_pointer` can be used to provide the proper definition

- v0.3.0: fixed `generate_csharp_methods`, now using global `usings` variable to support adding "using statements" 

- v0.2.0: c# classes are now properly initialized either by pointer or struct.  If by pointer, garbage collection is implemented first to ensure Julia cannot delete the pointer before it is marshalled to c#
