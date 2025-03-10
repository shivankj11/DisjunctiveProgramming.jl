# DisjunctiveProgramming.jl
Generalized Disjunctive Programming extension to JuMP

![](logo.png)

## Installation

```julia
using Pkg
Pkg.add("DisjunctiveProgramming")
```

## Disjunctions

After defining a JuMP model, disjunctions can be added to the model by using the `@disjunction` macro. This macro is called by `@disjunction(m, disjuncts...; kwargs...), where `disjuncts...` is a list of at least two expressions of the form:
1. A valid expression accepted by [JuMP.@constraint](https://jump.dev/JuMP.jl/stable/reference/constraints/#JuMP.@constraint). Names for the constraints or containers of constraints cannot be passed (use option 2).
2. A valid expression accepted by [JuMP.@constraints](https://jump.dev/JuMP.jl/stable/reference/constraints/#JuMP.@constraints) (using `begin...end)
3. A valid expression accepted by [JuMP.@NLconstraint](https://jump.dev/JuMP.jl/stable/reference/nlp/#JuMP.@NLconstraint). Containers of constraints cannot be passed (use option 4). Naming of non-linear constraints is not currently supported.
4. A valid expression accepted by [JuMP.@NLconstraints](https://jump.dev/JuMP.jl/stable/reference/nlp/#JuMP.@NLconstraints) (using `begin...end)
5. `Tuple` of expressions accepted by options 1 and/or 3.

NOTES: 
- Vectorized constraints (using `.` notation) are not currently supported. The current workarround is to first create the constraint with the `@constraint` macro and then use the `add_disjunction!`, instead of the `@disjunction` macro. The `add_disjunction!` function receives the same arguments as the `@disjunction` macro, with the exception that instead of creating the constraints in the disjunctions, references to previously created constraints are used for the disjuncts.
- Any constraints that are of `EqualTo` type are split into two constraints (e.g., `f(x) == 0` -> `0 <= f(x) <= 0`). This is necessary only for the Big-M reformulation of equality constraints, but is currently applied regardless of the reformulation technique.
- Any constraints that are of `Interval` type are split into two constraints (one for each bound).
- It is assumed that the disjuncts belonging to a disjunction are proper disjunctions (mutually exclussive) and only one of them will be selected (`XOR`).

The valid key-word arguments for the `@disjunction` macro are:
- `reformulation::Symbol`: `:big_m` for [Big-M Reformulation](https://optimization.mccormick.northwestern.edu/index.php/Disjunctive_inequalities#Big-M_Reformulation), `:hull` for [Hull Reformulation](https://optimization.mccormick.northwestern.edu/index.php/Disjunctive_inequalities#Convex-Hull_Reformulation)
- `M`: Big-M value used when `reformulation = :big_m`.
- `ϵ`: epsilon tolerance for the perspective function proposed by [Furman, et al. [2020]](https://link.springer.com/article/10.1007/s10589-020-00176-0). Only used when `reformulation = :hull`.
- `name::Symbol`: Name for the disjunction (also name for indicator variable used on that disjunction). If not passed (`name = missing`), a symbolic name will be generated with the prefix `disj`. The mutual exclussion constraint on the binary indicator variables can be accessed with `model[Symbol("XOR(disj_$name)")]`.

When a disjunction is defined using the `@disjunction` macro, the disjunctions are reformulated to algebraic constraints via either Big-M or Hull reformulations. For the Hull reformulation, disaggregated variables are generated by adding the suffix `_$name$i` to the original variables, where `i` is the index of the disjunct in that disjunction. Bounding constraints are applied to the disaggregated variables and can be accessed with `model[Symbol("$<original var>_$name$i_lb")]` and `model[Symbol("$<original var>_$name$i_ub")]` for the lower bound and upper bound constraints, respectively. The aggregation constraint can be accessed with `model[Symbol("$<original var>_aggregation")]`. For Big-M reformulations, the user may provide an `M` object that represents the BigM value(s). The `M` object can be a `Number` that is applied to all constraints in the disjuncts, or a `Vector`/`Tuple` of values that are used for each of the disjuncts. For Hull reformulations, the user may provide an `ϵ` value for the perspective function (default is `ϵ = 1e-6`). The `ϵ` object can be a `Number` that is applied to all perspective functions, or a `Vector`/`Tuple` of values that are used for each of the disjuncts.

For empty disjuncts, use `nothing` for their positional argument (e.g., `@disjunction(m, x <= 1, nothing, reformulation = :big_m)`).

NOTE: `:object_dict` is used in the extension dictionary to store the object dictionary of models using *DisjunctiveProgramming.jl*.

## Logical Propositions

Boolean logic can be included in the model by using the `@proposition` macro. This macro will take an expression that uses only binary variables from the model (typically a subset of the indicator variables used in the disjunctions) and one or more of the following Boolean operators:
- `∨` (or, typed with `\vee + tab`)
- `∧` (and, typed with `\wedge + tab`)
- `¬` (negation, typed with `\neg + tab`)
- `⇒` (implication, typed with `\Rightarrow + tab`)
- `⇔` (double implication or equivalence, typed with `\Leftrightarrow + tab`)
The logical proposition is then internally reformulated to an algebraic constraint that is added to the model. This constrait can be accessed with `model[Symbol("<logical proposition expression>")]`.

## Example

The example below is from the [Northwestern University Process Optimization Open Textbook](https://optimization.mccormick.northwestern.edu/index.php/Disjunctive_inequalities).

To perform the Big-M reformulation, `:big_m` is passed to the `reformulation` keyword argument. If nothing is passed to the keyword argument `M`, tight Big-M values will be inferred from the variable bounds using IntervalArithmetic.jl. If `x` is not bounded, Big-M values must be provided for either the whole system (e.g., `M = 10`) or for each of the constraint arrays in the example (e.g., `M = (10,10)`).

To perform the Hull reformulation, `reformulation = :hull`. Variables must have bounds for the reformulation to work.

```julia
using JuMP
using DisjunctiveProgramming

m = Model()
@variable(m, -5 ≤ x ≤ 10)
@disjunction(
    m,
    0 ≤ x ≤ 3,
    5 ≤ x ≤ 9,
    reformulation=:big_m,
    name=:y
)
@proposition(m, y[1] ∨ y[2]) #this is a redundant proposition

print(m)

┌ Warning: disj_y[1] : x in [0.0, 3.0] uses the `MOI.Interval` set. Each instance of the interval set has been split into two constraints, one for each bound.
┌ Warning: disj_y[2] : x in [5.0, 9.0] uses the `MOI.Interval` set. Each instance of the interval set has been split into two constraints, one for each bound.
Feasibility
Subject to
 XOR(disj_y) : y[1] + y[2] == 1.0         <- XOR constraint
 y[1] ∨ y[2] : y[1] + y[2] >= 1.0         <- reformulated logical proposition (name is the proposition)
 disj_y[1][lb] : -x + 5 y[1] <= 5.0       <- left-side of constraint in 1st disjunct (name is assigned to disj_y[1][lb])
 disj_y[1][ub] : x + 7 y[1] <= 10.0       <- right-side of constraint in 1st disjunct (name is assigned to disj_y[1][ub])
 disj_y[2][lb] : -x + 10 y[2] <= 5.0      <- left-side of constraint in 2nd disjunct (name is assigned to disj_y[2][lb])
 disj_y[2][ub] : x + y[2] <= 10.0         <- right-side of constraint in 2nd disjunct (name is assigned to disj_y[2][ub])
 x >= -5.0                                <- variable lower bound
 x <= 10.0                                <- variable upper bound
 y[1] binary                              <- indicator variable (1st disjunct) is binary
 y[2] binary                              <- indicator variable (2nd disjunct) is binary
```
