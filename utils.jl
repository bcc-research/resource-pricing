using Plots, LaTeXStrings

moving_average(vs,n) = [sum(@view vs[i:(i+n-1)])/n for i in 1:(length(vs)-(n-1))]

function make_plots(chain, mempool, ps, params; scenario=1, w=4)
    T = length(chain)
    inds = scenario < 3 ? (1:2) : (3:3)
    colors_plt1 = palette(:tab20, 2)
    scenario < 3 && deleteat!(colors_plt1.colors.colors, 2)
    plt1 = plot(0:T, ps'[:,inds];
        lw=1,
        linealpha=0.7,
        label=:none,
        dpi=300,
        ylabel="Price",
        xlabel="Block number",
        legend=:outerright,
        palette=colors_plt1
    )
    plot!(plt1, 0:T-w+1,hcat([moving_average(p, w) for p in eachcol(ps'[:,inds])]...);
        lw=3,
        label= scenario < 3 ? ["p₁" "p₂"] :  "p₃",
        dpi=300,
        ylabel="Price",
        xlabel="Block number",
        legend=:outerright,
        palette=colors_plt1
    )

    tx_types = [tx_type.(mempool.txs[block.txs]) for block in chain]
    n_tx1 = map(e->count(x->x==1, e), tx_types)
    lim2 = maximum(n_tx1)
    plt2 = plot(1:T, n_tx1; 
        legend=false, 
        dpi=300,
        linealpha=0.7,
        lw=1,
        ylabel="Number of tx",
        xlabel="Block number",
        label="Type 1",
        ylims=(0,ceil(lim2 / 5) * 5),
        color=:blue
    )
    plot!(plt2, w:T,moving_average(n_tx1, w);
        lw=3,
        label=:none,
        dpi=300,
        legend=:outerright,
        color=:blue
    )
    if scenario in (2, 4)
        n_tx2 = map(e->count(x->x==2, e), tx_types)
        lim2 = max(lim2, maximum(n_tx2))
        plot!(
            plt2,
            1:T,
            lw=1,
            linealpha=0.7,
            n_tx2,
            label="Type 2",
            ylims=(0,ceil(lim2 / 5) * 5),
            legend=:outerright,
            color=:red
        )
        plot!(plt2, w:T,moving_average(n_tx2, w);
            lw=3,
            label=:none,
            dpi=300,
            ylabel="Price",
            xlabel="Block number",
            legend=:outerright,
            color=:red
        )
    end

    resource_usage = hcat([vec(sum(mempool.resources[:, block.txs], dims=2)) for block in chain]...)
    y = resource_usage[1:2,:]'
    plt3 = plot(1:T, y;
        lw=2,
        label=["y₁" "y₂"],
        dpi=300,
        ylabel="Resource utilization",
        xlabel="Block number",
        yaxis=:log,
        legend=:outerright,
        # color= scenario < 3  ? [:indigo, :mediumblue]
    )
    if scenario > 0
        hline!(plt3, [params.b_target[1]], linestyle=:dash, label=L"$b^\star_1$", color=palette(:tab10)[1])
        hline!(plt3, [params.b_target[2]], linestyle=:dash, label=L"$b^\star_2$", color=palette(:tab10)[2])
        hline!(plt3, [params.b_limit[1]], linestyle=:dot, label=L"$b_1$", color=palette(:tab10)[1])
        hline!(plt3, [params.b_limit[2]], linestyle=:dot, label=L"$b_2$", color=palette(:tab10)[2])
    else
        hline!(plt3, [params.b_target[3]], linestyle=:dash, label=L"$b^\star_3$", color=palette(:tab10)[3])
        hline!(plt3, [params.b_limit[3]], linestyle=:dot, label=L"$b_3$", color=palette(:tab10)[3])
    end

    return plt1, plt2, plt3
end



function make_resource_plot(mempool2, chain2, mempool4, chain4; w=4)
    T = length(chain2)
    resource_usage2 = hcat([vec(sum(mempool2.resources[:, block.txs], dims=2)) for block in chain2]...)
    resource_usage4 = hcat([vec(sum(mempool4.resources[:, block.txs], dims=2)) for block in chain4]...)

    plt = plot(1:T, resource_usage2[1:2,:]';
        lw=2,
        label=["Multidimensional prices y₁" "Multidimensional prices y₂"],
        dpi=300,
        ylabel="Resource utilization",
        xlabel="Block number",
        yaxis=:log,
        legend=:topright,
        colors=[:indigo, :mediumblue]
    )
    plot!(plt, 1:T, resource_usage4[1:2,:]';
        lw=2,
        label=["Uniform prices y₁" "Uniform prices y₂"],
        colors=[:coral1, :firebrick]
    )

    hline!(plt, [params.b_target[1]], linestyle=:dash, label=:none, color=:orange)
    hline!(plt, [params.b_target[2]], linestyle=:dash, label=:none, color=:red)
    hline!(plt, [params.b_limit[1]], linestyle=:dot, label=:none, color=:orange)
    hline!(plt, [params.b_limit[2]], linestyle=:dot, label=:none, color=:red)
    return plt
end


function make_ntx_plot(mempool2, chain2, mempool4, chain4; w=4, scenario=0)
    T = length(chain2)
    tx_types_2 = [tx_type.(mempool2.txs[block.txs]) for block in chain2]
    tx_types_4 = [tx_type.(mempool4.txs[block.txs]) for block in chain4]
    n_tx1_2 = map(e->count(x->x==1, e), tx_types_2)
    n_tx2_2 = map(e->count(x->x==2, e), tx_types_2)
    n_tx1_4 = map(e->count(x->x==1, e), tx_types_4)
    n_tx2_4 = map(e->count(x->x==2, e), tx_types_4)
    lim2 = max(maximum(n_tx1_2), maximum(n_tx1_4))

    plt = plot(1:T, n_tx1_4; 
        dpi=300,
        ylabel="Number of tx",
        xlabel="Block number",
        ylims=(0,ceil(lim2 / 5) * 5),
        legend=:topright,
        linealpha=0.5,
        lw=1,
        color=:firebrick,
        label=:none
    )
    plot!(plt, w:T,moving_average(n_tx1_4, w);
        lw=3,
        label="Uniform Prices, Type 1",
        color=:firebrick
    )

    if scenario == 0
        plot!(
            plt,
            1:T,
            n_tx2_4,
            lw=1,
            linealpha=0.5,
            color=:coral1,
            label=:none,
        )
        plot!(plt, w:T,moving_average(n_tx2_4, w);
            lw=3,
            label="Uniform Prices, Type 2",
            color=:coral1
        )
    end

    plot!(plt, 1:T, n_tx1_2; 
        linealpha=0.5,
        lw=1,
        color=:indigo,
        label=:none,
    )
    plot!(plt, w:T, moving_average(n_tx1_2, w);
        label="Multidimensional Prices, Type 1",
        lw=3,
        color=:indigo
    )

    if scenario == 0
        plot!(
            plt,
            1:T,
            n_tx2_2,
            lw=1,
            linealpha=0.5,
            label=:none,
            color=:mediumblue
        )
        plot!(plt, w:T,moving_average(n_tx2_2, w);
            lw=3,
            label="Multidimensional Prices, Type 2",
            color=:mediumblue
        )
    end
    return plt
end

function get_resource_usage(mempool, chain)
    return hcat(
        [vec(sum(mempool.resources[:, block.txs], dims=2)) for block in chain]...
    )
end

function make_dev_plot(mempool1, chain1, mempool3, chain3; w=4)
    ru1 = get_resource_usage(mempool1, chain1)
    ru3 = get_resource_usage(mempool3, chain3)
    dev1 = ((ru1 .- params.b_target) .^ 2)[1:2,:]
    r1_multi = moving_average(dev1[1,:], w)
    r2_multi = moving_average(dev1[2,:], w)
    dev3 = ((ru3 .- params.b_target) .^ 2)[1:2,:]
    r1_single = moving_average(dev3[1,:], w)
    r2_single = moving_average(dev3[2,:], w)

    plt1 = plot(1:T, dev1[1,:]; 
            dpi=300,
            ylabel="Squared deviation from target",
            xlabel="Block number",
            legend=:topright,
            linealpha=0.5,
            lw=1,
            color=:mediumblue,
            label=:none
    )
    plot!(plt1, w:T, r1_multi;
        lw=3,
        label="Multidimensional Prices",
        color=:mediumblue
    )
    plot!(plt1, 1:T, dev3[1,:],
        lw=1,
        color=:firebrick,
        label=:none
    )
    plot!(plt1, w:T, r1_single;
        lw=3,
        label="Uniform Prices",
        color=:firebrick
    )

    plt2 = plot(1:T, dev1[2,:]; 
            dpi=300,
            ylabel="Squared deviation from target",
            xlabel="Block number",
            legend=:topright,
            linealpha=0.5,
            lw=1,
            color=:mediumblue,
            label=:none
    )
    plot!(plt2, w:T, r2_multi;
        lw=3,
        label="Multidimensional Prices",
        color=:mediumblue
    )
    plot!(plt2, 1:T, dev3[2,:],
        lw=1,
        color=:firebrick,
        label=:none
    )
    plot!(plt2, w:T, r2_single;
        lw=3,
        label="Uniform Prices",
        color=:firebrick
    )
    return plt1, plt2
end