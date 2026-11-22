@Serialize
class_name SaveHero
extends SavePlayer

var mana := 2


static func sample() -> SaveHero:
	var hero := SaveHero.new()
	hero.hp = 7
	hero.name_label = "Bea"
	hero.secret = "keep"
	hero.mana = 4
	hero.ratio = 1.5
	hero.spot = Vector2(1.5, -2)
	hero.where = Vector3(1, 0, -3.5)
	hero.tint = Color(0.25, 0.5, 0.75, 1)
	hero.path = NodePath("Body/Hand")
	hero.tag = &"hero"
	hero.flags = [1, true, "a"]
	hero.meta = {"slot": "bag", "n": 2}
	var item := SaveWeapon.new()
	item.damage = 9
	item.note = "skip"
	hero.weapon = item
	return hero
