using PyPlot
using LinearAlgebra
using PyCall
include("test.jl")

t = 0.0 

# * parameters for Newmark algorithm 
# Newmark Algorithm: http://solidmechanics.org/text/Chapter8_2/Chapter8_2.htm
β1 = 0.5
β2 = 0.5



function remove_bd!(K)
    if length(size(K))==1
        K[Dir] .= 0.0
    else
        T = UniformScaling(1.0)+zeros(2length(dirichlet),2length(dirichlet))
        K[Dir,Dir] = T
        K[Dir,.! Dir] .= 0.0
        K[.! Dir,Dir] .= 0.0
    end
end


# Domain: [0,1]^2
# Dirichlet boundary (u=0) : {0}x[0,1]
# Neumann boundary : {1}x[0,1] σ⋅n = (t1=0, t2), (up to a scalar).
#                    others: 0


# Data Structure
# nodes : nv x 2, coordinates per row
# elem : ne x 3, vertex index per row
n = 10
nv = n^2; ne = 2(n-1)^2
nodes = zeros(nv,2)
elem = zeros(Int64, ne, 3)
for i = 1:n 
    for j = 1:n 
        nodes[i+(j-1)*n,:] = [(i-1)/(n-1) (j-1)/(n-1)]
    end
end

k = 1
for i = 1:n-1
    for j = 1:n-1
        global k
        ii = i + (j-1)*n 
        elem[k,:] = [ii;ii+1;n+ii+1]
        elem[k+1,:] = [ii;n+ii+1;n+ii]
        k += 2
    end
end

# store information for later use
Areas = Float64[]
Ns = Array{Float64}[]
Vs = Array{Int64}[]
for i = 1:size(elem,1)
    x1, y1 = nodes[elem[i,1],:]
    x2, y2 = nodes[elem[i,2],:]
    x3, y3 = nodes[elem[i,3],:]
    A = inv([x1 y1 1;x2 y2 1;x3 y3 1])
    Area = det([x1 y1 1;x2 y2 1;x3 y3 1])/2
    N = [A[1,1] 0 A[1,2] 0 A[1,3] 0;0 A[2,1] 0 A[2,2] 0 A[2,3];A[2,1] A[1,1] A[2,2] A[1,2] A[2,3] A[1,3]]
    ind = [elem[i,1];elem[i,1]+n^2;elem[i,2];elem[i,2]+n^2;elem[i,3];elem[i,3]+n^2] # index, (u1,u2,u3,v1,v2,v3)
    push!(Areas, Area)
    push!(Ns, N)
    push!(Vs, ind)
end

# Dirichlet and Neumann
dirichlet = 1:n:n*(n-1)+1|>Array
neumann = [2:n-1|>Array 3:n|>Array]
Dir = zeros(Bool, 2n^2)
Dir[dirichlet] .= true
Dir[dirichlet .+ n^2] .= true

# Constitutive law: σ=Cε
ν,E = 0.3, 2000
E = E/(1-ν^2)*[1 ν 0.0;ν 1 0.0;0.0 0.0 (1-ν)/2]

# * computing stiffness and mass matrix for linear elasticity 
K = zeros(2nv,2nv) # stiffness matrix
M = zeros(2nv,2nv) # mass matrix
for i = 1:ne
    Q = [1/3 0 1/3 0 1/3 0;0 1/3 0 1/3 0 1/3]
    B = Ns[i]'*E*Ns[i]*Areas[i]    # stiffness matrix
    D = Q'*Q*Areas[i]
    ind = Vs[i]
    K[ind,ind] += B 
    M[ind,ind] += D
end
remove_bd!(K)
remove_bd!(M)

fα = zeros(ne)
fY = 10
fK = 1.0
function f(σ, α)
    return sqrt(σ[1]^2-σ[1]*σ[2]+σ[2]^2+3*σ[3]^2)-fY-fK*α
end

function fσ(σ)
    σ1, σ2, σ3 = σ[1], σ[2], σ[3]
    v = sqrt(σ1^2-σ1*σ2+σ2^2+3*σ3^2)
    z = [(σ1 - σ2/2)/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2);
        (-σ1/2 + σ2)/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2);
        3*σ3/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)]
end

function fσσ(σ)
    σ1, σ2, σ3 = σ[1], σ[2], σ[3]
    [     (-σ1 + σ2/2)*(σ1 - σ2/2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) + 1/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2) (σ1/2 - σ2)*(σ1 - σ2/2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) - 1/(2*sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2))                                   -3*σ3*(σ1 - σ2/2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2);
