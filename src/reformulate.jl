"""
    reformulate_disjunction(m::Model, disj...; bin_var, reformulation, param)

Reformulate disjunction on a JuMP model.

    reformulate_disjunction(disj, bin_var, reformulation, param)

Reformulate disjunction.
"""
function reformulate_disjunction(m::Model, disj...; bin_var, reformulation, param)
    m.ext[:object_dict] = copy(object_dictionary(m))
    #check disj
    disj = [check_constraint!(m, constr) for constr in disj]#check_disjunction!(m, disj)
    #run reformulation
    if reformulation == :hull
        disaggregate_variables(m, disj, bin_var)
    end
    reformulate_disjunction(disj, bin_var, reformulation, param)
end
function reformulate_disjunction(disj, bin_var, reformulation, param)
    for (i,constr) in enumerate(disj)
        reformulate_constraint(constr, bin_var, reformulation, param, i)
    end
end

"""
    reformulate_constraint(constr::Tuple, bin_var, reformulation, param, i)

Reformulate a Tuple of constraints.

    reformulate_constraint(constr::AbstractArray{<:ConstraintRef}, bin_var, reformulation, param, i, j = missing)

Reformulate a block of constraints.

    reformulate_constraint(constr::ConstraintRef, bin_var, reformulation, param, i, j = missing, k = missing)

Reformulate a constraint.
"""
function reformulate_constraint(constr::Tuple, bin_var, reformulation, param, i)
    for (j,constr_j) in enumerate(constr)
        reformulate_constraint(constr_j, bin_var, reformulation, param, i, j)
    end
end
function reformulate_constraint(constr::AbstractArray{<:ConstraintRef}, bin_var, reformulation, param, i, j = missing)
    for k in eachindex(constr)
        reformulate_constraint(constr[k], bin_var, reformulation, param, i, j, k)
    end
end
function reformulate_constraint(constr::ConstraintRef, bin_var, reformulation, param, i, j = missing, k = missing)
    if reformulation == :big_m
        big_m_reformulation!(constr, bin_var, param, i, j, k)
    elseif reformulation == :hull
        hull_reformulation!(constr, bin_var, param, i, j, k)
    end
end
reformulate_constraint(args...) = nothing
