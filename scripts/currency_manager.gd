extends Node

signal currency_changed(total: int, delta: int)
signal coin_collected(value: int, coins_collected: int, balance: int)

var total_currency: int = 0
var coins_collected: int = 0
var currency_earned: int = 0

func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	total_currency += amount
	currency_changed.emit(total_currency, amount)

## Records a single coin picked up: bumps the running pickup count, the
## lifetime value earned, and the spendable balance in one step.
func record_coin(value: int) -> void:
	if value <= 0:
		return
	coins_collected += 1
	currency_earned += value
	total_currency += value
	currency_changed.emit(total_currency, value)
	coin_collected.emit(value, coins_collected, total_currency)

## Number of individual coins picked up this session.
func get_coins_collected() -> int:
	return coins_collected

## Total value of every coin picked up this session (unaffected by spending).
func get_currency_earned() -> int:
	return currency_earned

## Current spendable balance.
func get_balance() -> int:
	return total_currency

func can_afford(amount: int) -> bool:
	return total_currency >= amount

func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return true
	if total_currency < amount:
		return false
	total_currency -= amount
	currency_changed.emit(total_currency, -amount)
	return true
