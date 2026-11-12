class_name LightMeter
extends RefCounted
## How lit a spot is, 0 (dark) to 1 (in a lamp's pool), worked out from the level's lights in code rather than read
## from the GPU, so it's the same on the Deck, on the PC and in headless probes (WO-005: "a light probe at Nim").
##
## Omni and spot lights count by distance (a squared falloff to their range) and only if nothing's between them and
## the spot. A directional light (the moon) counts if the spot isn't in its shadow. Ambient light doesn't count:
## that's what darkness is.

## How much a directional light's energy is worth (the moon lights everything a little; a lamp pool is what's bright).
const DIRECTIONAL_WEIGHT := 0.6
## Lights dimmer than this at the spot aren't worth a shadow ray.
const NEGLIGIBLE := 0.02
## Hits this close to a light are its own lamp or post.
const FIXTURE := 0.6


## The light at `at`. `lights` are the level's Light3D nodes; `exclude` are bodies that don't cast shadows here (Nim).
static func measure(at: Vector3, lights: Array, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> float:
	var total := 0.0
	for item: Variant in lights:
		# A light can be freed between refreshes (a collected Key's glow): check before treating it as a light.
		if not is_instance_valid(item):
			continue
		var l := item as Light3D
		if l == null or not l.is_visible_in_tree():
			continue
		var amount := 0.0
		var from := Vector3.ZERO
		if l is DirectionalLight3D:
			amount = l.light_energy * DIRECTIONAL_WEIGHT
			from = at + l.global_basis.z * 200.0   # back up the beam toward the light
		elif l is OmniLight3D or l is SpotLight3D:
			var r: float = l.get(&"omni_range") if l is OmniLight3D else l.get(&"spot_range")
			var d := at.distance_to(l.global_position)
			if d >= r:
				continue
			if l is SpotLight3D:
				var cone := deg_to_rad(float(l.get(&"spot_angle")))
				if (-l.global_basis.z).angle_to(at - l.global_position) > cone:
					continue
			var f := 1.0 - d / r
			amount = l.light_energy * f * f
			from = l.global_position
		if amount < NEGLIGIBLE:
			continue
		# Cast from the spot toward the light; a hit right at the light is its own fixture (a lamp post), not a shadow.
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, from, 1, exclude))
		if hit.is_empty() or (hit.position as Vector3).distance_to(from) < FIXTURE:
			total += amount
	return clampf(total, 0.0, 1.0)
