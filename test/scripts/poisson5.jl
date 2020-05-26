#=
link to 1, 4
Having computed 
y = h(s)
we want to compute ∇h(s0)
require data4.mat 
save data5.mat
=#
using Revise
using NNFEM
using PoreFlow
using ADCME 
using LinearAlgebra
using PyPlot
using MATLAB
using PyCall
using MAT
include("common1.jl")

ndata = 20
nodes, elems = meshread("$(splitdir(pathof(NNFEM))[1])/../deps/Data/lshape.msh")
elements = []
prop = Dict("name"=> "Scalar1D", "kappa"=>2.0)

for k = 1:size(elems,1)
    elnodes = elems[k,:]
    ngp = 2
    coord = nodes[elnodes,:]
    push!(elements, SmallStrainContinuum(coord, elnodes, prop, ngp))
end


# free boundary on all sides
EBC = zeros(Int64, size(nodes,1))
FBC = zeros(Int64, size(nodes,1))
g = zeros(size(nodes,1))
f = zeros(size(nodes,1))

bd = find_boundary(nodes, elems)
EBC[bd] .= -1

ndims = 1
domain = StaticDomain1(nodes, elements, EBC, g, FBC, f)
init_nnfem(domain)

α = 0.4*π/2
d = [cos(α);sin(α)]
f = (x,y)->300*sin(2π*y + π/8)
fext = compute_body_force_terms1(domain, f)

sol = zeros(domain.nnodes)
xy = getGaussPoints(domain)
x = xy[:,1]
y = xy[:,2]
k = squeeze(fc(xy, [20,20,20,1])) + 2.0

k = vector(1:4:4getNGauss(domain), k, 4getNGauss(domain)) + vector(4:4:4getNGauss(domain), k, 4getNGauss(domain))
k = reshape(k, (getNGauss(domain),2,2))
K = s_compute_stiffness_matrix1(k, domain)
S = K\fext

sol = vector(findall(domain.dof_to_eq), S, domain.nnodes)
dat = matread("data/1_dat.mat")["sol"]


idx = sample_interior(domain.nnodes, ndata, bd)

loss = mean((sol[idx] - dat[idx])^2)

g = Array{PyObject}(undef, ndata)
for i = 1:ndata
    @info i 
    g[i] = gradients(sol[idx[i]], get_collection())
end
sess = Session(); init(sess)
ADCME.load(sess, "data/4.mat")
@info run(sess, loss)

G = run(sess, g)
matwrite("data/5.mat", Dict(
    "G"=>G
))


