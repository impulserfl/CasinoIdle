extends Minigame

## Simplified baccarat: bet Player, Banker, or Tie.
## Standard-ish odds with house edge. RTP ≈ 94% on Player/Banker.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const VALS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0]

var _bet_on := "player"
var _player_label: Label
var _banker_label: Label
var _btns: Dictionary = {}


func _init() -> void:
	game_id = "baccarat"
	game_name = "Baccarat"
	game_icon = "🎴"
	base_rtp = 0.94


func _build_board(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.PANEL_HI, 12, 2)
	var col := UIKit.vbox(8)
	_player_label = UIKit.label("Player: —", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_banker_label = UIKit.label("Banker: —", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_player_label)
	col.add_child(_banker_label)
	panel.add_child(col)
	container.add_child(panel)

	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for e in [["player", "PLAYER 1:1"], ["banker", "BANKER 0.95:1"], ["tie", "TIE 8:1"]]:
		var b := UIKit.button(String(e[1]), 14)
		b.custom_minimum_size = Vector2(130, 40)
		b.pressed.connect(_select.bind(String(e[0])))
		_btns[String(e[0])] = b
		row.add_child(b)
	container.add_child(row)
	container.add_child(UIKit.wrapped("Closest to 9 wins. Banker pays 0.95:1. Tie is rare.", 12, UIKit.DIM))
	_refresh()


func _select(s: String) -> void:
	_bet_on = s
	_refresh()
	AudioManager.play_click()


func _refresh() -> void:
	for k in _btns:
		_btns[k].add_theme_color_override("font_color", UIKit.GOLD if k == _bet_on else UIKit.TEXT)


func _card() -> int:
	return VALS[randi() % VALS.size()]


func _hand() -> int:
	return (_card() + _card()) % 10


func play_once() -> void:
	if not wager(bet):
		set_result("Not enough chips.", UIKit.RED)
		stop_auto()
		return
	var staked := bet
	set_result("Dealing...", UIKit.DIM)
	await wait(0.25)
	if not is_inside_tree():
		return
	var p := _hand()
	var b := _hand()
	_player_label.text = "Player: %d" % p
	_banker_label.text = "Banker: %d" % b
	FX.pulse(_player_label, 1.1, 0.15)

	var payout := 0.0
	var won := false
	if p == b:
		if _bet_on == "tie":
			payout = staked * 9.0
			won = true
		else:
			GameManager.add_chips(staked, false)
			finish_round(0.0, 1.0, false)
			set_result("Tie — stake returned.", UIKit.BLUE)
			AudioManager.play_refund()
			return
	elif p > b and _bet_on == "player":
		payout = staked * 2.0
		won = true
	elif b > p and _bet_on == "banker":
		payout = staked * 1.95
		won = true

	var loss_p := 0.52 if _bet_on != "tie" else 0.90
	var credited := finish_round(payout, loss_p, false)
	if won:
		set_result("Win!  +%s" % Fmt.chips(payout), UIKit.GREEN)
		celebrate(payout, payout / staked)
	elif credited <= 0.0:
		set_result("No win.", UIKit.DIM)
