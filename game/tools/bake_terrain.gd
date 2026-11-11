extends SceneTree
## Bakes the island heightmap:  godot --headless -s tools/bake_terrain.gd
## Optional: `-- --map=out.png` also writes a top-down preview image.

func _init() -> void:
	var t := Terrain.new()
	var t0 := Time.get_ticks_msec()
	t.generate()
	t.save_baked("res://data/island_height.bin")
	print("baked %d samples in %d ms" % [t.H.size(), Time.get_ticks_msec() - t0])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			var img := Image.create(Terrain.N, Terrain.N, false, Image.FORMAT_RGB8)
			for j in Terrain.N:
				for i in Terrain.N:
					var x := -Terrain.HALF + i * Terrain.CELL
					var z := -Terrain.HALF + j * Terrain.CELL
					var y := t.H[j * Terrain.N + i]
					var c := Color(0.15, 0.4, 0.7)
					if y > 0.0:
						var n := t.normal(x, z)
						c = t._color(x, z, y, n.y) * (0.55 + 0.5 * clampf(n.dot(Vector3(-0.5, 0.7, -0.5).normalized()), 0, 1))
						if int(y / 10.0) != int(t.h(x + 2.5, z) / 10.0):
							c = c.darkened(0.25)
					img.set_pixel(i, j, c)
			img.save_png(a.trim_prefix("--map="))
	t.free()
	quit()
