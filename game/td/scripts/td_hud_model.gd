@Model
@RunScope
@Eager
@Component
class_name TdHudModel
extends RefCounted

## HUD state for Bindings. Wallet / waves / towers push values here.

@Property
var gold_text: String = "Gold: 0"

@Property
var lives_text: String = "Lives: 0"

@Property
var wave: String = "Wave: 1"

@Property
var status: String = "Build"

@Property
var upgrade: String = "Upgrade"
