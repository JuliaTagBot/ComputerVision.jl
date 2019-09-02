using ComputerVision
using Test
using StaticArrays
using GeometryTypes
using LinearAlgebra
using PGFPlotsX
using Makie
using Colors

# Generate points on two planar surfaces
x₁ = 0.0
x₁′ = 0.0
y₁ = -1000.0
y₁′ = 2000.0
z₁ = -1000.0
z₁′ = 1000.0
points₁ = [Point3(rand(x₁:x₁′), rand(y₁:y₁′), rand(z₁:z₁′)) for n = 1:250]
plane₁ = [Plane(Vec3(1.0, 0.0, 0.0), 0)]
p₁ = [x₁, y₁, z₁]
q₁ = [x₁, y₁′, z₁]
r₁ = [x₁, y₁′, z₁′]
s₁ = [x₁, y₁, z₁′]
segment₁ = [p₁ => q₁ , q₁ => r₁ , r₁ => s₁ , s₁ => p₁]
plane_segment₁ = PlaneSegment(first(plane₁), segment₁)

x₂ = 0.0
x₂′ = 3000.0
y₂ = 2000.0
y₂′ = 2000.0
z₂ = -1000.0
z₂′ = 1000.0
points₂ = [Point3(rand(x₂:x₂′), rand(y₂:y₂′), rand(z₂:z₂′)) for n = 1:250]
plane₂ = [Plane(Vec3(0.0, 1.0, 0.0), 2000)]
p₂ = [x₂, y₂, z₂]
q₂ = [x₂, y₂, z₂′]
r₂ = [x₂′, y₂, z₂′]
s₂ = [x₂′, y₂, z₂]
segment₂ = [p₂ => q₂ , q₂ => r₂ , r₂ => s₂ , s₂ => p₂]
plane_segment₂ = PlaneSegment(first(plane₂), segment₂)

planes = vcat(plane₁, plane₂)
#planes = vcat(plane_segment₁, plane_segment₂)
points = vcat(points₁, points₂)

groups = [IntervalAllotment(1:250), IntervalAllotment(251:500)]

world = PrimitiveWorld(points = points, planes = planes, groups = groups)

pinhole₁ = Pinhole(intrinsics = IntrinsicParameters(width = 640, height = 480, focal_length = 100))
analogue_image₁ = AnalogueImage(coordinate_system = OpticalSystem())
camera₁ = ComputerVision.Camera(image_type = analogue_image₁, model = pinhole₁)
𝐑₁ = SMatrix{3,3,Float64,9}(rotxyz(90*(pi/180), -110*(pi/180), 0*(pi/180)))
𝐭₁ = [3000.0,0.0, 0.0]
relocate!(camera₁, 𝐑₁, 𝐭₁)

pinhole₂ = Pinhole(intrinsics = IntrinsicParameters(width = 640, height = 480, focal_length = 100))
analogue_image₂ = AnalogueImage(coordinate_system = OpticalSystem())
camera₂ = ComputerVision.Camera(image_type = analogue_image₂, model = pinhole₂)
𝐑₂ = SMatrix{3,3,Float64,9}(rotxyz(90*(pi/180), -110*(pi/180), 0*(pi/180)))
𝐭₂ = [4000.0,0.0, 0.0]
relocate!(camera₂, 𝐑₂, 𝐭₂)


aquire = AquireImageContext()

# Project 3D points onto the cameras.
ℳ = aquire(world, camera₁)
ℳ′ = aquire(world, camera₂)

cameraₐ  = deepcopy(camera₁)
cameraᵦ  = deepcopy(camera₂)
world₂ = deepcopy(world)

default_world_system = CartesianSystem(Point(0.0, 0.0, 0.0), Vec(1.0, 0.0, 0.0), Vec(0.0, 1.0, 0.0), Vec(0.0, 0.0, 1.0))
alternative_world_system = get_coordinate_system(get_extrinsics(get_model(camera₁)))

transformation_context! = WorldCoordinateTransformationContext(CoordinateTransformation(source = default_world_system, target = alternative_world_system))
transformation_context!(cameraₐ)
transformation_context!(cameraᵦ)
transformation_context!(world₂)

# Project transformed 3D points onto the cameras.
ℳₐ = aquire(world₂, cameraₐ)
ℳᵦ′ = aquire(world₂, cameraᵦ)


# Verify that the coordinates of the image points are the same irrespective
# of the choice of the world coordinate system.
for couple in zip(ℳ, ℳₐ)
    @test isapprox(norm(first(couple)-last(couple)), 0.0; atol = 1e-10)
end
for couple in zip(ℳ′, ℳᵦ′)
    @test isapprox(norm(first(couple)-last(couple)), 0.0; atol = 1e-10)
end

# Verify that the original 3D points lie on their corresponding planes.
points3D = get_points(world)
planes3D = get_planes(world)
for (i, plane3D) in enumerate(planes3D)
    subset = points3D[get_interval(groups[i])]
    for pt in subset
        @test on_plane(pt, plane3D; tol = 1e-10)
    end
