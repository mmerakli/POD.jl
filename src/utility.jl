"""
    update_rel_gap(m::PODNonlinearModel)

Update POD model relative & absolute optimality gap.

The relative gap calculation is

```math
    \\textbf{Gap} = \\frac{|UB-LB|}{ϵ+|UB|}
```

The absolute gap calculation is
```
    |UB-LB|
```
"""
function update_opt_gap(m::PODNonlinearModel)

    if m.best_obj in [Inf, -Inf]
        m.best_rel_gap = Inf
        return
    else
        p = round(abs(log(10,m.relgap)))
        n = round(abs(m.best_obj-m.best_bound), Int(p))
        dn = round(abs(1e-12+abs(m.best_obj)), Int(p))
        if (n == 0.0) && (dn == 0.0)
            m.best_rel_gap = 0.0
            return
        end
        m.best_rel_gap = abs(m.best_obj - m.best_bound)/(m.tol+abs(m.best_obj))
    end

    # absoluate or any other bound calculation shows here..
    return
end

"""
    discretization_to_bounds(d::Dict, l::Int)

Same as [`update_var_bounds`](@ref)
"""
discretization_to_bounds(d::Dict, l::Int) = update_var_bounds(d, len=l)


"""
    Utility function for debugging.
"""
function show_solution(m::JuMP.Model)
    for i in 1:length(m.colNames)
        println("$(m.colNames[i])=$(m.colVal[i])")
    end
    return
end


"""
    Tell what would be the variable type of a lifted term.
    This function is with limited functionality
    @docstring TODO
"""
function resolve_lifted_var_type(var_types::Vector{Symbol}, operator::Symbol)

    if operator == :+
        detector = [i in [:Bin, :Int] ? true : false for i in var_types]
        if length(detector) == 1 && detector[1] # Special case
            if :Bin in var_types
                return :Bin
            else
                return :Int
            end
        end
        prod(detector) && return :Int
        # o/w continous variables
    elseif operator == :*
        detector = [i == :Bin ? true : false for i in var_types]
        prod(detector) && return :Bin
        detector = [i in [:Bin, :Int] ? true : false for i in var_types]
        prod(detector) && return :Int
        # o/w continous variables
    end

    return :Cont
end

"""
    init_disc(m::PODNonlinearModel)

This function initialize the dynamic discretization used for any bounding models. By default, it takes (.l_var_orig, .u_var_orig) as the base information. User is allowed to use alternative bounds for initializing the discretization dictionary.
The output is a dictionary with MathProgBase variable indices keys attached to the :PODNonlinearModel.discretization.
"""
function init_disc(m::PODNonlinearModel)

    for var in 1:(m.num_var_orig+m.num_var_linear_mip+m.num_var_nonlinear_mip)
        if m.var_type[var] in [:Bin, :Cont]
            lb = m.l_var_tight[var]
            ub = m.u_var_tight[var]
            m.discretization[var] = [lb, ub]
        elseif m.var_type[var] in [:Int]
            m.int_enable ? lb = floor(m.l_var_tight[var]) - 0.5 : lb = floor(m.l_var_tight[var])
            m.int_enable ? ub = ceil(m.u_var_tight[var]) + 0.5 : ub = floor(m.u_var_tight[var])
            m.discretization[var] = [lb, ub]
        else
            error("[EXCEPTION] Unexpected variable type when initializing discretization dictionary.")
        end
    end

    return
end

"""

    to_discretization(m::PODNonlinearModel, lbs::Vector{Float64}, ubs::Vector{Float64})

Utility functions to convert bounds vectors to Dictionary based structures that is more suitable for
partition operations.

"""
function to_discretization(m::PODNonlinearModel, lbs::Vector{Float64}, ubs::Vector{Float64})

    @assert length(lbs) == length(ubs)
    var_discretization = Dict()
    for var in 1:m.num_var_orig
        lb = lbs[var]
        ub = ubs[var]
        var_discretization[var] = [lb, ub]
    end

    total_var_cnt = m.num_var_orig+m.num_var_linear_mip+m.num_var_nonlinear_mip
    orig_var_cnt = m.num_var_orig
    if length(lbs) == total_var_cnt
        for var in (1+orig_var_cnt):total_var_cnt
            lb = lbs[var]
            ub = ubs[var]
            var_discretization[var] = [lb, ub]
        end
    else
        for var in (1+orig_var_cnt):total_var_cnt
            lb = -Inf
            ub = Inf
            var_discretization[var] = [lb, ub]
        end
    end

    return var_discretization
