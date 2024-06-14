using Test
using Julia2CSharp

module TestModule

struct DataObject
    current_itertion::Ref{Int}
    data::Vector{Vector{Float64}}
end
DataObject() = DataObject(Ref(0), Vector{Float64}[])


function long_process(obj::DataObject)
    for i=1:100
        obj.current_itertion[] = i
        push!(obj.data, rand(100))
        println(i)
        sleep(1)
    end
end

get_feedback_iteration(obj::DataObject) = obj.current_itertion[]
function get_feedback_data(obj::DataObject, i::Int)
    n = length(obj.data)
    if i > n
        i = n
    end
    if i < 1
        i = 1
    end
    return obj.data[i]
end

end


funs = [

    Julia2CSharp.Func(:DataObject, [], TestModule.DataObject, false, true)
    Julia2CSharp.Func(:long_process, (:obj, TestModule.DataObject))

    BradCode.Func(:get_live_feedback_error, [(:opt, Optimization)], Vector{Float64}, false, false)
    BradCode.Func(:get_live_feedback_results, [(:opt, Optimization), (:file_index, Int), (:output_variable, Int), (:iteration, Int)], Matrix{Float64}, false, false)
]

# TODO: review the current c# code, fix BradCode to implement SystemData.Methods.SendShotsVector
# TODO: IntPtr arg1 = SystemData.Methods.SendShotsVector(shots); //TODO: get this out of BradCode directly
BradCode.generate_csharp_methods("CatapultModelOptimizer", funs, raw"C:\Work\IST\Projects\CSxDT10\CSSupportTools\CatatpultModelOptimizer.jl\Methods.cs")


