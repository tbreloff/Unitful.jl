__precompile__(true)
module Unitful

import Base: ==, <, <=, +, -, *, /, .+, .-, .*, ./, .\, //, ^, .^
import Base: show, convert
import Base: abs, abs2, float, inv, sqrt
import Base: min, max, floor, ceil, log, log10, real, imag, conj

import Base: mod, rem, div, fld, cld, trunc, round, sign, signbit
import Base: isless, isapprox, isinteger, isreal, isinf, isfinite, isnan
import Base: copysign, flipsign
import Base: prevfloat, nextfloat, maxintfloat, rat, step #, linspace
import Base: promote_op, promote_array_type, promote_rule, unsafe_getindex
import Base: length, float, start, done, next, last, one, zero, colon#, range
import Base: getindex, eltype, step, last, first, frexp
import Base: Rational, typemin, typemax
import Base: steprange_last, unitrange_last, unsigned

export unit, dimension, uconvert, ustrip
export @dimension, @derived_dimension, @refunit, @unit, @u_str
export DimensionedQuantity, Quantity
export DimensionlessQuantity
export NoUnits, NoDims

include("Types.jl")
include("User.jl")
const NoUnits = Units{(), Dimensions{()}}()
const NoDims = Dimensions{()}()

"""
```
type DimensionError <: Exception end
```

Thrown when dimensions don't match in an operation that demands they do.
"""
type DimensionError <: Exception end

"""
```
ustrip(x::Number)
```

Returns the number out in front of any units. This may be different from the value
in the case of dimensionless quantities. See [`uconvert`](@ref) and the example
below. Because the units are removed, information may be lost and this should
be used with some care.

This function is just calling `x/unit(x)`, which is as fast as directly
accessing the `val` field of `x::Quantity`, but also works for any other kind
of number.

This function is mainly intended for compatibility with packages that don't know
how to handle quantities. This function may be deprecated in the future.

```jldoctest
julia> ustrip(2u"μm/m") == 2
true

julia> uconvert(NoUnits, 2u"μm/m") == 2//1000000
true
```
"""
ustrip(x::Number) = x/unit(x)

"""
```
ustrip{T,D,U}(x::Array{Quantity{T,D,U}})
```

Strip units from an `Array` by reinterpreting to type `T`. The resulting
`Array` is a "unit free view" into array `x`. Because the units are
removed, information may be lost and this should be used with some care.

This function is provided primarily for compatibility purposes; you could pass
the result to PyPlot, for example. This function may be deprecated in the future.

```jldoctest
julia> a = [1u"m", 2u"m"]
2-element Array{Quantity{Int64, Dimensions:{𝐋}, Units:{m}},1}:
 1 m
 2 m

julia> b = ustrip(a)
2-element Array{Int64,1}:
 1
 2

julia> a[1] = 3u"m"; b
2-element Array{Int64,1}:
 3
 2
```
"""
ustrip{T,D,U}(x::Array{Quantity{T,D,U}}) = reinterpret(T, x)

"""
```
ustrip{T<:Number}(x::Array{T})
```

Fall-back that returns `x`.
"""
ustrip{T<:Number}(x::Array{T}) = x

"""
```
unit{T,D,U}(x::Quantity{T,D,U})
```

Returns the units associated with a quantity, `U()`.

Examples:

```jldoctest
julia> unit(1.0u"m") == u"m"
true

julia> typeof(u"m")
Unitful.Units{(Unitful.Unit{:Meter}(0,1//1),),Unitful.Dimensions{(Unitful.Dimension{:Length}(1//1),)}}
```
"""
unit{T,D,U}(x::Quantity{T,D,U}) = U()

"""
```
unit{T,D,U}(x::Type{Quantity{T,D,U}})
```

Returns the units associated with a quantity type, `U()`.

Examples:

```jldoctest
julia> unit(typeof(1.0u"m")) == u"m"
true
```
"""
unit{T,D,U}(::Type{Quantity{T,D,U}}) = U()


