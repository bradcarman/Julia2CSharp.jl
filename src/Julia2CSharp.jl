module Julia2CSharp

const Parent = "Data"


struct Func
    name::Symbol
    args::Vector{Tuple{Symbol, Type}}
    ret::Union{Type,Nothing}
    async::Bool
    protect::Bool #provides the :protect option, see documentation for convert_value() function
end


function format_csharp(code::String)
    lines = split(code, '\n')

    formated = String[]
    indentlevel = 0;
    for line in lines

        code_line = split(line, "//")[1]
        if contains(code_line, '}') & !contains(code_line, '{')
            indentlevel -= 1
        end

        line = '\t'^indentlevel * strip(line)

        push!(formated, line)

        if contains(code_line, '{') & !contains(code_line, '}')
            indentlevel += 1
        end

    end


    return join(formated, '\n')
end

#TODO: What is this doing???
get_csharp_class_property(name::Symbol, ::Type{Union{Nothing, T}}) where T = get_csharp_class_property(name, T)

#TODO: setting to immutable { get; }, need to implement some way to reflect mutaded class back to Julia memory
function get_csharp_class_property(name::Symbol, ::Type{T}) where T
    
    typecode = get_csharp_class_type(T)

    #incase of parent circular reference problem, we allow a setter so the parent can be set in c#
    getset = if name == :parent
        "{ get; set; }"
    else
        "{ get { return $Parent.$name; } set { $Parent.$name = value; } }" #TODO: sort out how to truely modifiy the property and reflect back to Julia (currently this is modifiable for a couple cases like SystemData.BaseTest.isvisible)
    end
    
    code = "public $typecode $name $getset"

    return code
end

get_csharp_struct_property(name::Symbol, ::Type{Union{Nothing, T}}) where T = get_csharp_struct_property(name, T)

function get_csharp_struct_property(name::Symbol, ::Type{T}) where T
    
    typecode = get_csharp_struct_type(T)
    code = "public $typecode $name;"

    return code
end


function get_csharp_class_property_initializer(name::Symbol, type::Type) 
    
    valuecode = convert_value("$Parent.$name", type, :struct, false)

    #TODO: This code helps prevent the circular reference that occurs with the Test structure which references the Project parent.  Is there a better way to handle this???
    if string(name) == "parent"
        return "//avoiding circular reference... $name = $valuecode;"
    end


    return "$name = $valuecode;"    
end
    

function get_csharp_class_type(::Type{T}) where T 
    @show T 
    return nameof(T)
end
function get_csharp_struct_type(::Type{T}) where T
   
    if T <: Enum
        return nameof(T)
    end

    if ismutabletype(T)
        return "IntPtr"
    else
        return "$(nameof(T))Type"    
    end      

end


"""
convert_value(input::String, type::Type, input_type::Symbol)

- `input` is the c# code to be converted, for example the return value of a function, like `x`
- `type` is the Julia type which needs to be converted.  `convert_value` should specify the c# code of how to convert from the Julia type to the c# type
- `input_type` is `:struct` or `:pointer`

For example, with a custom type Test 
    `convert_value("x", Test, :struct [or :pointer])`

returns c# code
    `new Test(x)` - this works for both struct and pointer inputs


For example, with an Int
    `convert_value("structname.x", Int, :struct)`

returns c# code
    `structname.x`


"""
convert_value(input::String, type::Type, input_type::Symbol, protect=false) = convert_value(input, type, Val(input_type), protect)

function convert_value(input::String, ::Type{T}, ::Val{S}, protect) where {T,S}
    
    
        #this works if input is a pointer or structure because classes accept both!
        typecode = get_csharp_class_type(T)

        if T <: Enum
            return input
        else    
            if S == :struct
                return "new $(typecode)($input)"    
            else
                return "new $(typecode)($input, $protect)"
            end
        end

end


get_csharp_class_type(::Type{Function}) = "IntPtr"
get_csharp_struct_type(::Type{Function}) = "IntPtr"
convert_value(input::String, ::Type{Function}, ::Val, ::Bool) = input

