abstract type AbstractTriangulationAlgorithm end

struct DirectLinearTriangulation <: AbstractTriangulationAlgorithm end


struct TriangulateContext{T <: AbstractTriangulationAlgorithm} <: AbstractContext
    algorithm::T
end

function (context::TriangulateContext)(camera₁::AbstractCamera, camera₂::AbstractCamera, correspondences::AbstractCorrespondences)
    context(camera₁, camera₂, correspondences)
end

function (algorithm::DirectLinearTriangulation)(camera₁::AbstractCamera, camera₂::AbstractCamera, correspondences::AbstractCorrespondences)
    algorithm(Projection(camera₁, world_system), Projection(camera₂, world_system))
end

# function (algorithm::DirectLinearTriangulation)(fundamental_matrix::FundamentalMatrix, correspondences::AbstractCorrespondences)
#     # TODO
# end

function (algorithm::DirectLinearTriangulation)(essential_matrix::EssentialMatrix, correspondences::AbstractCorrespondences)
    projection₁, projection₂₁, projection₂₂, projection₂₃, projection₂₄ = essential_matrix_to_projections(essential_matrix::EssentialMatrix)
    𝒳₁ = algorithm(projection₁, projection₂₁, correspondences)
    𝒳₂ = algorithm(projection₁, projection₂₂, correspondences)
    𝒳₃ = algorithm(projection₁, projection₂₃, correspondences)
    𝒳₄ = algorithm(projection₁, projection₂₄, correspondences)
    # Determine which projection matrix in the second view triangulated
    # the majority of points in front of the cameras.
    ℳ₁ = map(𝒳₁) do 𝐗
        𝐦 = 𝐏₂₁ * 𝐗
        𝐦[3] > 0
    end

    ℳ₂ = map(𝒳₂) do 𝐗
        𝐦 = 𝐏₂₂ * 𝐗
        𝐦[3] > 0
    end

    ℳ₃ = map(𝒳₃) do 𝐗
        𝐦 = 𝐏₂₃ * 𝐗
        𝐦[3] > 0
    end

    ℳ₄ = map(𝒳₄) do 𝐗
        𝐦 = 𝐏₂₄ * 𝐗
        𝐦[3] > 0
    end

    total, index = findmax((sum(ℳ₁), sum(ℳ₂), sum(ℳ₃), sum(ℳ₄)))

    if index == 1
        return 𝒳₁
    elseif index == 2
        return 𝒳₂
    elseif index == 3
        return 𝒳₃
    else
        return 𝒳₄
    end
end

function (algorithm::DirectLinearTriangulation)(projection₁::Projection, projection₂::Projection, correspondences::AbstractCorrespondences)
    𝐏₁ = matrix(projection₁)
    𝐏₂ = matrix(projection₂)
    ℳ = correspondences[1]
    ℳ′ = correspondences[2]
    N = length(ℳ)
    𝒴 = [ linear_triangulate(𝐏₁, 𝐏₂, ℳ[n], ℳ′[n]) for n = 1:N]
end

function essential_matrix_to_projections(essential_matrix::EssentialMatrix)
    𝐄 = matrix(essential_matrix)
    𝐖 = SMatrix{3,3,Float64,3*3}([0 -1 0; 1 0 0; 0 0 1])
    𝐙 = SMatrix{3,3,Float64,3*3}([0 1 0; -1 0 0; 0 0 0])
    𝐔,𝐒,𝐕 = svd(𝐄)
    𝐭 = 𝐔[:,3]
    𝐏₁ = SMatrix{3,4,Float64,3*4}(1.0I)
    𝐏₂₁ = SMatrix{3,4,Float64,3*4}([𝐔*𝐖*𝐕'  𝐭])
    𝐏₂₂ = SMatrix{3,4,Float64,3*4}([𝐔*𝐖'*𝐕' 𝐭])
    𝐏₂₃ = SMatrix{3,4,Float64,3*4}([𝐔*𝐖*𝐕' -𝐭])
    𝐏₂₄ = SMatrix{3,4,Float64,3*4}([𝐔*𝐖'*𝐕' -𝐭])
    Projection(𝐏₁), Projection(𝐏₂₁), Projection(𝐏₂₂), Projection(𝐏₂₃), Projection(𝐏₂₄)
end

function linear_triangulate(𝐏₁::AbstractMatrix, 𝐏₂::AbstractMatrix, 𝐦::AbstractVector, 𝐦′::AbstractVector)
    eq1 = 𝐦[1] * 𝐏₁[3,:] - 𝐏₁[1,:]
    eq2 = 𝐦[2] * 𝐏₁[3,:] - 𝐏₁[2,:]
    eq3 = 𝐦′[1] * 𝐏₂[3,:] - 𝐏₂[1,:]
    eq4 = 𝐦′[2] * 𝐏₂[3,:] - 𝐏₂[2,:]
    𝐀 = SMatrix{4,4}(transpose(hcat(eq1,eq2,eq3,eq4)))
    F = svd(𝐀)
    Point(hom⁻¹(F.Vt[4,:]))
end