"""
```
unit(x::Number)
```

Returns a `Unitful.Units{(), Dimensions{()}}` object to indicate that ordinary
numbers have no units. This is a singleton, which we export as `NoUnits`.
The unit is displayed as an empty string.

Examples:

```jldoctest
julia> typeof(unit(1.0))
Unitful.Units{(),Unitful.Dimensions{()}}
julia> typeof(unit(Float64))
Unitful.Units{(),Unitful.Dimensions{()}}
julia> unit(1.0) == NoUnits
true
```
"""
unit(x::Number) = NoUnits
unit{T<:Number}(x::Type{T}) = NoUnits

"""
```
dimension(x::Number)
dimension{T<:Number}(x::Type{T})
```

Returns a `Unitful.Dimensions{()}` object to indicate that ordinary
numbers are dimensionless. This is a singleton, which we export as `NoDims`.
The dimension is displayed as an empty string.

Examples:

```jldoctest
julia> typeof(dimension(1.0))
Unitful.Dimensions{()}
julia> typeof(dimension(Float64))
Unitful.Dimensions{()}
julia> dimension(1.0) == NoDims
true
```
"""
dimension(x::Number) = NoDims
dimension{T<:Number}(x::Type{T}) = NoDims

"""
```
dimension{U,D}(u::Units{U,D})
```

Returns a [`Unitful.Dimensions`](@ref) object corresponding to the dimensions
of the units, `D()`. For a dimensionless combination of units, a
`Unitful.Dimensions{()}` object is returned.

Examples:

```jldoctest
julia> dimension(u"m")
𝐋

julia> typeof(dimension(u"m"))
Unitful.Dimensions{(Unitful.Dimension{:Length}(1//1),)}

julia> typeof(dimension(u"m/km"))
Unitful.Dimensions{()}
```
"""
dimension{U,D}(u::Units{U,D}) = D()

"""
```
dimension{D}(x::DimensionedQuantity{D})
```

Returns a [`Unitful.Dimensions`](@ref) object `D()` corresponding to the
dimensions of quantity `x`. For a dimensionless [`Unitful.Quantity`](@ref), a
`Unitful.Dimensions{()}` object is returned.

Examples:

```jldoctest
julia> dimension(1.0u"m")
𝐋

julia> typeof(dimension(1.0u"m/μm"))
Unitful.Dimensions{()}
```
"""
dimension{D}(x::DimensionedQuantity{D}) = D()
dimension{D}(x::Type{DimensionedQuantity{D}}) = D()
dimension{T,D,U}(::Type{Quantity{T,D,Units{U,D}}}) = D()

"""
```
dimension{T<:Number}(x::AbstractArray{T})
```

Just calls `map(dimension, x)`.
"""
dimension{T<:Number}(x::AbstractArray{T}) = map(dimension, x)

"""
```
dimension{T<:Units}(x::AbstractArray{T})
```

Just calls `map(dimension, x)`.
"""
dimension{T<:Units}(x::AbstractArray{T}) = map(dimension, x)

