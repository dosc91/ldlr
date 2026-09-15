# This file is included inside LDLRBackend. Implementations here intentionally
# avoid JudiLingMeasures functions whose edge cases or indexing are unreliable.

function safe_entropy(values)
    any(ismissing, values) && return missing
    positive = Float64[x for x in values if x > 0]
    isempty(positive) && return missing
    probabilities = positive ./ sum(positive)
    -sum(probabilities .* log2.(probabilities))
end

function mse_value(x, y)
    length(x) == length(y) || throw(ArgumentError("vectors need equal length"))
    mean((Float64.(x) .- Float64.(y)).^2)
end

function cue_indices(paths, cue_names)
    lookup = Dict(name => i for (i, name) in enumerate(cue_names))
    [[lookup[cue] for cue in path] for path in paths]
end

function cue_index(value)
    value isa Integer && return Int(value)
    parsed = tryparse(Int, string(value))
    isnothing(parsed) && throw(ArgumentError("cue paths must contain column indices"))
    parsed
end

function path_total_distance(mapping, indices; direction)
    vectors = direction == "comprehension" ? mapping[indices, :] : transpose(mapping[:, indices])
    isempty(indices) && return missing
    total = sqrt(sum(abs2, vectors[1, :]))
    for i in 2:size(vectors, 1)
        total += sqrt(sum(abs2, vectors[i, :] .- vectors[i - 1, :]))
    end
    total
end

function cue_measures(direction::AbstractString, mapping::AbstractMatrix,
                      predicted::AbstractMatrix, target::AbstractMatrix,
                      paths, requested, functional_load_method::AbstractString)
    size(predicted) == size(target) || throw(ArgumentError("predicted and target matrices must match"))
    # JuliaConnectoR may translate R's numeric-looking cue indices as either
    # strings or integers, so accept both representations explicitly.
    parsed_paths = Vector{Vector{Int}}(undef, length(paths))
    for (i, path) in enumerate(paths)
        parsed_paths[i] = [cue_index(value) for value in path]
    end
    requested_names = requested isa AbstractString ? (String(requested),) : String.(collect(requested))
    result = Dict{String,Any}()
    for name in requested_names
        if name == "functional_load"
            direction == "comprehension" || throw(ArgumentError("functional_load requires a comprehension model"))
            result[name] = [[functional_load_method == "correlation" ?
                             rowcor(view(mapping, cue, :), view(predicted, i, :)) :
                             functional_load_method == "mse" ?
                             mse_value(view(mapping, cue, :), view(predicted, i, :)) :
                             throw(ArgumentError("functional_load_method must be correlation or mse"))
                             for cue in parsed_paths[i]] for i in eachindex(parsed_paths)]
        elseif name == "total_distance"
            result[name] = [path_total_distance(mapping, path; direction=direction) for path in parsed_paths]
        elseif name == "semantic_support_for_form"
            direction == "production" || throw(ArgumentError("semantic_support_for_form requires a production model"))
            result[name] = [sum(predicted[i, path]) for (i, path) in enumerate(parsed_paths)]
        elseif name == "last_support"
            direction == "production" || throw(ArgumentError("last_support requires a production model"))
            result[name] = [isempty(path) ? missing : predicted[i, last(path)] for (i, path) in enumerate(parsed_paths)]
        elseif name == "c_precision"
            direction == "production" || throw(ArgumentError("c_precision requires a production model"))
            result[name] = [rowcor(view(predicted, i, :), view(target, i, :)) for i in axes(predicted, 1)]
        else
            throw(ArgumentError("unknown cue measure: $name"))
        end
    end
    result
end

function cosine_matrix(predicted, target)
    out = Matrix{Union{Missing,Float64}}(missing, size(predicted, 1), size(target, 1))
    for i in axes(predicted, 1), j in axes(target, 1)
        x, y = view(predicted, i, :), view(target, j, :)
        denominator = sqrt(sum(abs2, x)) * sqrt(sum(abs2, y))
        out[i, j] = iszero(denominator) ? missing : dot(x, y) / denominator
    end
    out
end

function mse_matrix(predicted, target)
    [mse_value(view(predicted, i, :), view(target, j, :))
     for i in axes(predicted, 1), j in axes(target, 1)]
end

function path_to_word(indices, i2f, grams, boundary)
    JudiLing.translate(indices, i2f, grams, false, nothing, boundary, "")
end

function levenshtein(a::AbstractString, b::AbstractString)
    ac, bc = collect(a), collect(b)
    previous = collect(0:length(bc))
    for (i, ca) in enumerate(ac)
        current = Vector{Int}(undef, length(bc) + 1)
        current[1] = i
        for (j, cb) in enumerate(bc)
            current[j + 1] = min(current[j] + 1, previous[j + 1] + 1,
                                 previous[j] + (ca == cb ? 0 : 1))
        end
        previous = current
    end
    previous[end]
