# Transactions
struct Transaction{T}
    type::Vector{Int}
    utility::Vector{T}
    resources::Vector{T}
    function Transaction(T::Type, m)
        return new{T}(
            zeros(Int, 1),
            zeros(T, 1),
            zeros(T, m)
        )
    end
end
Transaction(m) = Transaction(Float64, m)
tx_type(tx::Transaction) = tx.type[1]
function Base.show(io::IO, tx::Transaction{T}) where {T}
    println("TX: {type: $(tx.type[1])}")
end

# Mempool has a list of transactions
# - keeps track of which are active vs executed
# - keeps track of resources req for each (repeated info for efficiency)
mutable struct Mempool{T}
    n::Int
    txs::Vector{Transaction{T}}
    resources::Matrix{T}
    active::Vector{Bool}
    function Mempool(m, nmax, T=Float64)
        return new{T}(
            0,
            [Transaction(m) for _ in 1:nmax],
            zeros(T, m, nmax),
            zeros(Bool, nmax)
        )
    end
end
Base.length(mp::Mempool) = mp.n
len_active_txs(mp::Mempool) = count(x->x > 0, mp.active)
active_txs(mp::Mempool) = @view(mp.resources[:, mp.active]), findall(x->x>0, mp.active)
function Base.show(io::IO, mp::Mempool)
    println(
        "Mempool:" *
        "\n- length: $(length(mp))" *
        "\n- active txs: $(len_active_txs(mp))"
    )
    display(mp.txs)
end
active_tx_utilities(mp::Mempool) = [tx.utility[1] for tx in mp.txs[mp.active]]

function add_txs!(mp::Mempool{T}, txs::Vector{Transaction{T}}) where {T <: Real}
    n = length(txs)
    inds = mp.n+1 : mp.n + n
    mp.txs[inds] .= txs
    for i in 1:n
        mp.resources[:, mp.n + i] .= txs[i].resources
    end
    mp.active[inds] .= 1
    mp.n = mp.n + n
    return nothing
end

function remove_txs!(mp::Mempool, inds)
    any(mp.active[inds] .!= 1) && throw(DomainError("Not all inds are active in mempool!"))
    mp.active[inds] .= 0
    return nothing
end


# Block holds a list of executed transactions
struct Block
    txs::Vector{Int}
    function Block(txs)
        return new(txs)
    end
end
Base.length(b::Block) = length(b.txs)
Base.show(io::IO, b::Block) = show(b.txs)

# Blockchain holds of a list of blocks
mutable struct Blockchain
    block_num::Int
    history::Vector{Block}

    function Blockchain(nmax)
        return new(0, Vector{Block}(undef, nmax))
    end
end
Base.length(bc::Blockchain) = bc.block_num
function Base.show(io::IO, bc::Blockchain)
    println(
        "Blockchain with length $(length(bc))"
    )
    if bc.block_num > 10
        [(print("  "), display(block)) for block in bc.history[1:5]]
        println("⋮")
        [(print("  "), display(block)) for block in bc.history[bc.block_num-3:bc.block_num]]
    else
        [(print("  "), display(block)) for block in bc.history[1:bc.block_num]]
    end
end
Base.iterate(bc::Blockchain, state=1) = state > bc.block_num ? nothing : (bc.history[state], state+1)

function add_block!(bc::Blockchain, block::Block)
    bc.history[bc.block_num + 1] = block
    bc.block_num += 1
    return nothing
end