end

# Verify that the transformed 3D points lie on their corresponding transformed planes.
points3Dᵦ = get_points(world₂)
planes3Dᵦ = get_planes(world₂)
for (i, plane3Dᵦ) in enumerate(planes3Dᵦ)
    subset = points3Dᵦ[get_interval(groups[i])]
    for pt in subset
        @test on_plane(pt, plane3Dᵦ; tol = 1e-10)
    end
end

# Verify that the fundamental matrices are the same irrespective of how we choose
# the world coordinate system.
𝐅₁ = matrix(FundamentalMatrix(camera₁, camera₂))
𝐅₁ = 𝐅₁ / norm(𝐅₁)
𝐅₂ = matrix(FundamentalMatrix(cameraₐ, cameraᵦ))
𝐅₂ = 𝐅₂ / norm(𝐅₂)
@test norm(𝐅₁ - 𝐅₂) < 1e-15


# Verify that the homography matrices are the same irrespective of how we choose
# the world coordinate system.
ℋ = matrices(HomographyMatrices(camera₁, camera₂, get_planes(world)))
𝐇₁ = ℋ[1] / norm(ℋ[1])
𝐇₁ = 𝐇₁ / sign(𝐇₁[end])
𝐇₂ = ℋ[2] / norm(ℋ[2])
𝐇₂ = 𝐇₂ / sign(𝐇₂[end])

ℋ₂ = matrices(HomographyMatrices(cameraₐ, cameraᵦ, get_planes(world₂)))
𝐇ₐ = ℋ₂[1] / norm(ℋ₂[1])
𝐇ₐ = 𝐇ₐ  / sign(𝐇ₐ[end])
𝐇ᵦ = ℋ₂[2] / norm(ℋ₂[2])
𝐇ᵦ = 𝐇ᵦ  / sign(𝐇ᵦ[end])

@test norm(𝐇₁ .- 𝐇ₐ) < 1e-15
@test norm(𝐇₂ .- 𝐇ᵦ) < 1e-15

# Verify that the homographies are compatible with the projected points
for (i, group) in enumerate(groups)
    allotment = get_interval(group)
    for corresponding_pair in zip(ℳ[allotment], ℳ′[allotment])
        𝐇ᵢ = ℋ[i]
        𝐦 = corresponding_pair[1]
        𝐦′  = hom⁻¹(𝐇ᵢ * hom(𝐦))
        @test isapprox(norm(𝐦′ - corresponding_pair[2]), 0.0; atol = 1e-10)
    end
end


# Verify that the points are triangulated correctly for both choices of
# world coordinate systems.
𝒞₁ = Correspondences((ℳ,ℳ′))
triangulate_points =  TriangulateContext(DirectLinearTriangulation())
estimated_points₁ = triangulate_points(camera₁, camera₂, 𝒞₁)
# Verify that the triangulated points are close to the true points.
for couple in zip(estimated_points₁, get_points(world))
    @test isapprox(norm(first(couple)-last(couple)), 0.0; atol = 1e-7)
end

𝒞₂ = Correspondences((ℳₐ,ℳᵦ′))
triangulate_points =  TriangulateContext(DirectLinearTriangulation())
estimated_points₂ = triangulate_points(cameraₐ, cameraᵦ, 𝒞₂)
# Verify that the triangulated points are close to the true points.
for couple in zip(estimated_points₂, get_points(world₂))
    @test isapprox(norm(first(couple)-last(couple)), 0.0; atol = 1e-7)
end


extract_pose = PoseFromSingleHomographyContext(intrinsics = get_intrinsics(get_model(cameraₐ)), image_type = analogue_image₁, algorithm = MalisVargasDecomposition())

