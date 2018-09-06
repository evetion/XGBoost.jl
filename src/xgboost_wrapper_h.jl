include("../deps/deps.jl")

const Bst_ulong = if build_version == "master"
    Culonglong
else
    Culong
end

"Calls an xgboost API function and correctly reports errors."
macro xgboost(f, params...)
    return quote
        err = ccall(($f, _jl_libxgboost), Int64,
                    ($((esc(i.args[end]) for i in params)...),),
                    $((esc(i.args[end-1]) for i in params)...))
        if err != 0
            err_msg = unsafe_string(ccall((:XGBGetLastError, _jl_libxgboost), Cstring, ()))
            error("Call to XGBoost C function ", string($(esc(f))), " failed: ", err_msg)
        end
    end
end

function XGDMatrixCreateFromFile(fname::String, silent::Int32)
    out = Ref{Ptr{Cvoid}}()
    @xgboost(:XGDMatrixCreateFromFile,
             fname => Cstring,
             silent => Cint,
             out => Ref{Ptr{Void}})
    return out[]
end

function XGDMatrixCreateFromCSC(data::SparseMatrixCSC)
    out = Ref{Ptr{Cvoid}}()
    @xgboost(:XGDMatrixCreateFromCSC,
             convert(Vector{UInt64}, data.colptr - 1) => Ptr{Bst_ulong},
             convert(Vector{UInt32}, data.rowval - 1) => Ptr{Cuint},
             convert(Vector{Float32}, data.nzval) => Ptr{Cfloat},
             convert(UInt64, size(data.colptr)[1]) => Bst_ulong,
             convert(UInt64, nnz(data)) => Bst_ulong,
             out => Ref{Ptr{Void}})
    return out[]
end

function XGDMatrixCreateFromCSCT(data::SparseMatrixCSC)
    handle = Ref{Ptr{Cvoid}}()
    @xgboost(:XGDMatrixCreateFromCSR,
             convert(Vector{UInt64}, data.colptr - 1) => Ptr{Bst_ulong},
             convert(Vector{UInt32}, data.rowval - 1) => Ptr{Cuint},
             convert(Vector{Float32}, data.nzval) => Ptr{Cfloat},
             convert(UInt64, size(data.colptr)[1]) => Bst_ulong,
             convert(UInt64, nnz(data)) => Bst_ulong,
             handle => Ref{Ptr{Void}})
    return handle[]
end

function XGDMatrixCreateFromMat(data::Matrix{Float32}, missing::Float32)
    XGDMatrixCreateFromMatT(transpose(data), missing)
end

function XGDMatrixCreateFromMatT(data::Matrix{Float32}, missing::Float32)
    ncol, nrow = size(data)
    handle = Ref{Ptr{Cvoid}}()
    @xgboost(:XGDMatrixCreateFromMat,
             data => Ptr{Cfloat},
             nrow => Bst_ulong,
             ncol => Bst_ulong,
             missing => Cfloat,
             handle => Ref{Ptr{Void}})
    return handle[]
end

function XGDMatrixSliceDMatrix(handle::Ptr{Cvoid}, idxset::Vector{Int32}, len::UInt64)
    ret = Ref{Ptr{Cvoid}}()
    @xgboost(:XGDMatrixSliceDMatrix,
             handle => Ptr{Void},
             idxset => Ptr{Cint},
             len => Bst_ulong,
             ret => Ref{Ptr{Void}})
    return ret[]
end

function XGDMatrixFree(handle::Ptr{Cvoid})
    @xgboost(:XGDMatrixFree,
             handle => Ptr{Void})
end

function XGDMatrixSaveBinary(handle::Ptr{Cvoid}, fname::String, silent::Int32)
    @xgboost(:XGDMatrixSaveBinary,
             handle => Ptr{Void},
             fname => Cstring,
             silent => Cint)
end

function XGDMatrixSetFloatInfo(handle::Ptr{Cvoid}, field::String, array::Vector{Float32},
                               len::UInt64)
    @xgboost(:XGDMatrixSetFloatInfo,
             handle => Ptr{Void},
             field => Cstring,
             array => Ptr{Cfloat},
             len => Bst_ulong)
end

function XGDMatrixSetUIntInfo(handle::Ptr{Cvoid}, field::String, array::Vector{UInt32},
                              len::UInt64)
    @xgboost(:XGDMatrixSetUIntInfo,
             handle => Ptr{Void},
             field => Cstring,
             array => Ptr{Cuint},
             len => Bst_ulong)
end

function XGDMatrixSetGroup(handle::Ptr{Cvoid}, array::Vector{UInt32}, len::UInt64)
    @xgboost(:XGDMatrixSetGroup,
             handle => Ptr{Void},
             array => Ptr{Cuint},
             len => Bst_ulong)
end