end

"""
    flatten_discretization(discretization::Dict)

Utility functions to eliminate all partition on discretizing variable and keep the loose bounds.

"""
function flatten_discretization(discretization::Dict; kwargs...)

    flatten_discretization = Dict()
    for var in keys(discretization)
        flatten_discretization[var] = [discretization[var][1],discretization[var][end]]
    end

    return flatten_discretization
end

"""
    @docstring
"""
function insert_timeleft_symbol(options, val::Float64, keywords::Symbol, timeout; options_string_type=1)

    for i in 1:length(options)
        if options_string_type == 1
            if keywords in collect(options[i])
                deleteat!(options, i)
            end
        elseif options_string_type == 2
            if keywords == split(options[i],"=")[1]
                deleteat!(options, i)
            end
        end
    end

    if options_string_type == 1
        (val != Inf) && push!(options, (keywords, val))
    elseif options_string_type == 2
        (val != Inf) && push!(options, "$(keywords)=$(val)")
    end

    return
end

"""
    fetch_boundstop_symbol(m::PODNonlinearModel)

An utility function used to recongize different sub-solvers and return the bound stop option key words
"""
function update_boundstop_options(m::PODNonlinearModel)

    if m.mip_solver_id == "Gurobi"
        # Calculation of the bound
        if m.sense_orig == :Min
            stopbound = (1-m.relgap+m.tol) * m.best_obj
        elseif m.sense_orig == :Max
            stopbound = (1+m.relgap-m.tol) * m.best_obj
        end

        for i in 1:length(m.mip_solver.options)
            if m.mip_solver.options[i][1] == :BestBdStop
                deleteat!(m.mip_solver.options, i)
                if m.mip_solver_id == "Gurobi"
                    push!(m.mip_solver.options, (:BestBdStop, stopbound))
                else
                    return
                end
            end
        end
    end

    return
end


"""
    check_solution_history(m::PODNonlinearModel, ind::Int)

Check if the solution is alwasy the same within the last disc_consecutive_forbid iterations. Return true if suolution in invariant.
"""
function check_solution_history(m::PODNonlinearModel, ind::Int)

    (m.logs[:n_iter] < m.disc_consecutive_forbid) && return false

    sol_val = m.bound_sol_history[mod(m.logs[:n_iter]-1, m.disc_consecutive_forbid)+1][ind]
    for i in 1:(m.disc_consecutive_forbid-1)
        search_pos = mod(m.logs[:n_iter]-1-i, m.disc_consecutive_forbid)+1
        !isapprox(sol_val, m.bound_sol_history[search_pos][ind]; atol=m.disc_rel_width_tol) && return false
    end
    return true
end

"""

    fix_domains(m::PODNonlinearModel)

This function is used to fix variables to certain domains during the local solve process in the [`global_solve`](@ref).
More specifically, it is used in [`local_solve`](@ref) to fix binary and integer variables to lower bound solutions
and discretizing varibles to the active domain according to lower bound solution.
"""
function fix_domains(m::PODNonlinearModel;discrete_sol=nothing)

    discrete_sol != nothing && @assert length(discrete_sol) >= m.num_var_orig

    l_var = copy(m.l_var_orig)
    u_var = copy(m.u_var_orig)

    for i in 1:m.num_var_orig
        if i in m.disc_vars && m.var_type[i] == :Cont
            discrete_sol == nothing ? point = m.best_bound_sol[i] : point = discrete_sol[i]
            PCnt = length(m.discretization[i]) - 1
            for j in 1:PCnt
                if point >= (m.discretization[i][j] - m.tol) && (point <= m.discretization[i][j+1] + m.tol)
                    @assert j < length(m.discretization[i])
                    l_var[i] = m.discretization[i][j]
                    u_var[i] = m.discretization[i][j+1]
                    break
                end
            end
        elseif m.var_type[i] == :Bin || m.var_type[i] == :Int
            if discrete_sol == nothing
                l_var[i] = round(m.best_bound_sol[i])
                u_var[i] = round(m.best_bound_sol[i])
            else
                l_var[i] = discrete_sol[i]
                u_var[i] = discrete_sol[i]
            end
        end
    end

    return l_var, u_var
