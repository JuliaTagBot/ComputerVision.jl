using ComputerVision
using Test
using StaticArrays
using GeometryTypes
using LinearAlgebra
using Colors

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

planes = vcat(plane_segment₁, plane_segment₂)
points = vcat(points₁, points₂)

groups = [IntervalAllotment(1:250), IntervalAllotment(251:500)]

world = PrimitiveWorld(points = points, planes = planes, groups = groups)
@inferred PrimitiveWorld()

points = get_points(world)

planes = get_planes(world)

pinhole₁ = Pinhole(intrinsics = IntrinsicParameters(width = 640, height = 480, focal_length = 100))
analogue_image₁ = AnalogueImage(coordinate_system = OpticalSystem())
camera₁ = ComputerVision.Camera(image_type = analogue_image₁, model = pinhole₁)
𝐑₁ = SMatrix{3,3,Float64,9}(rotxyz(90*(pi/180), -130*(pi/180), 0*(pi/180)))
𝐭₁ = [3000.0,0.0, 0.0]
relocate!(camera₁, 𝐑₁, 𝐭₁)


pinhole₂ = Pinhole(intrinsics = IntrinsicParameters(width = 640, height = 480, focal_length = 150))
analogue_image₂ = AnalogueImage(coordinate_system = OpticalSystem())
camera₂ = ComputerVision.Camera(image_type = analogue_image₂, model = pinhole₂)
𝐑₂ = SMatrix{3,3,Float64,9}(rotxyz(90*(pi/180), -110*(pi/180), 0*(pi/180)))
𝐭₂ = [4000.0,0.0, 0.0]
relocate!(camera₂, 𝐑₂, 𝐭₂)

aquire = AquireImageContext()
ℳ = aquire(world, camera₁)
ℳ′ = aquire(world, camera₂)

𝐅 = matrix(FundamentalMatrix(camera₁, camera₂))
𝐅 = 𝐅 / norm(𝐅)

𝐇 = matrix(HomographyMatrix(camera₁, camera₂, first(plane₁)))
𝐇 = 𝐇 / norm(𝐇)

𝐇₂ = matrix(HomographyMatrix(camera₁, camera₂, first(plane₂)))
𝐇₂ = 𝐇₂ / norm(𝐇₂)

s₁ = [vec2antisym(hom(ℳ′[i])) * 𝐇  * hom(ℳ[i]) for i = 1:250]
s₂ = [vec2antisym(hom(ℳ′[i])) * 𝐇₂  * hom(ℳ[i]) for i = 251:500]

𝐫₁ = 𝐇'*𝐅 + 𝐅'*𝐇
𝐫₂ = 𝐇₂'*𝐅 + 𝐅'*𝐇₂


@test all(isapprox.(𝐫₁, 0.0; atol = 1e-14))
@test all(isapprox.(𝐫₂, 0.0; atol = 1e-14))

for 𝐱 in s₁
    @test all(isapprox.(𝐱, [0.0, 0.0, 0.0] ; atol = 1e-12))
end

for 𝐱 in s₂
    @test all(isapprox.(𝐱, [0.0, 0.0, 0.0] ; atol = 1e-12))
end
