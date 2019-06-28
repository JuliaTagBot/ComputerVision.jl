using ComputerVision
using Test
using StaticArrays
using GeometryTypes
using LinearAlgebra

points = [Point3(100,100,500), Point3(100,-100,500) , Point3(-100,-100,500) , Point3(-100,100,500)]
world = PrimitiveWorld(points = points)
@inferred PrimitiveWorld()

points = get_points(world)
planes = get_planes(world)
plane = first(planes)
𝐧 = get_normal(plane)
d = get_distance(plane)

# Verify that the default points lie on the plane
𝛑 = push(𝐧, -d) # 𝛑 =[n -d]
for 𝐱 in points
    @test isapprox(dot(𝛑, hom(𝐱)), 0.0; atol = 1e-14)
end

# Verify that the coordinates of the projected points are corrected for the different
# intrinsic coordinate system conventions

camera₁ = ComputerVision.Camera(image_type = AnalogueImage(coordinate_system = OpticalSystem()))
camera₂ = ComputerVision.Camera(image_type = AnalogueImage(coordinate_system = RasterSystem()))
camera₃ = ComputerVision.Camera(image_type = AnalogueImage(coordinate_system = PlanarCartesianSystem()))

aquire = AquireImageContext()

projected_points₁ = aquire(world, camera₁)
@test projected_points₁[1] == Point(-10.0, -10.0)
@test projected_points₁[2] == Point(-10.0, 10.0)
@test projected_points₁[3] == Point(10.0, 10.0)
@test projected_points₁[4] == Point(10.0, -10.0)

projected_points₂ = aquire(world, camera₂)
@test projected_points₂[1] == Point(490.0, 490.0)
@test projected_points₂[2] == Point(490.0, 510.0)
@test projected_points₂[3] == Point(510.0, 510.0)
@test projected_points₂[4] == Point(510.0, 490.0)

projected_points₃ = aquire(world, camera₃)
@test projected_points₃[1] == Point(490.0, 510.0)
@test projected_points₃[2] == Point(490.0, 490.0)
@test projected_points₃[3] == Point(510.0, 490.0)
@test projected_points₃[4] == Point(510.0, 510.0)