end

"""
    is_fully_convexified(m::PODNonlinearModel)
"""
function is_fully_convexified(m::PODNonlinearModel)

    # Other more advanced convexification check goes here
    for term in keys(m.nonconvex_terms)
        if !m.nonconvex_terms[term][:convexified]
            warn("Detected terms that is not convexified $(term[:lifted_constr_ref]), bounding model solver may report a error due to this")
            return
        else
            m.nonconvex_terms[term][:convexified] = false    # Reset status for next iteration
        end
    end

    return
end

"""
    pick_disc_vars(m::PODNonlinearModel)

This function helps pick the variables for discretization. The method chosen depends on user-inputs.
In case when `indices::Int` is provided, the method is chosen as built-in method. Currently,
there exist two built-in method:

    * `max-cover(m.disc_var_pick=0, default)`: pick all variables involved in the non-linear term for discretization
    * `min-vertex-cover(m.disc_var_pick=1)`: pick a minimum vertex cover for variables involved in non-linear terms so that each non-linear term is at least convexified

For advance usage, `m.disc_var_pick` allows `::Function` inputs. User is required to perform flexible methods in choosing the non-linear variable.
For more information, read more details at [Hacking Solver](@ref).

"""
function pick_disc_vars(m::PODNonlinearModel)

    if isa(m.disc_var_pick, Function)
        eval(m.disc_var_pick)(m)
        (length(m.disc_vars) == 0 && length(m.nonconvex_terms) > 0) && error("[USER FUNCTION] must select at least one variable to perform discretization for convexificiation purpose")
    elseif isa(m.disc_var_pick, Int) || isa(m.disc_var_pick, String)
        if m.disc_var_pick == 0
            select_all_nlvar(m)
        elseif m.disc_var_pick == 1
            min_vertex_cover(m)
        elseif m.disc_var_pick == 2
            (length(m.candidate_disc_vars) > 15) ? min_vertex_cover(m) : select_all_nlvar(m)
        elseif m.disc_var_pick == 3 # Initial
            (length(m.candidate_disc_vars) > 15) ? min_vertex_cover(m) : select_all_nlvar(m)
        else
            error("Unsupported default indicator for picking variables for discretization")
        end
    else
        error("Input for parameter :disc_var_pick is illegal. Should be either a Int for default methods indexes or functional inputs.")
    end

    return
end

"""

    select_all_nlvar(m:PODNonlinearModel)

A built-in method for selecting variables for discretization. It selects all variables in the nonlinear terms.

"""
function select_all_nlvar(m::PODNonlinearModel)

    m.num_var_disc_mip = length(m.candidate_disc_vars)
    m.disc_vars = copy(m.candidate_disc_vars)

    return
end

"""
    Special funtion for debugging bounding models
"""
function print_iis_gurobi(m::JuMP.Model)

    grb = MathProgBase.getrawsolver(internalmodel(m))
    Gurobi.computeIIS(grb)
    numconstr = Gurobi.num_constrs(grb)
    numvar = Gurobi.num_vars(grb)

    iisconstr = Gurobi.get_intattrarray(grb, "IISConstr", 1, numconstr)
    iislb = Gurobi.get_intattrarray(grb, "IISLB", 1, numvar)
    iisub = Gurobi.get_intattrarray(grb, "IISUB", 1, numvar)

    info("Irreducible Inconsistent Subsystem (IIS)")
    info("Variable bounds:")
    for i in 1:numvar
        v = Variable(m, i)
        if iislb[i] != 0 && iisub[i] != 0
            println(getlowerbound(v), " <= ", getname(v), " <= ", getupperbound(v))
        elseif iislb[i] != 0
            println(getname(v), " >= ", getlowerbound(v))
        elseif iisub[i] != 0
            println(getname(v), " <= ", getupperbound(v))
        end
    end

    info("Constraints:")
    for i in 1:numconstr
        if iisconstr[i] != 0
            println(m.linconstr[i])
        end
    end

    return