function basefactorhelper(inex, ex, t, p)
    if isinteger(p)
        p = Integer(p)
    end

    can_exact = (ex < typemax(Int))
    can_exact &= (1/ex < typemax(Int))

    ex2 = 10.0^t*float(ex)^p
    can_exact &= (ex2 < typemax(Int))
    can_exact &= (1/ex2 < typemax(Int))
    can_exact &= isinteger(p)

    if can_exact
        (inex^p, (ex//1*10^t)^p)
    else
        ((inex * ex * 10.0^t)^p, 1)
    end
end

@generated function basefactor(x::Units)
    tunits = x.parameters[1]
    fact1 = map(basefactor, tunits)
    inex1 = mapreduce(x->getfield(x,1), *, 1.0, fact1)
    ex1   = mapreduce(x->getfield(x,2), *, 1, fact1)
    :(($inex1,$ex1))
end

function tensfactor(x::Unit)
    p = power(x)
    if isinteger(p)
        p = Integer(p)
    end
    tens(x)*p
end

@generated function tensfactor(x::Units)
    tunits = x.parameters[1]
    a = mapreduce(tensfactor, +, 0, tunits)
    :($a)
end

# Addition / subtraction
for op in [:+, :-]
    @eval ($op){S,T,D,U}(x::Quantity{S,D,U}, y::Quantity{T,D,U}) =
        Quantity(($op)(x.val,y.val), U())

    # If not generated, there are run-time allocations
    @eval @generated function ($op){S,T,D,SU,TU}(x::Quantity{S,D,SU},
            y::Quantity{T,D,TU})
        result_units = promote_type(SU,TU)()
        :($($op)(uconvert($result_units, x), uconvert($result_units, y)))
    end

    @eval ($op)(::Quantity, ::Quantity) = throw(DimensionError())
    @eval function ($op)(x::Quantity, y::Number)
        if isa(x, DimensionlessQuantity)
            ($op)(promote(x,y)...)
        else
            throw(DimensionError())
        end
    end
    @eval function ($op)(x::Number, y::Quantity)
        if isa(y, DimensionlessQuantity)
            ($op)(promote(x,y)...)
        else
            throw(DimensionError())
        end
    end

    @eval ($op)(x::Quantity) = Quantity(($op)(x.val),unit(x))
end

*(x::Number, y::Units, z::Units...) = Quantity(x,*(y,z...))

# Kind of weird, but okay, no need to make things noncommutative.
*(x::Units, y::Number) = *(y,x)

# These six are defined for use in `*(a0::Unitlike, a::Unitlike...)`
unit{S}(x::Unit{S}) = S
unit{S}(x::Dimension{S}) = S
tens(x::Unit) = x.tens
tens(x::Dimension) = 0
power(x::Unit) = x.power
power(x::Dimension) = x.power

"""
```
*(a0::Unitlike, a::Unitlike...)
```

Given however many unit-like objects, multiply them together. Both
[`Unitful.Dimensions`](@ref) and [`Unitful.Units`](@ref) objects are considered
to be `Unitlike` in the sense that you can multiply them, divide them, and
collect powers. This function will fail if there is an attempt to multiply a
unit by a dimension or vice versa.

Collect [`Unitful.Unit`](@ref) objects from the type parameter of the
[`Unitful.Units`](@ref) objects. For identical units including SI prefixes
(i.e. cm ≠ m), collect powers and sort uniquely by the name of the `Unit`.
The unique sorting permits easy unit comparisons.

Examples:

```jldoctest
julia> u"kg*m/s^2"
kg m s^-2

julia> u"m/s*kg/s"
kg m s^-2

julia> typeof(u"m/s*kg/s") == typeof(u"kg*m/s^2")
true
```
"""
@generated function *(a0::Unitlike, a::Unitlike...)

    # Sort the units uniquely. This is a generated function so that we
    # don't have to figure out the units each time.

    D = a0 <: Units ? Unit : Dimension
    b = Array{D,1}()
    a0p = a0.parameters[1]
    length(a0p) > 0 && append!(b, a0p)
    for x in a
        xp = x.parameters[1]
        length(xp) > 0 && append!(b, xp)
    end

    # b is an Array containing all of the Unit or Dimension objects that were
    # found in the type parameters of the Units or Dimensions object (a0, a...)

    sort!(b, by=x->power(x))
    D == Unit && sort!(b, by=x->tens(x))
    sort!(b, by=x->unit(x))

    # Units[m,m,cm,cm^2,cm^3,nm,m^4,µs,µs^2,s]
    # reordered as:
    # Units[nm,cm,cm^2,cm^3,m,m,m^4,µs,µs^2,s]

    # Collect powers of a given unit
    c = Array{D,1}()
    if !isempty(b)
        i = start(b)
        oldstate = b[i]
        p=0//1
        while !done(b, i)
            (state, i) = next(b, i)
            if tens(state) == tens(oldstate) && unit(state) == unit(oldstate)
                p += power(state)
            else
                if p != 0
                    push!(c, D{unit(oldstate)}(tens(oldstate),p))
                end
                p = power(state)
            end
            oldstate = state
        end
        if p != 0
            push!(c, D{unit(oldstate)}(tens(oldstate),p))
        end
    end
    # results in:
    # Units[nm,cm^6,m^6,µs^3,s]

    if a0 <: Units
        T = Units
        d = (c...)
        f = typeof(mapreduce(dimension,*,NoDims,c))
        :(($T){$d,$f}())
    else
        T = Dimensions
        d = (c...)
        :(($T){$d}())
    end
end

function *{T,D,U}(x::Quantity{T,D,U}, y::Units, z::Units...)
    result_units = *(U(),y,z...)
    Quantity(x.val,result_units)
end

function *(x::Quantity, y::Quantity)
    xunits = unit(x)
    yunits = unit(y)
    result_units = xunits*yunits
    z = x.val*y.val
    Quantity(z,result_units)
end

# Next two lines resolves some method ambiguity:
*{T<:Quantity}(x::Bool, y::T) =
    ifelse(x, y, ifelse(signbit(y), -zero(y), zero(y)))
*(x::Quantity, y::Bool) = Quantity(x.val*y, unit(x))

*(y::Number, x::Quantity) = *(x,y)
*(x::Quantity, y::Number) = Quantity(x.val*y, unit(x))

# See operators.jl
# Element-wise operations with units
for (f,F) in [(:./, :/), (:.*, :*), (:.+, :+), (:.-, :-)]
    @eval ($f)(x::Units, y::Units) = ($F)(x,y)
    @eval ($f)(x::Number, y::Units)   = ($F)(x,y)
    @eval ($f)(x::Units, y::Number)   = ($F)(x,y)
end
.\(x::Unitlike, y::Unitlike) = y./x
.\(x::Number, y::Units) = y./x
.\(x::Units, y::Number) = y./x

# See arraymath.jl
./(x::Units, Y::AbstractArray) =
    reshape([ x ./ y for y in Y ], size(Y))
./(X::AbstractArray, y::Units) =
    reshape([ x ./ y for x in X ], size(X))
.\(x::Units, Y::AbstractArray) =
    reshape([ x .\ y for y in Y ], size(Y))
.\(X::AbstractArray, y::Units) =
    reshape([ x .\ y for x in X ], size(X))

for f in (:.*,) # looked in arraymath.jl for similar code
    @eval begin
        function ($f){T}(A::Units, B::AbstractArray{T})
            F = similar(B, promote_op($f,typeof(A),T))
            for (iF, iB) in zip(eachindex(F), eachindex(B))
                @inbounds F[iF] = ($f)(A, B[iB])
            end
            return F
        end
        function ($f){T}(A::AbstractArray{T}, B::Units)
            F = similar(A, promote_op($f,T,typeof(B)))
            for (iF, iA) in zip(eachindex(F), eachindex(A))
                @inbounds F[iF] = ($f)(A[iA], B)
            end
            return F
        end
    end
end

# Division (units)

/(x::Unitlike, y::Unitlike) = *(x,inv(y))
/(x::Quantity, y::Units) = Quantity(x.val, unit(x) / y)
/(x::Units, y::Quantity) = Quantity(1/y.val, x / unit(y))
/(x::Number, y::Units) = Quantity(x,inv(y))
/(x::Units, y::Number) = (1/y) * x

//(x::Unitlike, y::Unitlike)  = x/y
//(x::Quantity, y::Units) = Quantity(x.val, unit(x) / y)
//(x::Units, y::Quantity) = Quantity(1//y.val, x / unit(y))
//(x::Number, y::Units) = Rational(x)/y
//(x::Units, y::Number) = (1//y) * x

# Division (quantities)

for op in (:/, ://)
    @eval begin
        ($op)(x::Quantity, y::Quantity) = Quantity(($op)(x.val, y.val), unit(x) / unit(y))
        ($op)(x::Quantity, y::Number) = Quantity(($op)(x.val, y), unit(x))
        ($op)(x::Number, y::Quantity) = Quantity(($op)(x, y.val), inv(unit(y)))
    end
end

# ambiguity resolution
//(x::Quantity, y::Complex) = Quantity(//(x.val, y), unit(x))

# Division (other functions)

for f in (:div, :fld, :cld)
    @eval function ($f)(x::Quantity, y::Quantity)
        z = uconvert(unit(y), x)
        ($f)(z.val,y.val)
    end
end

for f in (:mod, :rem)
    @eval function ($f)(x::Quantity, y::Quantity)
        z = uconvert(unit(y), x)
        Quantity(($f)(z.val,y.val), unit(y))
    end
end

# Exponentiation is not type stable.
# For now we define a special `inv` method to at least
# enable division to be fast.
@generated function inv(x::Dimensions)
    tup = x.parameters[1]
    length(tup) == 0 && return :(x)
    tup2 = map(x->x^-1,tup)
    y = *(Dimensions{tup2}())
    :($y)
end

@generated function inv(x::Units)
    tup = x.parameters[1]
    length(tup) == 0 && return :(x)
    tup2 = map(x->x^-1,tup)
    D = typeof(mapreduce(dimension, *, NoDims, tup2))
    y = *(Units{tup2, D}())
    :($y)
end

^{T}(x::Unit{T}, y::Integer) = Unit{T}(tens(x),power(x)*y)
^{T}(x::Unit{T}, y) = Unit{T}(tens(x),power(x)*y)

^{T}(x::Dimension{T}, y::Integer) = Dimension{T}(power(x)*y)
^{T}(x::Dimension{T}, y) = Dimension{T}(power(x)*y)

function ^{T}(x::Dimensions{T}, y::Integer)   # needed for ambiguity resolution
    *(Dimensions{map(a->a^y, T)}())
end

function ^{T}(x::Dimensions{T}, y)
    *(Dimensions{map(a->a^y, T)}())
end

function ^{U,D}(x::Units{U,D}, y::Integer)
    utup = map(a->a^y, U)
    *(Units{utup, ()}()) # dimensions get reconstructed anyway
    # would use mapreduce(dimension, *, NoDims, utup)
end

function ^{U,D}(x::Units{U,D}, y)
    utup = map(a->a^y, U)
    *(Units{utup, ()}())
end

# All of these are needed for ambiguity resolution
^{T,D,U}(x::Quantity{T,D,U}, y::Integer) = Quantity((x.val)^y, U()^y)
^{T,D,U}(x::Quantity{T,D,U}, y::Rational) = Quantity((x.val)^y, U()^y)
^{T,D,U}(x::Quantity{T,D,U}, y::Real) = Quantity((x.val)^y, U()^y)

# Other mathematical functions
"""
```
sqrt(x::Quantity)
```
"""
sqrt(x::Quantity) = Quantity(sqrt(x.val), sqrt(unit(x)))

# This is a generated function to ensure type stability and keep `sqrt` fast.
@generated function sqrt(x::Dimensions)
    tup = x.parameters[1]
    tup2 = map(x->x^(1//2),tup)
    y = *(Dimensions{tup2}())    # sort appropriately
    :($y)
end

# This is a generated function to ensure type stability and keep `sqrt` fast.
@generated function sqrt(x::Units)
    tup = x.parameters[1]
    tup2 = map(x->x^(1//2),tup)
    y = *(Units{tup2,()}())    # sort appropriately
    :($y)
end

for (f, F) in [(:min, :<), (:max, :>)]
    @eval @generated function ($f)(x::Quantity, y::Quantity)
        xdim = x.parameters[2]()
        ydim = y.parameters[2]()
        if xdim != ydim
            return :(throw(DimensionError()))
        end

        xunits = x.parameters[3].parameters[1]
        yunits = y.parameters[3].parameters[1]

        factx = mapreduce(.*, xunits) do x
            vcat(basefactor(x)...)
        end
        facty = mapreduce(.*, yunits) do x
            vcat(basefactor(x)...)
        end

        tensx = mapreduce(tensfactor, +, xunits)
        tensy = mapreduce(tensfactor, +, yunits)

        convx = *(factx..., (10.0)^tensx)
        convy = *(facty..., (10.0)^tensy)

        :($($F)(x.val*$convx, y.val*$convy) ? x : y)
    end

    @eval ($f)(x::Units, y::Units) =        # TODO remove
        unit(($f)(Quantity(1.0, x), Quantity(1.0, y)))
end

@vectorize_2arg Quantity max
@vectorize_2arg Quantity min

abs(x::Quantity) = Quantity(abs(x.val),  unit(x))
abs2(x::Quantity) = Quantity(abs2(x.val), unit(x)*unit(x))

trunc(x::Quantity) = Quantity(trunc(x.val), unit(x))
round(x::Quantity) = Quantity(round(x.val), unit(x))

copysign(x::Quantity, y::Number) = Quantity(copysign(x.val,y/unit(y)), unit(x))
flipsign(x::Quantity, y::Number) = Quantity(flipsign(x.val,y/unit(y)), unit(x))

isless{T,D,U}(x::Quantity{T,D,U}, y::Quantity{T,D,U}) = isless(x.val, y.val)
isless(x::Quantity, y::Quantity) = isless(uconvert(unit(y), x).val, y.val)
<{T,D,U}(x::Quantity{T,D,U}, y::Quantity{T,D,U}) = (x.val < y.val)
<(x::Quantity, y::Quantity) = <(uconvert(unit(y), x).val,y.val)

isapprox{T,D,U}(x::Quantity{T,D,U}, y::Quantity{T,D,U}) = isapprox(x.val, y.val)
isapprox(x::Quantity, y::Quantity) = isapprox(uconvert(unit(y), x).val, y.val)
isapprox(x::Quantity, y::Number) = isapprox(uconvert(NoUnits, x), y)
isapprox(x::Number, y::Quantity) = isapprox(y,x)

function isapprox{T1,D,U1,T2,U2}(x::AbstractArray{Quantity{T1,D,U1}},
        y::AbstractArray{Quantity{T2,D,U2}}; rtol::Real=Base.rtoldefault(T1,T2),
        atol=zero(Quantity{T1,D,U1}), norm::Function=vecnorm)

    d = norm(x - y)
    if isfinite(d)
        return d <= atol + rtol*max(norm(x), norm(y))
    else
        # Fall back to a component-wise approximate comparison
        return all(ab -> isapprox(ab[1], ab[2]; rtol=rtol, atol=atol), zip(x, y))
    end
end
isapprox{S<:Quantity,T<:Quantity}(x::AbstractArray{S}, y::AbstractArray{T};
    kwargs...) = false
function isapprox{S<:Quantity,N<:Number}(x::AbstractArray{S}, y::AbstractArray{N};
    kwargs...)
    if dimension(N) == dimension(S)
        isapprox(map(x->uconvert(NoUnits,x),x),y; kwargs...)
    else
        false
    end
end
isapprox{S<:Quantity,N<:Number}(y::AbstractArray{N}, x::AbstractArray{S};
    kwargs...) = isapprox(x,y; kwargs...)

=={S,T,D,U}(x::Quantity{S,D,U}, y::Quantity{T,D,U}) = (x.val == y.val)
function ==(x::Quantity, y::Quantity)
    dimension(x) != dimension(y) && return false
    uconvert(unit(y), x).val == y.val
end

function ==(x::Quantity, y::Number)
    if dimension(x) == NoDims
        uconvert(NoUnits, x) == y
    else
        false
    end
end
==(x::Number, y::Quantity) = ==(y,x)
<=(x::Quantity, y::Quantity) = <(x,y) || x==y

for f in (:zero, :floor, :ceil)
    @eval ($f)(x::Quantity) = Quantity(($f)(x.val), unit(x))
end
zero{T,D,U}(x::Type{Quantity{T,D,U}}) = zero(T)*U()

"""
```
one(x::Quantity)
```

Returns the multiplicative identity for `x`.
"""
one(x::Quantity) = one(x.val)

"""
```
one{T,D,U}(x::Type{Quantity{T,U}})
```

Returns the multiplicative identity for this type (it's `one(T)`).
"""
one{T,D,U}(x::Type{Quantity{T,D,U}}) = one(T)

isinteger(x::Quantity) = isinteger(x.val)
isreal(x::Quantity) = isreal(x.val)
isfinite(x::Quantity) = isfinite(x.val)
isinf(x::Quantity) = isinf(x.val)
isnan(x::Quantity) = isnan(x.val)

unsigned(x::Quantity) = Quantity(unsigned(x.val), unit(x))

log(x::DimensionlessQuantity) = log(uconvert(NoUnits, x))
log10(x::DimensionlessQuantity) = log10(uconvert(NoUnits, x))

real(x::Quantity) = Quantity(real(x.val), unit(x))
imag(x::Quantity) = Quantity(imag(x.val), unit(x))
conj(x::Quantity) = Quantity(conj(x.val), unit(x))

"""
```
sign(x::Quantity)
```

Returns the sign of `x`.
"""
sign(x::Quantity) = sign(x.val)

"""
```
signbit(x::Quantity)
```

Returns the sign bit of the underlying numeric value of `x`.
"""
signbit(x::Quantity) = signbit(x.val)

prevfloat{T<:AbstractFloat,D,U}(x::Quantity{T,D,U}) =
    Quantity(prevfloat(x.val), unit(x))
nextfloat{T<:AbstractFloat,D,U}(x::Quantity{T,D,U}) =
    Quantity(nextfloat(x.val), unit(x))

function frexp{T<:AbstractFloat,D,U}(x::Quantity{T,D,U})
    a,b = frexp(x.val)
    a *= unit(x)
    a,b
end

"""
```
float(x::Quantity)
```

Convert the numeric backing type of `x` to a floating-point representation.
Returns a `Quantity` with the same units.
"""
float(x::Quantity) = Quantity(float(x.val), unit(x))

"""
```
Integer(x::Quantity)
```

Convert the numeric backing type of `x` to an integer representation.
Returns a `Quantity` with the same units.
"""
Integer(x::Quantity) = Quantity(Integer(x.val), unit(x))

"""
```
Rational(x::Quantity)
```

Convert the numeric backing type of `x` to a rational number representation.
Returns a `Quantity` with the same units.
"""
Rational(x::Quantity) = Quantity(Rational(x.val), unit(x))

colon(start::Quantity, step::Quantity, stop::Quantity) =
    StepRange(promote(start, step, stop)...)

function Base.steprange_last{T<:Number,D,U}(start::Quantity{T,D,U}, step, stop)
    z = zero(step)
    step == z && throw(ArgumentError("step cannot be zero"))
    if stop == start
        last = stop
    else
        if (step > z) != (stop > start)
            last = start - step
        else
            diff = stop - start
            if T<:Signed && (diff > zero(diff)) != (stop > start)
                # handle overflowed subtraction with unsigned rem
                if diff > zero(diff)
                    remain = -convert(typeof(start), unsigned(-diff) % step)
                else
                    remain = convert(typeof(start), unsigned(diff) % step)
                end
            else
                remain = Base.steprem(start,stop,step)
            end
            last = stop - remain
        end
    end
    last
end

"""
```
offsettemp(::Unit)
```

For temperature units, this function is used to set the scale offset.
"""
offsettemp(::Unit) = 0

include("Display.jl")
include("Promotion.jl")
include("Conversion.jl")

defaults()
end
