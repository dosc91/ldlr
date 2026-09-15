module LDLRBackend

using JudiLing
using DataFrames
using LinearAlgebra
using SparseArrays
using Statistics

"""Fit an LDL mapping while keeping the R-facing API free of Julia details."""
function fit_mapping(X::AbstractMatrix, Y::AbstractMatrix, learning::AbstractString,
                     frequency::AbstractVector, epochs::Integer, eta::Real,
                     learning_sequence::AbstractVector, seed::Integer, shift::Real)
    if learning == "endstate"
        return Matrix(JudiLing.make_transform_matrix(X, Y; shift=Float64(shift)))
    elseif learning == "frequency"
        length(frequency) == size(X, 1) || throw(ArgumentError("frequency length must equal the number of rows"))
        return Matrix(JudiLing.make_transform_matrix(X, Y, frequency; shift=Float64(shift)))
    elseif learning == "incremental"
        sequence = if !isempty(learning_sequence)
            Int.(learning_sequence)
        elseif !isempty(frequency)
            JudiLing.make_learn_seq(Int.(frequency); random_seed=Int(seed))
        else
            collect(axes(X, 1))
        end
        return Matrix(JudiLing.wh_learn(X, Y; n_epochs=Int(epochs),
                      eta=Float64(eta), learn_seq=sequence, verbose=false))
    end
    throw(ArgumentError("unknown learning method: $learning"))
end