end

function build_discvar_graph(m::PODNonlinearModel)

    # Collect the information of nonlinear terms in terms of arcs and nodes
    nodes = Set()
    arcs = Set()

    # Collect variables in nonconvex terms
    for k in keys(m.nonconvex_terms)
        m.nonconvex_terms[k][:discvar_collector](m, k, var_bowl=nodes)
    end

    for k in keys(m.nonconvex_terms)
        if m.nonconvex_terms[k][:nonlinear_type] == :BILINEAR
            arc = []
            for i in k
                @assert isa(i.args[2], Int)
                push!(arc, i.args[2])
            end
            push!(arcs, sort(arc))
        elseif m.nonconvex_terms[k][:nonlinear_type] == :MONOMIAL
            @assert isa(m.nonconvex_terms[k][:var_idxs][1], Int)
            push!(arcs, [m.nonconvex_terms[k][:var_idxs][1], m.nonconvex_terms[k][:var_idxs][1];])
        elseif m.nonconvex_terms[k][:nonlinear_type] == :MULTILINEAR
            var_idxs = m.nonconvex_terms[k][:var_idxs]
            for i in 1:length(var_idxs)
                for j in 1:length(var_idxs)
                    i != j && push!(arcs, sort([var_idxs[i], var_idxs[j];]))
                end
            end
        elseif m.nonconvex_terms[k][:nonlinear_type] == :INTLIN
            @assert length(m.nonconvex_terms[k][:var_idxs]) == 2
            var_idxs = copy(m.nonconvex_terms[k][:var_idxs])
            push!(arcs, sort(var_idxs))
        elseif m.nonconvex_terms[k][:nonlinear_type] == :INTPROD
            var_idxs = m.nonconvex_terms[k][:var_idxs]
            for i in 1:length(var_idxs)
                for j in 1:length(var_idxs)
                    i != j && push!(arcs, sort([var_idxs[i], var_idxs[j];]))
                end
            end
        elseif m.nonconvex_terms[k][:nonlinear_type] in [:cos, :sin]
            @assert length(m.nonconvex_terms[k][:var_idxs]) == 1
            var_idx = m.nonconvex_terms[k][:var_idxs][1]
            @assert isa(var_idx, Int)
            push!(arcs, [var_idx, var_idx;])
        elseif m.nonconvex_terms[k][:nonlinear_type] in [:BININT, :BINLIN, :BINPROD]
            continue
        else
            error("[EXCEPTION] Unexpected nonlinear term when building discvar graph.")
        end
    end

    # Collect integer variables
    for i in 1:m.num_var_orig
        if !(i in nodes) && m.var_type[i] == :Int
            push!(nodes, i)
            push!(arcs, [i,i;])
        end
    end

    @assert length(nodes) == length(m.candidate_disc_vars)

    nodes = collect(nodes)
    arcs = collect(arcs)

    return nodes, arcs
end

function min_vertex_cover(m::PODNonlinearModel)

    nodes, arcs = build_discvar_graph(m)

    # Set up minimum vertex cover problem
    minvertex = Model(solver=m.mip_solver)
    @variable(minvertex, x[nodes], Bin)
    for a in arcs
        @constraint(minvertex, x[a[1]] + x[a[2]] >= 1)
    end
    @objective(minvertex, Min, sum(x))

    status = solve(minvertex, suppress_warnings=true)
    xVal = getvalue(x)

    # Getting required information
    m.num_var_disc_mip = Int(sum(xVal))
    m.disc_vars = [i for i in nodes if xVal[i] > 1e-5]

    return
end

