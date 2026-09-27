extends Node2D

@export var color: String
var matched: bool = false
var treasured: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func move(target: Vector2) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.3)
	await tween.finished

func dim():
	$Sprite2D.modulate.a = 0.5 # $Sprite is short hand for get_node("Sprite)
