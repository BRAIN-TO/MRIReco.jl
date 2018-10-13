export ExplicitOp

mutable struct ExplicitOp{T} <: AbstractLinearOperator{T}
  nrow :: Int
  ncol :: Int
  symmetric :: Bool
  hermitian :: Bool
  prod :: Function
  tprod :: Union{Function,Nothing}
  ctprod :: Union{Function,Nothing}
  inv :: Union{Function,Nothing}
  density
end

#
# Linear Operator to perform explicite reconstruction
#
function ExplicitOp(shape::Tuple, tr::AbstractTrajectory, correctionmap::Matrix
                        ; method="nfft"
                        , symmetrize=true
                        , alpha::Float64=1.75
                        , m::Float64=4.0)

  nodes,times = kspaceNodes(tr), readoutTimes(tr)
  nrow = size(nodes,2)
  ncol = prod(shape)

  plan = NFFTPlan(nodes, shape, 4, 1.75)
  density = convert(Vector{Float64}, sdc(plan))

  return ExplicitOp{ComplexF64}(nrow, ncol, false, false
            , x->produ(x, nrow, ncol, shape, plan, correctionmap, density, symmetrize)
            , nothing
            , y->ctprodu(y, shape, plan, correctionmap, density, symmetrize)
            , y->ctprodu(y, shape, plan, correctionmap, density, symmetrize)
            , density )
end

function produ{T<:ComplexF64}(x::Vector{T}, numOfNodes::Int, numOfPixel::Int,
                     shape::Tuple, plan, correctionmap, density, symmetrize::Bool)
   if symmetrize
       x = x .* sqrt(density)
   end

   if isempty(correctionmap)
       disturbanceTerm = zeros(ComplexF64,shape...)
   else
       disturbanceTerm = correctionmap
   end

   out = zeros(ComplexF64,shape)
   for nx=1:shape[1]
       for ny=1:shape[2]
           for k=1:length(kdata)
               phi = (nodes[1,k]*(nx-shape[1]/2-1)+
                      nodes[2,k]*(ny-shape[2]/2-1))
               e = exp(2*1im*pi*phi - times[k]*disturbanceTerm[nx,ny])
               out[nx,ny] += x[k] * conj(e)
           end
       end
   end
   return vec(out)
end

function ctprodu{T<:ComplexF64}(x::Vector{T}, shape::Tuple, plan, correctionmap,
               density, symmetrize::Bool)

  if symmetrize
      x = x .* sqrt(density) # <- using for FISTA
  end

  if isempty(correctionmap)
      disturbanceTerm = zeros(ComplexF64,shape...)
  else
      disturbanceTerm = correctionmap
  end

  out = zeros(ComplexF64,shape)
  for nx=1:shape[1]
      for ny=1:shape[2]
          for k=1:length(kdata)
              phi = (nodes[1,k]*(nx-shape[1]/2-1)+
                     nodes[2,k]*(ny-shape[2]/2-1))
              e = exp(-2*1im*pi*phi - times[k]*disturbanceTerm[nx,ny])
              out[nx,ny] += x[k] * conj(e)
          end
      end
  end
  return vec(out)
end