(-σ1 + σ2/2)*(-σ1/2 + σ2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) - 1/(2*sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2))    (-σ1/2 + σ2)*(σ1/2 - σ2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) + 1/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)                                  -3*σ3*(-σ1/2 + σ2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2);
3*σ3*(-σ1 + σ2/2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2)                                                        3*σ3*(σ1/2 - σ2)/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) -9*σ3^2/(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)^(3/2) + 3/sqrt(σ1^2 - σ1*σ2 + σ2^2 + 3*σ3^2)]

end


# function f(σ, α)
#     return sum(σ)
# end

# function fσ(σ)
#     return [1;1;1]
# end

# function fσσ(σ)
#     return zeros(3,3)
# end



# * computing dΔσdΔε based on the constitutive law of the element:
# * 1. elastic: E
# * 2. plastic: E + (plastic term)
function dΔσdΔε(Δσ,Δγ,σA,Δε)
    dσdε = Array{Float64}[]
    for i = 1:ne 
        σ = Δσ[3(i-1)+1:3i]+σA[3(i-1)+1:3i]
        temp = f(σ, fα[i])
        if temp<0
            push!(dσdε, E)
        else
            A = [UniformScaling(1.0)+Δγ[i]*E*fσσ(σ) E*fσ(σ);
                reshape(fσ(σ),1,3) 0]
            rhs = [E;zeros(1,3)]
            out = A\rhs
            push!(dσdε,out[1:3,:])
        end
    end
    dσdε
end


# * return mapping algorithm: for each element, computing the corresponding constitutive law 
function _rtm(σA, Δε)
    tol = 1e-12
    local e0
    err = 0.0
    Δσ = zeros(3ne); Δγ = zeros(ne)
    for i = 1:ne 
        
        σtrial = σA[3(i-1)+1:3i] + E*Δε[3(i-1)+1:3i]
        if f(σtrial, fα[i])<=0 
            Δσ[3(i-1)+1:3i] = E*Δε[3(i-1)+1:3i]
            Δγ[i] = 0.0
        else
            # using Newton 
            Δσtrial = E*Δε[3(i-1)+1:3i]
            for iter = 1:10000
                σtrial = σA[3(i-1)+1:3i] + Δσtrial
                q1 = Δσtrial - E*Δε[3(i-1)+1:3i] + Δγ[i]*E*fσ(σtrial)
                q2 = f(σtrial, fα[i])

                # * check error 
                e = sum(q1.^2)+q2 
                if iter==1
                    e0 = e
                end
                # @show iter, e/e0
                if iter==1000
                    error("Newton iteration fails, err=$(e/e0), input norm=$(norm(Δε[3(i-1)+1:3i]))")
                end
                if e/e0<tol
                    # printstyled("[Outer$i]$iter, $(e/e0)\n", color=:green)
                    break
                end
                J = [UniformScaling(1.0)+Δγ[i]*E*fσσ(σtrial) E*fσ(σtrial);
                        reshape(fσ(σtrial),1,3) 0]
                δ = -J\[q1;q2]
                Δσtrial += δ[1:3]
                Δγ[i] += δ[4]
                # @show Δσtrial,Δγ[i]
            end
            Δσ[3(i-1)+1:3i] = Δσtrial
        end
    end
    return Δσ, Δγ
end



# * return mapping algorithm: given Δε, find the admissible Δσ and at the same time return the sensitivity 
function rtm(Δε, σA)
    Δσ, Δγ = _rtm(σA, Δε)
    # update the internal variables
    dσdε = dΔσdΔε(Δσ,Δγ,σA,Δε)
    σA+Δσ, dσdε, Δγ
end

# ! check gradients of dΔσdΔε, PASS
σA = rand(3ne)
function _f(Δε)
    σB, dσdε, _ = rtm(Δε, σA)
    J = zeros(3ne, 3ne)
    for e = 1:ne 
        J[3(e-1)+1:3e, 3(e-1)+1:3e] = dσdε[e]
    end
    σB, J
end
gradtest(_f, rand(Float64,3ne))
error()
        