for (i, group) in enumerate(groups)
    # Obtain the ground truth
    relative_pose = RelativePose(cameraₐ, cameraᵦ)
    R = ComputerVision.rotation(relative_pose)
    t = ComputerVision.translation(relative_pose)
    planes = get_planes(world₂)
    plane = planes[i]
    𝐧 = get_normal(plane)
    d = get_distance(plane)
    # Convention used by Malis and Vargas in their homography decomposition paper.
    𝐑 = R'
    𝐭 = (-R'*t) / d

    # Extract the corresponding points associated with the current plane
    allotment = get_interval(groups[i])
    𝒞 = Correspondences((ℳₐ[allotment],ℳᵦ′[allotment]))

    # Construct two potential solutions
    potential_poses = extract_pose(HomographyMatrix(cameraₐ, cameraᵦ, plane), 𝒞)
    # One of the poses should correspond with the truth (taking into account numerical errors)
    A₁, b₁, v₁ =  potential_poses[1]
    A₂, b₂, v₂ =  potential_poses[2]
    test₁ = norm(A₁ - 𝐑) < 1e-7 && norm(b₁ - 𝐭) < 1e-7 && norm(v₁ - 𝐧) < 1e-7
    test₂ = norm(A₂ - 𝐑) < 1e-7 && norm(b₂ - 𝐭) < 1e-7 && norm(v₂ - 𝐧) < 1e-7
    @test test₁ || test₂
end



relative_pose = RelativePose(cameraₐ, cameraᵦ)
R = ComputerVision.rotation(relative_pose)
t = ComputerVision.translation(relative_pose)
planes = get_planes(world₂)
plane = planes[1]
𝐧 = get_normal(plane)
d = get_distance(plane)
# Convention used by Malis and Vargas in their homography decomposition paper.
𝐑 = R'
𝐭 = (-R'*t) / d


allotment₁ = get_interval(groups[1])
𝒞₁ = Correspondences((ℳₐ[allotment₁],ℳᵦ′[allotment₁]))
valid_poses = extract_pose(HomographyMatrix(cameraₐ, cameraᵦ, first(get_planes(world₂))), 𝒞₁)
A, b, v = valid_poses[1]
Aₚ = A'
bₚ = -A' * b * d


#
#
# # One of the valid poses should correspond with the truth (taking into account numerical errors)
# A₁, b₁, v₁ =  valid_poses[1]
# A₂, b₂, v₂ =  valid_poses[2]
# test₁ = norm(A₁ - 𝐑) < 1e-7 && norm(b₁ - 𝐭) < 1e-7 && norm(v₁ - 𝐧) < 1e-7
# test₂ = norm(A₂ - 𝐑) < 1e-7 && norm(b₂ - 𝐭) < 1e-7 && norm(v₂ - 𝐧) < 1e-7
# @test test₁ || test₂
#
# # Second plane?
# relative_pose = RelativePose(cameraₐ, cameraᵦ)
# R = ComputerVision.rotation(relative_pose)
# t = ComputerVision.translation(relative_pose)
# planes = get_planes(world₂)
# plane = planes[2]
# 𝐧 = get_normal(plane)
# d = get_distance(plane)
# # Convention used by Malis and Vargas in their homography decomposition paper.
# 𝐑 = R'
# 𝐭 = (-R'*t) / d
#
# 𝐧
#
# extract_pose = PoseFromSingleHomographyContext(intrinsics = get_intrinsics(get_model(cameraₐ)), image_type = analogue_image₁, algorithm = MalisVargasDecomposition(), use_outward_normal_convention = true)
# poses = extract_pose(HomographyMatrix(cameraₐ, cameraᵦ, last(get_planes(world₂))), 𝒞₂)
# poses
#
# allotment₂ = get_interval(groups[2])
# 𝒞₂ = Correspondences((ℳₐ[allotment₂],ℳᵦ′[allotment₂]))
# 𝒞₂ = Correspondences((ℳₐ,ℳᵦ′))
# #valid_poses = determine_pose(HomographyMatrix(cameraₐ, cameraᵦ, last(get_planes(world₂))), 𝒞₂)
#
#
# # One of the valid poses should correspond with the truth (taking into account numerical errors)
# A₁, b₁, v₁ =  valid_poses[1]
# A₂, b₂, v₂ =  valid_poses[2]
# test₁ = norm(A₁ - 𝐑) < 1e-7 && norm(b₁ - 𝐭) < 1e-7 && norm(v₁ - 𝐧) < 1e-7
# test₂ = norm(A₂ - 𝐑) < 1e-7 && norm(b₂ - 𝐭) < 1e-7 && norm(v₂ - 𝐧) < 1e-7
# @test test₁ || test₂
#
#
# poses
#
# 𝐊 = to_matrix(get_intrinsics(get_model(cameraₐ)), OpticalSystem())
# 𝐆 = 𝐊*(𝐑 + 𝐭*𝐧')*inv(𝐊)
# 𝐆 = 𝐆 / norm(𝐆)
# 𝐆 = 𝐆 / sign(𝐆[end])
# 𝐇₁ = 𝐇₁ / sign(𝐇₁[end])
# 𝐇ₐ = 𝐇ₐ  / sign(𝐇ₐ[end])
# @test norm(𝐇₁ .- 𝐆) < 1e-15
# @test norm(𝐇ₐ .- 𝐆) < 1e-15
#
#
# 𝐧
# 𝐭
#
#
#
#
#
#
# #poses = determine_pose(HomographyMatrix(cameraₐ, cameraᵦ, first(get_planes(world₂))))
#
#
# for pose in poses
#     A, b, v =  pose
#     @show 1 + v'*A'*b
# end
#
# valid_poses
#
#
#
# poses
# #
# # poses₂ = determine_pose(HomographyMatrix(cameraₐ, cameraᵦ, last(get_planes(world₂))))
# #
# # ascertain_pose(cameraᵦ, default_world_system)
# #
# #
# #
# # analogue_image₁
# #
# # valid_poses = determine_pose(HomographyMatrix(cameraₐ, cameraᵦ, first(get_planes(world₂))), Correspondences((ℳₐ,ℳᵦ′)))
# #
# # valid_poses
# #
# # poses
#
#
#
#
#
# poses₂