# get_csharp_class_type(::Type{ColorSchemes.ColorScheme}) = "IntPtr"
# get_csharp_struct_type(::Type{ColorSchemes.ColorScheme}) = "IntPtr"
# convert_value(input::String, ::Type{ColorSchemes.ColorScheme}, ::Val, ::Bool) = input


# Vectors and Matrix -----------------------------------------------
get_csharp_class_type(::Type{Vector{T}}) where T = "$(get_csharp_class_type(T))[]"
get_csharp_class_type(::Type{Matrix{T}}) where T = "$(get_csharp_class_type(T))[,]"
get_csharp_struct_type(::Type{Vector{T}}) where T = "IntPtr"
get_csharp_struct_type(::Type{Matrix{T}}) where T = "IntPtr"

# for generic vectors of struct types
#input_type is always pointer 
function convert_value(input::String, ::Type{T}, ::Val, protect=false) where T <: Vector

    arraytype = T.parameters[1]
    typecode = get_csharp_class_type(arraytype)
    structtypecode = get_csharp_struct_type(arraytype)

    if ismutabletype(arraytype)
        return "Julia.MutableStruct<$typecode>($input, $protect)"
    else
        return "Julia.ImmutableStruct<$typecode>($input, Marshal.SizeOf<$structtypecode>(), $protect)"
    end

end

# Refs ---------------------------------------------------------------
get_csharp_class_type(::Type{Ref{T}}) where T = "IntPtr"
get_csharp_struct_type(::Type{Ref{T}}) where T = "IntPtr"
convert_value(input::String, ::Type{Ref{T}}, ::Val{:struct}, ::Bool) where T = input

#input_type is always pointer 
convert_value(input::String, ::Type{Vector{String}}, ::Val, ::Bool) = "Julia.GetStringVector($input)"
convert_value(input::String, ::Type{Vector{Float64}}, ::Val, ::Bool) = "Julia.GetFloat64Vector($input)"
convert_value(input::String, ::Type{Matrix{Float64}}, ::Val, ::Bool) = "Julia.GetFloat64Matrix($input)"
convert_value(input::String, ::Type{Vector{Int32}}, ::Val, ::Bool) = "Julia.GetInt32Vector($input)"
convert_value(input::String, ::Type{Vector{Int64}}, ::Val, ::Bool) = "Julia.GetInt64Vector($input)"
convert_value(input::String, ::Type{Vector{Bool}}, ::Val, ::Bool) = "Julia.GetUInt8Array($input)"
convert_value(input::String, ::Type{Vector{UInt8}}, ::Val, ::Bool) = "Julia.GetUInt8Array($input)"

# specific types ----------------------------

get_csharp_class_type(::Type{String}) = "string"
get_csharp_struct_type(::Type{String}) = "IntPtr"
convert_value(input::String, ::Type{String}, ::Val, ::Bool) = "Julia.GetString($input)"

get_csharp_class_type(::Type{Symbol}) = "string"
get_csharp_struct_type(::Type{Symbol}) = "IntPtr"
convert_value(input::String, ::Type{Symbol}, ::Val, ::Bool) = "Julia.GetString(Julia.jl_string($input))"

get_csharp_class_type(::Type{UInt8}) = "byte"
get_csharp_struct_type(::Type{UInt8}) = "byte"
convert_value(input::String, ::Type{UInt8}, ::Val{:struct}, ::Bool) = input 
convert_value(input::String, ::Type{UInt8}, ::Val{:pointer}, ::Bool) = error("not implemented yet") #TODO: How to unbox a UInt8 pointer?

get_csharp_class_type(::Type{Int64}) = "Int64"
get_csharp_struct_type(::Type{Int64}) = "Int64"
convert_value(input::String, ::Type{Int64}, ::Val{:struct}, ::Bool) = input 
convert_value(input::String, ::Type{Int64}, ::Val{:pointer}, ::Bool) = "Julia.GetInt64($input)"

get_csharp_class_type(::Type{Int32}) = "int"
get_csharp_struct_type(::Type{Int32}) = "int"
convert_value(input::String, ::Type{Int32}, ::Val{:struct}, ::Bool) = input
convert_value(input::String, ::Type{Int32}, ::Val{:pointer}, ::Bool) = "Julia.GetInt32($input)"

