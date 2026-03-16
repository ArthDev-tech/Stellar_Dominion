class_name StarSystem
extends RefCounted
## A star system: position on galaxy map, star type, planets, and asteroid belts.

enum StarType {
	M, K, G, F, A, B, O,
	BLACK_HOLE,
	PULSAR,
	NEUTRON_STAR,
}

var id: int
var name_key: String
var position: Vector2  ## 2D position on galaxy map
var star_type: StarType
var planets: Array[Planet] = []
var asteroid_belts: Array[AsteroidBelt] = []
## Star-level deposits (e.g. energy from star). Array of { "resource_type": int, "amount": float }
var star_deposits: Array = []


func _init(
	p_id: int = 0,
	p_name_key: String = "",
	p_position: Vector2 = Vector2.ZERO,
	p_star_type: StarType = StarType.G
) -> void:
	id = p_id
	name_key = p_name_key
	position = p_position
	star_type = p_star_type


func add_planet(planet: Planet) -> void:
	planets.append(planet)


func add_asteroid_belt(belt: AsteroidBelt) -> void:
	asteroid_belts.append(belt)


func is_special_star() -> bool:
	return star_type == StarType.BLACK_HOLE or star_type == StarType.PULSAR or star_type == StarType.NEUTRON_STAR
