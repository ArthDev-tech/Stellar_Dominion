class_name AsteroidBelt
extends RefCounted
## An asteroid belt in a star system.

var id: int
var name_key: String
var inner_radius: float
var outer_radius: float
var significant_asteroids: int  ## Number of notable / mineable asteroids
## Resource deposits (monthly yield when mined). Array of { "resource_type": int, "amount": float }
var deposits: Array = []


func _init(
	p_id: int = 0,
	p_name_key: String = "",
	p_inner_radius: float = 120.0,
	p_outer_radius: float = 160.0,
	p_significant_asteroids: int = 0
) -> void:
	id = p_id
	name_key = p_name_key
	inner_radius = p_inner_radius
	outer_radius = p_outer_radius
	significant_asteroids = p_significant_asteroids
