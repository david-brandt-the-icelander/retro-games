class_name Pal
## The game's 16-colour cartoon palette. Every colour in the game comes from this list
## (the names are the classic 16-colour slots), which keeps code-drawn art and AI art consistent.

const BLACK := Color("2a2230")     # ink: outlines, tyres, text
const BLUE := Color("3466c2")
const GREEN := Color("4c9a3c")
const CYAN := Color("3fb6c4")
const RED := Color("d6453d")
const MAGENTA := Color("a24ab0")
const BROWN := Color("a8662c")
const LGRAY := Color("c9c6c0")
const DGRAY := Color("6b6670")
const LBLUE := Color("7fa8ff")
const LGREEN := Color("8fd65a")
const LCYAN := Color("a6e4f2")     # sky
const LRED := Color("ff7f6e")
const LMAGENTA := Color("ff8fd0")
const YELLOW := Color("ffd84a")
const WHITE := Color("fbfaf5")

const ALL := [BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, BROWN, LGRAY,
	DGRAY, LBLUE, LGREEN, LCYAN, LRED, LMAGENTA, YELLOW, WHITE]