end

function candidate_table(res, words, cue_train, cue_obj)
    item = Int[]
    target = String[]
    candidate = Vector{Union{Missing,String}}()
    path = Vector{Union{Missing,String}}()
    support = Vector{Union{Missing,Float64}}()
    tolerance_count = Vector{Union{Missing,Int}}()
    best = Vector{Union{Missing,Bool}}()
    correct = Vector{Union{Missing,Bool}}()
    novel = Vector{Union{Missing,Bool}}()
    cue_indices_out = Vector{Union{Missing,Vector{Int}}}()
    training_paths = Set(Tuple(x) for x in cue_train.gold_ind)
    for i in eachindex(res)
        if isempty(res[i])
            push!(item, i); push!(target, words[i]); push!(candidate, missing)
            push!(path, missing); push!(support, missing); push!(tolerance_count, missing)
            push!(best, missing); push!(correct, missing); push!(novel, missing)
            push!(cue_indices_out, missing)
            continue
        end
        for (j, result) in enumerate(res[i])
            indices = Int.(result.ngrams_ind)
            predicted = path_to_word(indices, cue_obj.i2f, cue_obj.grams, cue_obj.start_end_token)
            push!(item, i); push!(target, words[i]); push!(candidate, predicted)
            push!(path, join((cue_obj.i2f[k] for k in indices), ":"))
            push!(support, result.support); push!(tolerance_count, result.num_tolerance)
            push!(best, j == 1); push!(correct, indices == cue_obj.gold_ind[i])
            push!(novel, !(Tuple(indices) in training_paths)); push!(cue_indices_out, indices)
        end
    end
    Dict("item" => item, "target" => target, "candidate" => candidate,
         "path" => path, "support" => support, "tolerance_count" => tolerance_count,
         "best" => best, "correct" => correct, "novel" => novel,
         "cue_indices" => cue_indices_out)
end

function item_and_path_measures(res, gpi, rpi, words, cue_obj, Chat)
    n = length(words)
    predicted = Vector{Union{Missing,String}}(missing, n)
    correct = Vector{Union{Missing,Bool}}(missing, n)
    scpp = Vector{Union{Missing,Float64}}(missing, n)
    path_sum = Vector{Union{Missing,Float64}}(missing, n)
    target_path_sum = Vector{Union{Missing,Float64}}(missing, n)
    path_sum_chat = Vector{Union{Missing,Float64}}(missing, n)
    within_path_entropy = Vector{Union{Missing,Float64}}(missing, n)
    mean_word_support = Vector{Union{Missing,Float64}}(missing, n)
    mean_word_support_chat = Vector{Union{Missing,Float64}}(missing, n)
    lwlr = Vector{Union{Missing,Float64}}(missing, n)
    lwlr_chat = Vector{Union{Missing,Float64}}(missing, n)
    path_count = zeros(Int, n)
    path_entropy_scp = Vector{Union{Missing,Float64}}(missing, n)
    path_entropy_chat = Vector{Union{Missing,Float64}}(missing, n)
    aldc = Vector{Union{Missing,Float64}}(missing, n)

    for i in 1:n
        path_count[i] = length(res[i])
        isempty(res[i]) && continue
        top = res[i][1]
        indices = Int.(top.ngrams_ind)
        predicted[i] = path_to_word(indices, cue_obj.i2f, cue_obj.grams, cue_obj.start_end_token)
        correct[i] = indices == cue_obj.gold_ind[i]
        scpp[i] = top.support
        chat_supports = Float64.(Chat[i, indices])
        path_sum_chat[i] = sum(chat_supports)
        mean_word_support_chat[i] = isempty(indices) ? missing : sum(chat_supports) / length(indices)
        lwlr_chat[i] = isempty(indices) || minimum(chat_supports) == 0 ? missing : length(indices) / minimum(chat_supports)
        path_entropy_scp[i] = safe_entropy([x.support for x in res[i]])
        path_entropy_chat[i] = safe_entropy([sum(Chat[i, Int.(x.ngrams_ind)]) for x in res[i]])
        aldc[i] = mean(levenshtein(words[i], path_to_word(Int.(x.ngrams_ind), cue_obj.i2f,
                                                        cue_obj.grams, cue_obj.start_end_token)) for x in res[i])
        if !isnothing(rpi)
            supports = Float64.(rpi[i].ngrams_ind_support)
            path_sum[i] = sum(supports)
            within_path_entropy[i] = safe_entropy(supports)
            mean_word_support[i] = isempty(indices) ? missing : sum(supports) / length(indices)
            lwlr[i] = isempty(indices) || minimum(supports) == 0 ? missing : length(indices) / minimum(supports)
        end
        if !isnothing(gpi)
            target_path_sum[i] = sum(gpi[i].ngrams_ind_support)
        end
    end
    items = Dict("item" => collect(1:n), "target" => words, "predicted" => predicted,
                 "correct" => correct, "support" => scpp,
                 "candidate_count" => path_count)
    measures = Dict(
        "scpp" => scpp, "path_sum" => path_sum, "target_path_sum" => target_path_sum,
        "path_sum_chat" => path_sum_chat, "within_path_entropy" => within_path_entropy,
        "mean_word_support" => mean_word_support,
        "mean_word_support_chat" => mean_word_support_chat,
        "length_weakest_link_ratio" => lwlr,
        "length_weakest_link_ratio_chat" => lwlr_chat,
        "path_count" => path_count, "path_entropy_scp" => path_entropy_scp,
        "path_entropy_chat" => path_entropy_chat,
        "average_levenshtein_distance" => aldc)
    items, measures
