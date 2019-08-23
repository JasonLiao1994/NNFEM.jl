
using ForwardDiff
using DelimitedFiles
include("ops.jl")
threshold = 1e-4
function nn(ε, ε0, σ0) # ε, ε0, σ0 are all length 3 vector
    local y
    global H0
    if nntype=="linear"
        y = ε*H0*stress_scale
        y
    elseif nntype=="ae_scaled"
        x = [ε/strain_scale ε0/strain_scale σ0/stress_scale]
        if isa(x, Array)
            x = constant(x)
        end
        y = ae(x, [20,20,20,20,3], nntype)*stress_scale
    elseif nntype=="piecewise"
        x = [ε/strain_scale ε0/strain_scale σ0/stress_scale]
        x = constant(x)
        ε = constant(ε)
        ε0 = constant(ε0)
        σ0 = constant(σ0)
        
        H0 = [ 2.50784e11  1.12853e11  0.0       
            1.12853e11  2.50784e11  0.0       
            0.0         0.0         6.89655e10]/stress_scale
        y = ae(x, [20,20,20,20,6], nntype)
        z = tf.reshape(sym_op(y), (-1,3,3))
        σnn = squeeze(tf.matmul(z, tf.reshape((ε-ε0)/strain_scale, (-1,3,1)))) + σ0/stress_scale
        σH = (ε-ε0)/strain_scale * H0 + σ0/stress_scale
        z = sum(ε^2,dims=2)
        i = sigmoid(1e9*(z-(threshold)^2))
        i = [i i i]
        out = σnn .* i + σH .* (1-i)
        out*stress_scale
    else
        error("$nntype does not exist")
    end
end



function sigmoid_(z)

    return 1.0 / (1.0 + exp(-z))
  
end

function nn_helper(ε, ε0, σ0)
    if nntype=="linear"
        x = reshape(reshape(ε,1,3)*H0,3,1)
    elseif nntype=="ae_scaled"
        x = reshape([ε;ε0;σ0/stress_scale],1, 9)
        reshape(nnae_scaled(x)*stress_scale,3,1)
    elseif nntype=="piecewise"
        H0 = [ 2.50784e11  1.12853e11  0.0       
            1.12853e11  2.50784e11  0.0       
            0.0         0.0         6.89655e10]
        ε = ε/strain_scale
        ε0 = ε0/strain_scale
        σ0 = σ0/stress_scale
        x = reshape([ε;ε0;σ0],1, 9)
        y1 = reshape(σ0, 1, 3) + (reshape(ε, 1, 3) - reshape(ε0, 1, 3))*get_matrix(nnae_scaled(x))
        y1 = reshape(y1, 3, 1)*stress_scale
        y2 = reshape(reshape(ε,1,3)*H0,3,1)
        i = sigmoid_(1e9*(norm(ε)^2-(threshold)^2))
        y1 * i + y2 * (1-i)
    else
        error("$nntype does not exist")
    end
end

function post_nn(ε, ε0, σ0, Δt)
    f = x -> nn_helper(x, ε0, σ0)
    df = ForwardDiff.jacobian(f, ε)
    return f(ε), df
end