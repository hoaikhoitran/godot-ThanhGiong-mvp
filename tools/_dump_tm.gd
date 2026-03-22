extends SceneTree
func _init() -> void:
  var t = ClassDB.class_get_property_list("TileMap")
  for p in t: print(p.name if p is Dictionary else p)
  quit()
