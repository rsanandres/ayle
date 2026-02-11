class_name ObjectSpriteSetup
## Utility to create placeholder pixel art sprites for objects.

static func create_desk_texture() -> ImageTexture:
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	# Table top (brown)
	var brown := Color(0.55, 0.35, 0.17)
	var dark_brown := Color(0.4, 0.25, 0.1)
	for x in range(24):
		for y in range(0, 4):
			img.set_pixel(x, y, brown)
	# Legs
	for y in range(4, 16):
		img.set_pixel(1, y, dark_brown)
		img.set_pixel(2, y, dark_brown)
		img.set_pixel(21, y, dark_brown)
		img.set_pixel(22, y, dark_brown)
	# Monitor on desk
	var gray := Color(0.3, 0.3, 0.35)
	var screen := Color(0.4, 0.6, 0.8)
	for x in range(8, 16):
		for y in range(0, 3):
			img.set_pixel(x, y, gray)
	for x in range(9, 15):
		img.set_pixel(x, 1, screen)
	return ImageTexture.create_from_image(img)


static func create_coffee_machine_texture() -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	var body := Color(0.3, 0.3, 0.3)
	var accent := Color(0.8, 0.2, 0.15)
	# Machine body
	for x in range(2, 12):
		for y in range(2, 12):
			img.set_pixel(x, y, body)
	# Red accent top
	for x in range(3, 11):
		img.set_pixel(x, 2, accent)
		img.set_pixel(x, 3, accent)
	# Cup area
	var white := Color(0.9, 0.9, 0.85)
	for x in range(5, 9):
		for y in range(8, 11):
			img.set_pixel(x, y, white)
	return ImageTexture.create_from_image(img)


static func create_couch_texture() -> ImageTexture:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var cushion := Color(0.3, 0.45, 0.65)
	var frame := Color(0.25, 0.35, 0.5)
	# Back rest
	for x in range(1, 31):
		for y in range(2, 6):
			img.set_pixel(x, y, frame)
	# Seat cushions
	for x in range(1, 31):
		for y in range(6, 12):
			img.set_pixel(x, y, cushion)
	# Arm rests
	for y in range(3, 12):
		img.set_pixel(0, y, frame)
		img.set_pixel(31, y, frame)
	# Legs
	var dark := Color(0.2, 0.2, 0.2)
	for x in [2, 3, 28, 29]:
		for y in range(12, 15):
			img.set_pixel(x, y, dark)
	return ImageTexture.create_from_image(img)