# * compute M+∂K/∂u''
function dKd∂∂u(∂∂u, F, ∂u, ∂∂uk, σA)
    Δu = Δt * ∂u + (1-2β2)/2*Δt^2*∂∂uk + β2*Δt^2*∂∂u
    Δε = zeros(3ne)
    for j = 1:ne 
        B = Ns[j]
        Δε[3(j-1)+1:3j] = B*Δu[Vs[j]]
    end     
    r = M*∂∂u - F
    σB, dσdε, Δγ = rtm(Δε, σA)
    Kt = zeros(2nv, 2nv)
    for i = 1:ne
        B = Ns[i]; ind = Vs[i]
        loc = B'*dσdε[i]*B* Areas[i]* β2*Δt^2
        Kt[ind, ind] += loc
        r[ind] += B'*σB[3(i-1)+1:3i] * Areas[i]

        # Kt[ind, ind] += B'*B*Areas[i]* β2*Δt^2
        # r[ind] += B'*Δε[3(i-1)+1:3i]*Areas[i]
    end
    # remove_bd!(Kt)
    # remove_bd!(r)
    -r, M+Kt, σB, Δγ
end

# ! for gradient test. FAILED: not second order convergence but small
F = rand(2nv)
∂u = rand(2nv)
∂∂uk = rand(2nv)
σA = rand(3ne)
function __f1(∂∂u)
    q, J,_,_ = dKd∂∂u(∂∂u, F, ∂u, ∂∂uk, σA)
    -q, J
end
gradtest(__f1, rand(Float64,2nv))
error()


# * newton step 
function lnl(∂u, ∂∂uk, F, σA)
    global fα
    local σB, e0, Δγ
    tol = 1e-8
    ∂∂u = copy(∂∂uk)
    for i = 1:10000
        q, J, σB, Δγ = dKd∂∂u(∂∂u, F, ∂u, ∂∂uk, σA)
        if i==1
            e0 = norm(q)
        end
        @show i, norm(q)/e0
        if norm(q)/e0<tol
            printstyled("lnl converged, iter = $i, err = $(norm(q)/e0)\n", color=:green)
            break 
        end
        if i==10000
            error("Newton iteration fails")
        end
        δ = J\q 
        ∂∂u += δ
    end
    fα +=Δγ
    ∂∂u,σB
end




# imposing neumann boundary condition
F = zeros(2n^2)
# for i = 1:size(neumann,1)
#     ind = [neumann[i,1]; neumann[i,2]]
#     F[ind] += ones(2)*t
# end
# F[Dir] .= 0.0

# NOTE Newmark Algorithm 
NT = 100
Δt = 1/NT
U = zeros(2nv,NT+1)
∂U = zeros(2nv,NT+1)
∂∂U = zeros(2nv,NT+1)
∂∂U[:,1] = M\(F-K*U[:,1])
Σ = zeros(3ne, NT+1)
∂U[n^2 .+ (1:n^2),1] .= 5.0; ∂U[Dir,1] .= 0.0
for k = 2:NT+1
    println("time step: $k")
    ∂∂U[:,k],Σ[:,k] = lnl(∂U[:,k-1], ∂∂U[:,k-1], F, Σ[:,k-1])
    U[:,k] = U[:,k-1] + Δt*∂U[:,k-1] + Δt^2/2*((1-β2)*∂∂U[:,k-1]+β2*∂∂U[:,k])
    ∂U[:,k] = ∂U[:,k-1] + Δt*((1-β1)*∂∂U[:,k-1]+β1*∂∂U[:,k])
end



# Set up formatting for the movie files
animation = pyimport("matplotlib.animation")
Writer = animation.writers.avail["ffmpeg"]
writer = Writer(fps=15, bitrate=1800)

fig = figure()
# visualization
scat0 = scatter(nodes[:,1], nodes[:,2], color="k")
grid("on")
ims = Any[(scat0,)]

for k = 1:NT+1
    u1 = U[1:n^2,k] + nodes[:,1]
    u2 = U[n^2+1:end,k] + nodes[:,2]
    # scat.set_offsets([u1 u2])
    # title("Δt = $(round((k-1)*Δt, digits=2))")
    # pause(0.1)

    scat = scatter(u1, u2, color="orange")
    grid("on")
    title("Δt = $(round((k-1)*Δt, digits=2))")
    push!(ims, (scat,scat0))
end

im_ani = animation.ArtistAnimation(fig, ims, interval=50, repeat_delay=3000,
                                   blit=true)
im_ani.save("im.mp4", writer=writer)