"""Prepare an exact, efficient leave-one-out ridge calculation."""
function prepare_loo(X::AbstractMatrix, Y::AbstractMatrix, shift::Real)
    size(X, 1) == size(Y, 1) || throw(ArgumentError("X and Y must have equal row counts"))
    shift > 0 || throw(ArgumentError("shift must be positive"))
    X_dense = Matrix{Float64}(X)
    Y_dense = Matrix{Float64}(Y)
    factor = cholesky(Symmetric(X_dense' * X_dense + Float64(shift) * I))
    mapping = factor \ (X_dense' * Y_dense)
    fitted = X_dense * mapping
    (X=X_dense, Y=Y_dense, factor=factor, fitted=fitted)
end

"""Fit JudiLing's additive end-state mapping with an explicit ridge shift."""
function fit_endstate(X::AbstractMatrix, Y::AbstractMatrix, shift::Real)
    size(X, 1) == size(Y, 1) || throw(ArgumentError("X and Y must have equal row counts"))
    shift > 0 || throw(ArgumentError("shift must be positive"))
    X_dense = Matrix{Float64}(X)
    factor = cholesky(Symmetric(X_dense' * X_dense + Float64(shift) * I))
    factor \ (X_dense' * Matrix{Float64}(Y))
end

"""Calculate one chunk of exact leave-one-out predictions."""
function loo_predictions_chunk(state, indices::AbstractVector{<:Integer})
    output = Matrix{Float64}(undef, length(indices), size(state.Y, 2))
    for (position, index_value) in enumerate(indices)
        index = Int(index_value)
        1 <= index <= size(state.X, 1) || throw(BoundsError(state.X, index))
        x = view(state.X, index, :)
        leverage = dot(x, state.factor \ x)
        denominator = 1.0 - leverage
        denominator > sqrt(eps(Float64)) ||
            throw(ArgumentError("leave-one-out prediction is numerically undefined at row $index"))
        output[position, :] = view(state.Y, index, :) .-
                              (view(state.Y, index, :) .- view(state.fitted, index, :)) ./ denominator
    end
    output
end

# JuliaConnectoR simplifies a length-one R integer vector to a scalar. Keep the
# public backend boundary robust when the final chunk contains exactly one row.
loo_predictions_chunk(state, index::Integer) =
    loo_predictions_chunk(state, [Int(index)])

function smoke_test()
    C = [1.0 0.0; 0.0 1.0; 1.0 1.0]
    S = [1.0 2.0; 2.0 1.0; 3.0 3.0]
    F = fit_mapping(C, S, "endstate", Float64[], 1, 0.1, Int[], 314, 0.02)
    size(F) == (2, 2) || error("unexpected mapping dimensions")
    true
end

function rowcor(x, y)
    (length(x) < 2 || iszero(std(x)) || iszero(std(y))) && return missing
    cor(x, y)
end

function similarity_matrix(predicted, target)
    out = Matrix{Union{Missing,Float64}}(missing, size(predicted, 1), size(target, 1))
    for i in axes(predicted, 1), j in axes(target, 1)
        out[i, j] = rowcor(view(predicted, i, :), view(target, j, :))
    end
    out
end

function euclidean_matrix(predicted, target)
    out = Matrix{Float64}(undef, size(predicted, 1), size(target, 1))
    for i in axes(predicted, 1), j in axes(target, 1)
        out[i, j] = sqrt(sum(abs2, view(predicted, i, :) .- view(target, j, :)))
    end
    out
end

function corrected_uncertainty(similarities)
    out = Vector{Union{Missing,Float64}}(missing, size(similarities, 1))
    for i in axes(similarities, 1)
        row = similarities[i, :]
        any(ismissing, row) && continue
        lo, hi = extrema(row)
        if hi == lo
            out[i] = 0.0
            continue
        end
        scaled = (row .- lo) ./ (hi - lo)
        order = sortperm(scaled)
        ranks = similar(order)
        for (rank, index) in enumerate(order)
            ranks[index] = rank - 1
        end
        out[i] = sum(scaled .* ranks)
    end
    out
end

"""Corrected, independently guarded matrix measures used by the R package."""
function matrix_measures(predicted::AbstractMatrix, target::AbstractMatrix,
                         requested, neighbours::Integer,
                         uncertainty_method::AbstractString="correlation")
    size(predicted, 2) == size(target, 2) || throw(ArgumentError("predicted and target vectors need equal width"))
    corrs = similarity_matrix(predicted, target)
    eucl = euclidean_matrix(predicted, target)
    result = Dict{String,Any}()
    n = clamp(Int(neighbours), 1, size(target, 1))
    requested_names = requested isa AbstractString ? (String(requested),) : String.(collect(requested))
    for name in requested_names
        if name == "l1"
            result[name] = vec(sum(abs.(predicted), dims=2))
        elseif name == "l2"
            result[name] = vec(sqrt.(sum(abs2.(predicted), dims=2)))
        elseif name == "semantic_density"
            result[name] = [any(ismissing, corrs[i, :]) ? missing :
                mean(sort(Float64.(corrs[i, :]); rev=true)[1:n]) for i in axes(corrs, 1)]
        elseif name == "average_lexical_correlation"
            result[name] = [any(ismissing, corrs[i, :]) ? missing : mean(corrs[i, :]) for i in axes(corrs, 1)]
        elseif name == "euclidean_nearest_neighbour"
            result[name] = vec(minimum(eucl, dims=2))
        elseif name == "nearest_neighbour_correlation"
            result[name] = [any(ismissing, corrs[i, :]) ? missing : maximum(corrs[i, :]) for i in axes(corrs, 1)]
        elseif name == "target_correlation"
            size(predicted, 1) == size(target, 1) || throw(ArgumentError("target correlation requires paired rows"))
            result[name] = [corrs[i, i] for i in axes(predicted, 1)]
        elseif name == "rank"
            size(predicted, 1) == size(target, 1) || throw(ArgumentError("rank requires paired rows"))
            result[name] = [ismissing(corrs[i, i]) ? missing :
                findfirst(==(corrs[i, i]), sort(collect(corrs[i, :]); rev=true)) for i in axes(predicted, 1)]
        elseif name == "recognition"
            size(predicted, 1) == size(target, 1) || throw(ArgumentError("recognition requires paired rows"))
            result[name] = [any(ismissing, corrs[i, :]) ? missing :
                argmax(corrs[i, :]) == i for i in axes(predicted, 1)]
        elseif name == "uncertainty"
            scores = uncertainty_method == "correlation" ? corrs :
                     uncertainty_method == "cosine" ? cosine_matrix(predicted, target) :
                     uncertainty_method == "mse" ? mse_matrix(predicted, target) :
                     throw(ArgumentError("uncertainty_method must be correlation, cosine, or mse"))
            result[name] = corrected_uncertainty(scores)
        else
            throw(ArgumentError("measure is not a matrix measure: $name"))
        end
    end
    result
end

include("PathMeasures.jl")

end
