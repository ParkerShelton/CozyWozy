# world_noise.gd
extends Node

var lake_noise = null
var river_noise = null

var lake_threshold: float = -0.35
var river_threshold: float = 0.035

func initialize(world_seed: int):
	lake_noise = FastNoiseLite.new()
	lake_noise.seed = world_seed
	lake_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	lake_noise.frequency = 0.005
	
	river_noise = FastNoiseLite.new()
	river_noise.seed = world_seed + 99999
	river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	river_noise.frequency = 0.003
	river_noise.domain_warp_enabled = true
	river_noise.domain_warp_amplitude = 40.0
	river_noise.domain_warp_frequency = 0.008

func is_water(world_x: float, world_z: float) -> bool:
	return is_lake(world_x, world_z) or is_river(world_x, world_z)

func is_lake(world_x: float, world_z: float) -> bool:
	return lake_noise.get_noise_2d(world_x, world_z) < lake_threshold

func is_river(world_x: float, world_z: float) -> bool:
	var value = river_noise.get_noise_2d(world_x, world_z)
	return abs(value) < river_threshold