function XGDMatrixGetFloatInfo(handle::Ptr{Cvoid}, field::String, out_len::Vector{Bst_ulong})
    out_dptr = Ref{Ptr{Cfloat}}()
    @xgboost(:XGDMatrixGetFloatInfo,
             handle => Ptr{Void},
             field => Cstring,
             out_len => Ptr{Bst_ulong},
             out_dptr =>  Ref{Ptr{Cfloat}})
    return out_dptr[]
end

function JLGetFloatInfo(handle::Ptr{Cvoid}, field::String)
    len = Bst_ulong[1]
    ptr = XGDMatrixGetFloatInfo(handle, field, len)
    return unsafe_wrap(Array, ptr, len[1])
end

function JLGetUintInfo(handle::Ptr{Cvoid}, field::String)
    len = Bst_ulong[1]
    ptr = XGDMatrixGetUIntInfo(handle, field, len)
    return unsafe_wrap(Array, ptr, len[1])
end

function XGDMatrixGetUIntInfo(handle::Ptr{Cvoid}, field::String, out_len::Vector{Bst_ulong})
    out_dptr = Ref{Ptr{Cuint}}()
    @xgboost(:XGDMatrixGetUIntInfo,
             handle => Ptr{Void},
             field => Cstring,
             out_len => Ptr{Bst_ulong},
             out_dptr => Ref{Ptr{Cuint}})
    return out_dptr[]
end

function XGDMatrixNumRow(handle::Ptr{Cvoid})
    out = Ref{Bst_ulong}()
    @xgboost(:XGDMatrixNumRow,
             handle => Ptr{Void},
             out => Ref{Bst_ulong})
    return out[]
end

function XGBoosterCreate(cachelist::Vector{Ptr{Cvoid}}, len::Int64)
    out = Ref{Ptr{Cvoid}}()
    @xgboost(:XGBoosterCreate,
             cachelist => Ptr{Ptr{Void}},
             len => Bst_ulong,
             out => Ref{Ptr{Void}})
    return out[]
end

function XGBoosterFree(handle::Ptr{Cvoid})
    @xgboost(:XGBoosterFree,
             handle => Ptr{Void})
end

function XGBoosterSetParam(handle::Ptr{Cvoid}, name::String, value::String)
    @xgboost(:XGBoosterSetParam,
             handle => Ptr{Void},
             name => Cstring,
             value => Cstring)
end

function XGBoosterUpdateOneIter(handle::Ptr{Cvoid}, iter::Int32, dtrain::Ptr{Cvoid})
    @xgboost(:XGBoosterUpdateOneIter,
             handle => Ptr{Void},
             iter => Cint,
             dtrain => Ptr{Void})
end

function XGBoosterBoostOneIter(handle::Ptr{Cvoid}, dtrain::Ptr{Cvoid}, grad::Vector{Float32},
                               hess::Vector{Float32}, len::UInt64)
    @xgboost(:XGBoosterBoostOneIter,
             handle => Ptr{Void},
             dtrain => Ptr{Void},
             grad => Ptr{Cfloat},
             hess => Ptr{Cfloat},
             len => Bst_ulong)
end

function XGBoosterEvalOneIter(handle::Ptr{Cvoid}, iter::Int32, dmats::Vector{Ptr{Cvoid}},
                              evnames::Vector{String}, len::UInt64)
    out_result = Ref{Cstring}()
    @xgboost(:XGBoosterEvalOneIter,
             handle => Ptr{Void},
             iter => Cint,
             dmats => Ptr{Ptr{Void}},
             evnames => Ptr{Cstring},
             len => Bst_ulong,
             out_result => Ref{Cstring})
    return unsafe_string(out_result[])
end

function XGBoosterPredict(handle::Ptr{Cvoid}, dmat::Ptr{Cvoid}, option_mask::Int32,
                          ntree_limit::UInt32, out_len::Vector{UInt64})
    out_result = Ref{Ptr{Float32}}()
    @xgboost(:XGBoosterPredict,
             handle => Ptr{Void},
             dmat => Ptr{Void},
             option_mask => Cint,
             ntree_limit => Cuint,
             out_len => Ptr{Bst_ulong},
             out_result => Ref{Ptr{Cfloat}})
    return out_result[]
end

function XGBoosterLoadModel(handle::Ptr{Cvoid}, fname::String)
    @xgboost(:XGBoosterLoadModel,
             handle => Ptr{Void},
             fname => Cstring)
end

function XGBoosterSaveModel(handle::Ptr{Cvoid}, fname::String)
    @xgboost(:XGBoosterSaveModel,
             handle => Ptr{Void},
             fname => Cstring)
end

function XGBoosterDumpModel(handle::Ptr{Cvoid}, fmap::String, with_stats::Int64)
    out_dump_array = Ref{Ptr{Cstring}}()
    out_len = Ref{Bst_ulong}(0)
    @xgboost(:XGBoosterDumpModel,
             handle => Ptr{Void},
             fmap => Cstring,
             with_stats => Cint,
             out_len => Ref{Bst_ulong},
             out_dump_array => Ref{Ptr{Cstring}})
    return unsafe_wrap(Array, out_dump_array[], out_len[])
end