#Note: Julia stores boolean as byte!
get_csharp_class_type(::Type{Ref{Bool}}) = "bool"
get_csharp_class_type(::Type{Bool}) = "bool"
get_csharp_struct_type(::Type{Bool}) = "byte"
convert_value(input::String, ::Type{Ref{Bool}}, ::Val{:struct}, ::Bool) = "Julia.jl_unbox_bool($input)"
convert_value(input::String, ::Type{Bool}, ::Val{:struct}, ::Bool) = "Convert.ToBoolean($input)"
convert_value(input::String, ::Type{Bool}, ::Val{:pointer}, ::Bool) = "Julia.jl_unbox_bool($input)" 


get_csharp_class_type(::Type{Float64}) = "double"
get_csharp_struct_type(::Type{Float64}) = "double"
convert_value(input::String, ::Type{Float64}, ::Val{:struct}, ::Bool) = input
convert_value(input::String, ::Type{Float64}, ::Val{:pointer}, ::Bool) = "Julia.jl_unbox_float64($input)"


function get_csharp_class_properties(type::Type)
    names = fieldnames(type)
    types = Base.datatype_fieldtypes(type)

    class_props = String[]
    for i=1:length(names)
        push!(class_props, get_csharp_class_property(names[i], types[i]))
    end

    return join(class_props, "\n" )
end

function get_csharp_class_property_initializers(type::Type)
    names = fieldnames(type)
    types = Base.datatype_fieldtypes(type)

    class_parts = String[]
    for i=1:length(names)
        push!(class_parts, get_csharp_class_property_initializer(names[i], types[i]))
    end

    return join(class_parts, "\n" )
end



function generate_csharp_struct(type::Type)

    names = fieldnames(type)
    types = Base.datatype_fieldtypes(type)

    struct_parts = String[]
    for i=1:length(names)
        push!(struct_parts, get_csharp_struct_property(names[i], types[i]))
    end

    return join(struct_parts, "\n" )

end

function is_type_immutable(type::Type)
    if any(propertynames(type) .== :mutable)
        return !type.mutable
    else
        return false
    end
end

function is_type_fully_immutable(type::Type)    
    types = Base.datatype_fieldtypes(type)

    is_immutable = Bool[]
    for inner_type in types
        push!(is_immutable, is_type_immutable(inner_type))
    end

    return all(is_immutable) & is_type_immutable(type)
end

function generate_csharp(namespace::String, type::Type, file::String)
    code = generate_csharp(namespace, type)
    open(file, "w") do io
        write(io, code)
    end
    return code
end

function generate_csharp(namespace::String, type::Type)

    local code
    if type <: Enum
        code = string("""
        using EmbeddedJulia;
        using System;
        using System.Runtime.InteropServices;
        
        namespace $namespace
        {
            public enum $(nameof(type))  : Int32
            {
                $(join(["$(string(v)) = $(Int(v))" for v in instances(type)], ", \n"))
            }    
        }
        """)
    else
        code = string("""
        using System;
        using System.Runtime.InteropServices;
        
        namespace $namespace
        {
            public struct $(nameof(type))Type
            {
                $(generate_csharp_struct(type))
            }
    
            public partial class $(nameof(type))
            {
                IntPtr pointer = IntPtr.Zero;

                public IntPtr Pointer
                { 
                    get 
                    {
                        if (pointer == IntPtr.Zero)
                        {
                            $(get_csharp_to_pointer(type))
                            
                            Julia.gc_push(pointer);
                        }
        
                        return pointer;
                    }
                    
                }

                public $(nameof(type))Type $Parent;
                private bool IsProtected = false;

                public $(nameof(type))(IntPtr ptr, bool protect = false)
                { 
                    pointer = ptr; 
                    if (protect)
                    {
                        IsProtected=true;
                        Julia.gc_push(pointer);
                    }

                    $Parent = Marshal.PtrToStructure<$(nameof(type))Type>(ptr);
                    $(get_csharp_class_property_initializers(type))
                }
    
                $(get_csharp_class_properties(type))
    
                ~$(nameof(type))() // finalizer
                {
                    if (IsProtected & (pointer != IntPtr.Zero))
                        {
                            Console.WriteLine("Releasing $(nameof(type)) with pointer: " + pointer.ToString());
                            Julia.gc_pop(pointer);
                        }
                }
            }
        
        }
        """)
    end
    

    return format_csharp(code)

