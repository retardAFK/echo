class_name HitscanShot
extends RefCounted
## The rays of a Versus shot (spec S-025, Q2, T-403), pure: where each
## pellet goes, and what it deals.


## The directions of pellets rays around aim, each within spread degrees of
## it (uniform over the disc of the cone), drawn with rng.
static func directions(
	aim: Vector3, pellets: int, spread: float, rng: RandomNumberGenerator
) -> Array[Vector3]:
	var forward := aim.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.01:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var result: Array[Vector3] = []
	for i in maxi(pellets, 1):
		var radius := tan(deg_to_rad(spread)) * sqrt(rng.randf())
		var angle := rng.randf() * TAU
		var offset := side * cos(angle) * radius + up * sin(angle) * radius
		result.append((forward + offset).normalized())
	return result


## Damage and poise of a pellet of weapon, in the face or not, as
## [damage, poise].
static func hit_of(weapon: VersusWeapon, face: bool) -> Array[float]:
	if face:
		return [weapon.damage * weapon.face_multiplier, weapon.face_poise]
	return [weapon.damage, weapon.poise]
