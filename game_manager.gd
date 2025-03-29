# GameManager.gd (Autoload)
extends Node

var lives = 100
var cash = 650
var current_round = 0

signal lives_changed(new_lives)
signal cash_changed(new_cash)

func decrease_lives(amount = 1):
	lives -= amount
	lives_changed.emit(lives)
	print("Lives remaining: ", lives)
	if lives <= 0:
		game_over()

func increase_cash(amount):
	cash += amount
	cash_changed.emit(cash)
	print("Cash: ", cash)

func can_afford(cost):
	return cash >= cost

func spend_cash(amount):
	if can_afford(amount):
		cash -= amount
		emit_signal("cash_changed", cash)
		return true
	return false

func game_over():
	print("GAME OVER!")
	get_tree().paused = true # Simple pause
	# Add logic here to show a game over screen