end

function generate_csharp_method_var(fun::Func)

    vars = String[]
    
    push!(vars, "IntPtr $(fun.name)_sym = Julia.jl_symbol(\"$(fun.name)\");")
    push!(vars, "IntPtr $(fun.name)_fun = Julia.jl_get_global(module, $(fun.name)_sym);")

    return join(vars, "\n")

end




# get_csharp_ret(::Type{String}) = "string"
# get_csharp_ret(type::Type) = nameof(type)

function get_csharp_args(args::Vector{Tuple{Symbol, Type}})

    argstr = String[]
    for arg in args
        push!(argstr, "$(get_csharp_class_type(arg[2])) $(arg[1])")
    end

    return join(argstr, ",")
end


# Generic get_csharp_args_to_pointer ---------------------------
# Here are a couple examples...
#BradCode.get_csharp_arg_to_pointer(i::Int, name::Symbol, ::Type{Test}) = "IntPtr arg$i = $(name).Pointer;"
#BradCode.get_csharp_arg_to_pointer(i::Int, name::Symbol, type::Type{Result}) = "IntPtr arg$i = IntPtr.Zero; Marshal.StructureToPtr<$(nameof(type))Type>($name, arg$i, true);"

#TODO: Generate for Vector of Struct (see: https://discourse.julialang.org/t/dereferencing-an-array-of-struct-pointer/51145/6)
function get_csharp_arg_to_pointer(i::Int, name::Symbol, ::Type{T}) where T

    namespace = parentmodule(T)

    type = string(T) 
    # string conversion brings in the namespace, sometimes: for example string(Shot) = "SystemData.BaseShot{SystemData.BaseTest{Project}}"
    # so we must first remove the namesapce, the add it back in so it's consistent
    type = replace(type, "$namespace."=>"")
    type = replace(type, "{"=> "{{$namespace.")
    type = replace(type, "}"=> "}}")
    type = "$namespace.$type"

    typecode = nameof(T)


    code = if T <: Enum 
        """
        IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf<$typecode>());
        Marshal.StructureToPtr($name, ptr, true);
        IntPtr arg$i = Julia.jl_eval_string(String.Format("p = Ptr{{$type}}({0}); t = unsafe_load(p); t", ptr.ToInt64()));
        """
    elseif ismutabletype(T)
        "IntPtr arg$i = $name.Pointer;"
    else
        "IntPtr arg$i = $name.Pointer;"
    end

end


#Note: ::Type{T} where T is the same as T::Type
function get_csharp_to_pointer(::Type{T}) where T
    
    namespace = parentmodule(T)

    type = string(T) 
    # string conversion brings in the namespace, sometimes: for example string(Shot) = "SystemData.BaseShot{SystemData.BaseTest{Project}}"
    # so we must first remove the namesapce, the add it back in so it's consistent
    type = replace(type, "$namespace."=>"")
    type = replace(type, "{"=> "{{$namespace.")
    type = replace(type, "}"=> "}}")
    type = "$namespace.$type"

    typecode = nameof(T)
    


    code = if T <: Enum 
        """
        IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf<$typecode>());
        Marshal.StructureToPtr($Parent, ptr, true);
        pointer = Julia.jl_eval_string(String.Format("p = Ptr{{$type}}({0}); t = unsafe_load(p); t", ptr.ToInt64()));
        """
    elseif ismutabletype(T)
        """
        IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf<$(typecode)Type>());
        Marshal.StructureToPtr($Parent, ptr, true);
        IntPtr send = Marshal.AllocHGlobal(Marshal.SizeOf<IntPtr>());
        Marshal.WriteIntPtr(send, ptr);
        pointer = Julia.jl_eval_string(String.Format("p = Ptr{{Ptr{{$type}}}}({0}); t = unsafe_load(unsafe_load(p)); t", send.ToInt64()));
        """
    else
        """
        IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf<$(typecode)Type>());
        Marshal.StructureToPtr($Parent, ptr, true);
        pointer = Julia.jl_eval_string(String.Format("p = Ptr{{$type}}({0}); t = unsafe_load(p); t", ptr.ToInt64()));
        """
    end

