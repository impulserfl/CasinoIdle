extends Control

@onready var reel1_label: Label = $VBox/Reels/Reel1
@onready var reel2_label: Label = $VBox/Reels/Reel2
@onready var reel3_label: Label = $VBox/Reels/Reel3
@onready var result_label: Label = $VBox/ResultLabel
@onready var spin_button: Button = $VBox/Buttons/SpinButton
@onready var auto_button: Button = $VBox/Buttons/AutoButton
@onready var bet_label: Label = $VBox/BetLabel

var symbols := ["🍒", "🍋", "🍊", "🍇", "⭐", "🍀", "7"]
var bet_amount: float = 10.0
var is_spinning: bool = false
var auto_spin: bool = false

func _ready() -> void:
	result_label.text = "Press SPIN!"
	_update_bet_label()

func _update_bet_label() -> void:
	bet_label.text = "Bet: %.0f Chips" % bet_amount

func _on_spin_button_pressed() -> void:
	if is_spinning:
		return
	_do_spin()

func _on_auto_button_pressed() -> void:
	auto_spin = not auto_spin
	auto_button.text = "AUTO: ON" if auto_spin else "AUTO: OFF"
	if auto_spin and not is_spinning:
		_do_spin()

func _do_spin() -> void:
	if GameManager.chips < bet_amount:
		result_label.text = "Not enough chips!"
		auto_spin = false
		auto_button.text = "AUTO: OFF"
		return
	
	is_spinning = true
	spin_button.disabled = true
	GameManager.chips -= bet_amount
	
	# Animate reels a bit
	result_label.text = "Spinning..."
	
	for i in range(8):
		reel1_label.text = symbols[randi() % symbols.size()]
		reel2_label.text = symbols[randi() % symbols.size()]
		reel3_label.text = symbols[randi() % symbols.size()]
		await get_tree().create_timer(0.07).timeout
	
	# Final result
	var r1 = symbols[randi() % symbols.size()]
	var r2 = symbols[randi() % symbols.size()]
	var r3 = symbols[randi() % symbols.size()]
	
	reel1_label.text = r1
	reel2_label.text = r2
	reel3_label.text = r3
	
	var win = _calculate_win(r1, r2, r3)
	
	if win > 0:
		GameManager.add_chips(win)
		result_label.text = "YOU WON %.0f CHIPS!" % win
	else:
		result_label.text = "No win..."
		# Still give a tiny bit of exp for playing
		GameManager.add_exp(1.0)
	
	is_spinning = false
	spin_button.disabled = false
	
	if auto_spin:
		await get_tree().create_timer(0.6).timeout
		if auto_spin:
			_do_spin()

func _calculate_win(a: String, b: String, c: String) -> float:
	# Three of a kind
	if a == b and b == c:
		if a == "7":
			return bet_amount * 50.0
		elif a == "⭐":
			return bet_amount * 25.0
		elif a == "🍀":
			return bet_amount * 15.0
		else:
			return bet_amount * 8.0
	
	# Two of a kind
	if a == b or b == c or a == c:
		return bet_amount * 2.0
	
	return 0.0
