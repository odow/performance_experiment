using JuMP
using JSON
using DataFrames
using BenchmarkTools
using Gurobi

function read_fixed_data()
    N = open(JSON.parse, "IJKLM/data/data_N.json")
    JKL = open(JSON.parse, "IJKLM/data/data_JKL.json")
    KLM = open(JSON.parse, "IJKLM/data/data_KLM.json")
    return N, JKL, KLM
end

function read_variable_data(n)
    I = ["i$i" for i in 1:n]
    IJK = open(JSON.parse, "IJKLM/data/data_IJK_$n.json")
    return I, IJK
end

function intuitive_jump(I, IJK, JKL, KLM, solve)
    model = Model()

    x_list = [
        (i, j, k, l, m)
        for (i, j, k) in IJK
        for (jj, kk, l) in JKL if jj == j && kk == k
        for (kkk, ll, m) in KLM if kkk == k && ll == l
    ]

    @variable(model, x[x_list] >= 0)

    @constraint(model, [i in I], sum(
        x[(i, j, k, l, m)]
        for (ii, j, k) in IJK if ii == i
        for (jj, kk, l) in JKL if jj == j && kk == k
        for (kkk, ll, m) in KLM if kkk == k && ll == l
    ) >= 0
    )

    if solve == "True"
        set_optimizer(model, Gurobi.Optimizer)
        set_silent(model)
        optimize!(model)
    end
end

function jump(I, IJK, JKL, KLM, solve)
    model = Model()

    x_list = [
        (i, j, k, l, m)
        for (i, j, k) in IJK
        for (jj, kk, l) in JKL if jj == j && kk == k
        for (kkk, ll, m) in KLM if kkk == k && ll == l
    ]

    @variable(model, x[x_list] >= 0)

    @constraint(
        model,
        [i in I],
        sum(x[k] for k in x_list if k[1] == i) >= 0
    )

    if solve == "True"
        set_optimizer(model, Gurobi.Optimizer)
        set_silent(model)
        optimize!(model)
    end
end

# standalone 
# solve = false
# samples = 2
# evals = 1
# time_limit = 5

# call from python
solve = ARGS[1]
samples = parse(Int64, ARGS[2])
evals = parse(Int64, ARGS[3])
time_limit = parse(Int64, ARGS[4])

N, JKL, KLM = read_fixed_data()

t = DataFrame(I=Int[], Language=String[], MinTime=Float64[], MeanTime=Float64[], MedianTime=Float64[])
tt = DataFrame(I=Int[], Language=String[], MinTime=Float64[], MeanTime=Float64[], MedianTime=Float64[])

for n in N
    I, IJK = read_variable_data(n)

    if maximum(t.MinTime; init=0) < time_limit
        r = @benchmark jump($I, $IJK, $JKL, $KLM, $solve) samples = samples evals = evals
        push!(t, (n, "JuMP", minimum(r.times) / 1e9, mean(r.times) / 1e9, median(r.times) / 1e9))
        println("JuMP done $n in $(round(minimum(r.times) / 1e9, digits=2))s")
    end

    if maximum(tt.MinTime; init=0) < time_limit
        rr = @benchmark intuitive_jump($I, $IJK, $JKL, $KLM, $solve) samples = samples evals = evals
        push!(tt, (n, "Intuitive JuMP", minimum(rr.times) / 1e9, mean(rr.times) / 1e9, median(rr.times) / 1e9))
        println("Intuitive JuMP done $n in $(round(minimum(rr.times) / 1e9, digits=2))s")
    end
end

if solve == "True"
    file = "IJKLM/results/jump_results_solve.json"
    file2 = "IJKLM/results/intuitive_jump_results_solve.json"
else
    file = "IJKLM/results/jump_results_model.json"
    file2 = "IJKLM/results/intuitive_jump_results_model.json"
end

open(file, "w") do f
    JSON.print(f, t, 4)
end

open(file2, "w") do f
    JSON.print(f, tt, 4)
end

println("JuMP done")