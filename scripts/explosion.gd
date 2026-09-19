class_name Explosion
extends Node3D

@onready var fire_particles: CPUParticles3D = $FireParticles
@onready var spark_particles: CPUParticles3D = $SparkParticles
@onready var smoke_particles: CPUParticles3D = $SmokeParticles
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var blast_light: OmniLight3D = $BlastLight

var _time: float = 0.0

func _ready() -> void:
	if fire_particles:
		fire_particles.emitting = true
	if spark_particles:
		spark_particles.emitting = true
	if smoke_particles:
		smoke_particles.emitting = true

	if SoundManager.instance:
		SoundManager.instance.play_crash()

	var cam = get_viewport().get_camera_3d() as CameraFollow
	if cam:
		cam.add_trauma(0.6)

	var tween = create_tween()
	tween.tween_property(blast_light, "light_energy", 0.0, 0.5)
	tween.parallel().tween_property(shockwave, "scale", Vector3(12, 0.1, 12), 0.45)
	tween.tween_callback(queue_free).set_delay(0.8)
