using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
using LinearAlgebra, Random, JuMP, ProgressMeter, Clp, HiGHS

# Mempool and Blockchain types; plot utilities
include("mempool.jl")
include("utils.jl")

# Solves the miner problem (9)
function packing_problem(tx_utility, tx_fees, A, b_limit; mi=false)
    _, n = size(A)

    if mi
        model = Model(HiGHS.Optimizer)
        @variable(model, x[1:n], Bin)
    else
        # Use a simplex-based solver from COIN-OR
        model = Model(Clp.Optimizer)
        @variable(model, x[1:n])
    end
    set_silent(model)
    
    # Construct the set S = {0,1}ⁿ ∩ {x | Ax ≤ b} ∩ 
    @constraint(model, 0 .<= x .<= 1)
    @constraint(model, A * x .<= b_limit)

    @objective(model, Max, sum((tx_utility[i] - tx_fees[i]) * x[i] for i in 1:n))
    optimize!(model)

    if termination_status(model) == OPTIMAL
        return model, x
    else
        error("Solve failed")
    end
end

function create_tx(; type=1)
    tx = Transaction(3)
    tx.type[1] = type
    if type == 1
        tx.resources[1] = 0.5 + 0.5*rand()
        tx.resources[2] = 0.05 + 0.05*rand()
        tx.utility[1] = 5*rand()
    elseif type == 2
        tx.resources[1] = 0.01
        tx.resources[2] = 0.5
        tx.utility[1] = 10 + 10*rand()
    else
        error("Unknown tx type")
    end
    tx.resources[3] = tx.resources[1] + 10*tx.resources[2]
    return tx
end

function create_txs(n; type=1)
    return [create_tx(; type=type) for _ in 1:n]
end

function run_sim(n, T, η, params; rseed=0, p0=zeros(3), scenario=1, mempool=nothing)
    Random.seed!(rseed)
    nmax = T*n*10
    
    # Setup problem
    m, b_target, b_limit = params
    
    isnothing(mempool) && (mempool = Mempool(m, nmax))
    chain = Blockchain(nmax)
    ystar = zeros(m)
    ps = zeros(m, T+1)
    ps[:,1] .= p0

    # run simulation
    @showprogress for block = 1:T
        p = @view ps[:, block]
        p_next = @view ps[:, block+1]

        # create new txs
        n_tx = (block == 1 && scenario in (1, 3)) ? n : n
        new_txs = create_txs(n_tx)
        if scenario in (2, 4) && block == 10
            n_tx_2 = 10n
            append!(new_txs, create_txs(n_tx_2; type=2))
        end
        add_txs!(mempool, new_txs)

        # Solve miner problem
        A, active_inds = active_txs(mempool)
        tx_utility = active_tx_utilities(mempool)
        inds = scenario > 2 ? (3:3) : (1:2)
        tx_fees = scenario > 2 ? A[inds,:]'*p[inds] : A[inds,:]'*p[inds]
        _, x = packing_problem(tx_utility, tx_fees, A[inds, :], b_limit[inds])
        
        # Find executed txs from soln (& handle approximation if using IP solver)
        x0 = value.(x)
        if !all(isapprox.(x0, 1.0, atol=1e-2) .|| isapprox.(x0, 0.0, atol=1e-2))
            @warn("Not all xᵢ ∈ {0,1}, solving with MILP solver")
            _, x = packing_problem(tx_utility, tx_fees, A[inds, :], b_limit[inds]; mi=true)
        end
        executed_tx = findall(x->isapprox(x, 1, atol=1e-3), x0)
        x0[executed_tx] .= 0.0
        x0[executed_tx] .= 1.0
        executed_inds = active_inds[executed_tx] # Map back to mempool

        # compute ∇lstar(p)
        @. ystar = b_target * max(p, zero(eltype(p)))
        # @. ystar = (p / 2 + b_target) * max(p, zero(eltype(p)))

        # Compute price update as in (12)
        ∇̃g = ystar - A*x0
        @. p_next =  p - η * ∇̃g

        # Update mempool
        remove_txs!(mempool, executed_inds)

        # Create block
        add_block!(chain, Block(executed_inds))
    end

    return chain, mempool, ps
end

n, T, η = 15, 250, 1e-2
params = (m=3, b_target=[10, 1, 10], b_limit=[50, 5, 50])

## Scenario 1: steady state
chain1, mempool1, ps1 = run_sim(n, T, η, params);
plt_price1, plt_ntx1, plt_resource1 = make_plots(chain1, mempool1, ps1, params)

## Scenario 2: distribution shift
p0 = ps1[:, end]
T2 = T
chain2, mempool2, ps2 = run_sim(n, T2, η, params; p0=p0, scenario=2, mempool=mempool1);
plt_price2, plt_ntx2, plt_resource2 = make_plots(chain2, mempool2, ps2, params; scenario=2)

## Scenario 3: only "gas"
chain3, mempool3, ps3 = run_sim(n, T, η, params; scenario=3);
plt_price3, plt_ntx3, plt_resource3 = make_plots(chain3, mempool3, ps3, params; scenario=3)

## Scenario 4: only "gas" + distribution shift
p0 = ps3[:, end]
chain4, mempool4, ps4 = run_sim(n, T2, η, params; p0=p0, scenario=4, mempool=mempool3);
plt_price4, plt_ntx4, plt_resource4 = make_plots(chain4, mempool4, ps4, params; scenario=4)


## Plots!
ntx_plt_shift = make_ntx_plot(mempool2, chain2, mempool4, chain4)
savefig(ntx_plt_shift, joinpath(@__DIR__, "figs", "ntx.pdf"))

ntx_plt_steady = make_ntx_plot(mempool1, chain1, mempool3, chain3; scenario=1)
savefig(ntx_plt_steady, joinpath(@__DIR__, "figs", "ntx-steady.pdf"))

dev_plt_r1, dev_plt_r2 = make_dev_plot(mempool1, chain1, mempool3, chain3)
savefig(dev_plt_r1, joinpath(@__DIR__, "figs", "dev-r1.pdf"))
savefig(dev_plt_r2, joinpath(@__DIR__, "figs", "dev-r2.pdf"))

savefig(plt_price1, joinpath(@__DIR__, "figs", "price1.pdf"))
savefig(plt_ntx1, joinpath(@__DIR__, "figs", "ntx1.pdf"))
savefig(plt_resource1, joinpath(@__DIR__, "figs", "resource1.pdf"))

savefig(plt_price2, joinpath(@__DIR__, "figs", "price2.pdf"))
savefig(plt_ntx2, joinpath(@__DIR__, "figs", "ntx2.pdf"))
savefig(plt_resource2, joinpath(@__DIR__, "figs", "resource2.pdf"))

savefig(plt_price3, joinpath(@__DIR__, "figs", "price3.pdf"))
savefig(plt_ntx3, joinpath(@__DIR__, "figs", "ntx3.pdf"))
savefig(plt_resource3, joinpath(@__DIR__, "figs", "resource3.pdf"))

savefig(plt_price4, joinpath(@__DIR__, "figs", "price4.pdf"))
savefig(plt_ntx4, joinpath(@__DIR__, "figs", "ntx4.pdf"))
savefig(plt_resource4, joinpath(@__DIR__, "figs", "resource4.pdf"))
