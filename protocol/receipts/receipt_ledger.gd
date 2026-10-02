extends Node

signal receipt_appended(receipt: Dictionary)

const MAX_RECEIPTS := 1000
var _receipts: Array[Dictionary] = []

func append_receipt(receipt: Dictionary) -> void:
	_receipts.append(receipt.duplicate(true))
	if _receipts.size() > MAX_RECEIPTS:
		_receipts.pop_front()
	receipt_appended.emit(receipt)

func snapshot() -> Array[Dictionary]:
	return _receipts.duplicate(true)

func latest() -> Dictionary:
	if _receipts.is_empty():
		return {}
	return _receipts[-1].duplicate(true)

func clear() -> void:
	_receipts.clear()