end


get_csharp_arg_to_pointer(i::Int, name::Symbol, ::Type{String}) = "IntPtr arg$i = Julia.jl_cstr_to_string($(name));"
get_csharp_arg_to_pointer(i::Int, name::Symbol, ::Type{Int64}) = "IntPtr arg$i = Julia.jl_box_int64($(name));"
get_csharp_arg_to_pointer(i::Int, name::Symbol, ::Type{Float64}) = "IntPtr arg$i = Julia.jl_box_float64($(name));"

function get_csharp_args_to_pointers(args::Vector{Tuple{Symbol, Type}})
    argstr = String[]
    for (i, arg) in enumerate(args)
        push!(argstr, get_csharp_arg_to_pointer(i, arg[1], arg[2]))
    end

    return join(argstr, "\n")
end

function get_csharp_argpointerlist(args::Vector{Tuple{Symbol, Type}})
    argstr = ""
    for (i, arg) in enumerate(args)
        argstr *= ", arg$i"
    end

    return argstr
end


function generate_csharp_method_fun(module_name::Symbol, fun::Func)

    if fun.async
        if !isnothing(fun.ret)

            ret  = convert_value("ret", fun.ret, :pointer, fun.protect)
            var="""public static async Task<$(get_csharp_class_type(fun.ret))> $(fun.name)($(get_csharp_args(fun.args)))
            {
                IntPtr module = Julia.jl_eval_string("$module_name");
                $(generate_csharp_method_var(fun))

                $(get_csharp_args_to_pointers(fun.args))

                IntPtr ret = await Julia.RunFunctionAsync($(fun.name)_fun $(get_csharp_argpointerlist(fun.args)));
    
                return $ret;
            }
            """
        else
            var="""public static async Task $(fun.name)($(get_csharp_args(fun.args)))
            {    
                IntPtr module = Julia.jl_eval_string("$module_name");
                $(generate_csharp_method_var(fun))

                $(get_csharp_args_to_pointers(fun.args))
    
                await Julia.RunFunctionAsync($(fun.name)_fun $(get_csharp_argpointerlist(fun.args)));
            }
            """
        end
    else    
        if !isnothing(fun.ret)
            ret  = convert_value("ret", fun.ret, :pointer, fun.protect)
            var="""public static $(get_csharp_class_type(fun.ret)) $(fun.name)($(get_csharp_args(fun.args)))
            {
                IntPtr module = Julia.jl_eval_string("$module_name");
                $(generate_csharp_method_var(fun))

                $(get_csharp_args_to_pointers(fun.args))
    
                IntPtr ret = Julia.RunFunction($(fun.name)_fun $(get_csharp_argpointerlist(fun.args)));
    
                return $ret;
            }
            """
        else
            var="""public static void $(fun.name)($(get_csharp_args(fun.args)))
            {
                IntPtr module = Julia.jl_eval_string("$module_name");
                $(generate_csharp_method_var(fun))

                $(get_csharp_args_to_pointers(fun.args))
    
                Julia.RunFunction($(fun.name)_fun $(get_csharp_argpointerlist(fun.args)));
            }
            """
        end
    end


    
end

function generate_csharp_method_parts(module_name::Symbol, funs::Vector{Func})
    vars = String[]
    for fun in funs

        var = generate_csharp_method_fun(module_name, fun)

        push!(vars, var)
    end

    return join(vars, "\n")
end

function generate_csharp_methods(namespace::String, module_name::Symbol,  funs::Vector{Func}, usings::Vector{String} = String[])

    code = string("""
    using System;
    using System.Runtime.InteropServices;
    using System.Threading.Tasks;
    $(join(["using $u;" for u in usings], '\n'))
    
    namespace $namespace
    {
   
        public static partial class Methods
        {
            
            $(generate_csharp_method_parts(module_name, funs))

        }
    
    }
    """)

    return format_csharp(code)

end

function generate_csharp_methods(namespace::String, module_name::Symbol, funs::Vector{Func}, file::String, usings::Vector{String} = String[])
    code = generate_csharp_methods(namespace, module_name, funs, usings)
    open(file, "w") do io
        write(io, code)
    end
    return code
end



end # module Julia2CSharp