end

function gold_table(gpi, words)
    n = length(words)
    if isnothing(gpi)
        return Dict("item" => collect(1:n), "target" => words,
                    "path_sum" => Vector{Union{Missing,Float64}}(missing, n),
                    "weakest_support" => Vector{Union{Missing,Float64}}(missing, n))
    end
    Dict("item" => collect(1:n), "target" => words,
         "path_sum" => [sum(x.ngrams_ind_support) for x in gpi],
         "weakest_support" => [isempty(x.ngrams_ind_support) ? missing : minimum(x.ngrams_ind_support) for x in gpi])
end

"""Run JudiLing path finding and return only portable, R-friendly structures."""
function produce_word_forms(train_words::AbstractVector{<:AbstractString},
                            words::AbstractVector{<:AbstractString}, C_train::AbstractMatrix,
                            S::AbstractMatrix, F::AbstractMatrix, Chat::AbstractMatrix,
                            expected_cues::AbstractVector{<:AbstractString}, grams::Integer,
                            boundary::AbstractString, method::AbstractString,
                            max_candidates::Integer, threshold::Real, tolerant::Bool,
                            tolerance::Real, max_tolerance::Integer, neighbours::Integer,
                            verbose::Bool)
    length(words) == size(S, 1) == size(Chat, 1) || throw(ArgumentError("word and matrix row counts differ"))
    data_train = DataFrame(Word=String.(train_words))
    data = DataFrame(Word=String.(words))
    same_data = String.(train_words) == String.(words)
    if same_data
        cue_train = JudiLing.make_cue_matrix(data_train; grams=Int(grams), target_col=:Word,
                                             tokenized=false, start_end_token=String(boundary),
                                             verbose=false)
        cues = cue_train
    else
        cue_train, cues = JudiLing.make_combined_cue_matrix(
            data_train, data; grams=Int(grams), target_col=:Word, tokenized=false,
            start_end_token=String(boundary), verbose=false)
    end
    actual_cues = [cues.i2f[i] for i in 1:length(cues.i2f)]
    actual_cues == String.(expected_cues) || throw(ArgumentError("R and Julia cue columns differ"))
    size(C_train) == size(cue_train.C) || throw(ArgumentError("training cue matrix dimensions differ"))
    Shat = Matrix(cues.C) * F
    max_t = JudiLing.cal_max_timestep(data, :Word; tokenized=false)
    gpi = nothing
    rpi = nothing
    if method == "learn"
        res, gpi, rpi = JudiLing.learn_paths_rpi(
            data_train, data, cue_train.C, S, F, Chat, cue_train.A,
            cue_train.i2f, cue_train.f2i;
            gold_ind=cues.gold_ind, Shat_val=Shat, check_gold_path=true,
            max_t=max_t, max_can=Int(max_candidates), threshold=Float64(threshold),
            is_tolerant=tolerant, tolerance=Float64(tolerance),
            max_tolerance=Int(max_tolerance), grams=Int(grams), tokenized=false,
            target_col=:Word, start_end_token=String(boundary), verbose=verbose)
    elseif method == "build"
        n_neighbours = min(Int(neighbours), size(cue_train.C, 1))
        res = JudiLing.build_paths(data, cue_train.C, S, F, Chat, cue_train.A,
                                  cue_train.i2f, cue_train.gold_ind; max_t=max_t,
                                  max_can=Int(max_candidates), n_neighbors=n_neighbours,
                                  grams=Int(grams), tokenized=false, target_col=:Word,
                                  start_end_token=String(boundary), verbose=verbose)
    else
        throw(ArgumentError("method must be build or learn"))
    end
    candidates = candidate_table(res, String.(words), cue_train, cues)
    items, measures = item_and_path_measures(res, gpi, rpi, String.(words), cues, Chat)
    Dict("candidates" => candidates, "items" => items,
         "gold" => gold_table(gpi, String.(words)), "measures" => measures)
end