function weighted_min_vertex_cover(m::PODNonlinearModel, distance::Dict)

    # Collect the graph information
    nodes, arcs = build_discvar_graph(m)

    # A little bit redundency before
    disvec = [distance[i] for i in keys(distance) if i in m.candidate_disc_vars]
    disvec = abs.(disvec[disvec .> 0.0])
    isempty(disvec) ? heavy = 1.0 : heavy = 1/minimum(disvec)
    weights = Dict()
    for i in m.candidate_disc_vars
        isapprox(distance[i], 0.0; atol=1e-6) ? weights[i] = heavy : (weights[i]=(1/distance[i]))
        (m.loglevel > 100) && println("VAR$(i) WEIGHT -> $(weights[i]) ||| DISTANCE -> $(distance[i])")
    end

    # Set up minimum vertex cover problem
    minvertex = Model(solver=m.mip_solver)
    @variable(minvertex, x[nodes], Bin)
    for arc in arcs
        @constraint(minvertex, x[arc[1]] + x[arc[2]] >= 1)
    end
    @objective(minvertex, Min, sum(weights[i]*x[i] for i in nodes))

    # Solve the minimum vertex cover
    status = solve(minvertex, suppress_warnings=true)

    xVal = getvalue(x)
    m.num_var_disc_mip = Int(sum(xVal))
    m.disc_vars = [i for i in nodes if xVal[i] > 0]
    (m.loglevel >= 99) && println("UPDATED DISC-VAR COUNT = $(length(m.disc_vars)) : $(m.disc_vars)")

    return
end

function round_sol(m::PODNonlinearModel, nlp_model)
    relaxed_sol = MathProgBase.getsolution(nlp_model)
    return [m.var_type_orig[i] in [:Bin, :Int] ? round(relaxed_sol[i]) : relaxed_sol[i] for i in 1:m.num_var_orig]
end

"""
    Evaluate a solution feasibility: Solution bust be in the feasible category and evaluated rhs must be feasible
"""
function eval_feasibility(m::PODNonlinearModel, sol::Vector)

    length(sol) == m.num_var_orig || error("Candidate solution length mismatch.")


    for i in 1:m.num_var_orig
        # Check solution category and bounds
        if m.var_type[i] == :Bin
            isapprox(sol[i], 1.0;atol=m.tol) || isapprox(sol[i], 0.0;atol=m.tol) || return false
        elseif m.var_type[i] == :Int
            isapprox(mod(sol[i], 1.0), 0.0;atol=m.tol) || return false
        end
        # Check solution bounds (with tight bounds)
        sol[i] <= m.l_var_tight[i] - m.tol || return false
        sol[i] >= m.u_var_tight[i] + m.tol || return false
    end

    # Check constraint violation
    eval_rhs = zeros(m.num_constr_orig)
    MathProgBase.eval_g(m.d_orig, eval_rhs, rounded_sol)
    feasible = true
    for i in 1:m.num_constr_orig
        if m.constr_type_orig[i] == :(==)
            if !isapprox(eval_rhs[i], m.l_constr_orig[i]; atol=m.tol)
                feasible = false
                m.loglevel >= 100 && println("[BETA] Violation on CONSTR $(i) :: EVAL $(eval_rhs[i]) != RHS $(m.l_constr_orig[i])")
                m.loglevel >= 100 && println("[BETA] CONSTR $(i) :: $(m.bounding_constr_expr_mip[i])")
                return false
            end
        elseif m.constr_type_orig[i] == :(>=)
            if !(eval_rhs[i] >= m.l_constr_orig[i] - m.tol)
                m.loglevel >= 100 && println("[BETA] Violation on CONSTR $(i) :: EVAL $(eval_rhs[i]) !>= RHS $(m.l_constr_orig[i])")
                m.loglevel >= 100 && println("[BETA] CONSTR $(i) :: $(m.bounding_constr_expr_mip[i])")
                return false
            end
        elseif m.constr_type_orig[i] == :(<=)
            if !(eval_rhs[i] <= m.u_constr_orig[i] + m.tol)
                m.loglevel >= 100 && println("[BETA] Violation on CONSTR $(i) :: EVAL $(eval_rhs[i]) !<= RHS $(m.u_constr_orig[i])")
                m.loglevel >= 100 && println("[BETA] CONSTR $(i) :: $(m.bounding_constr_expr_mip[i])")
                return false
            end
        end
    end

    return feasible
end
