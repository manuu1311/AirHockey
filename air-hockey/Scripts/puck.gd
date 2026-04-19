extends RigidBody2D

@export var startingPos: Vector2

func reset():
	linear_velocity=Vector2.ZERO
	angular_velocity=0
	position=startingPos
	
