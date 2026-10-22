extends RefCounted

## A simulation-time cadence shared by targeting users. Stable phases spread
## group scans across frames without changing movement or attack timers.
const PHASE_SLOTS: int = 16
static var _next_phase: int = 0
var _phase: float
var _initialized: bool = false
var _remaining: float = 0.0

func _init() -> void:
	_phase = float(_next_phase % PHASE_SLOTS) / float(PHASE_SLOTS)
	_next_phase += 1

func phase_delay(interval: float) -> float:
	return maxf(interval, 0.0) * _phase

func is_due(delta: float, interval: float) -> bool:
	if interval <= 0.0:
		return true
	if not _initialized:
		_initialized = true
		# The first lookup stays responsive; later empty scans are staggered.
		_remaining = phase_delay(interval)
		if _remaining <= 0.0:
			_remaining = interval
		return true
	_remaining -= maxf(delta, 0.0)
	if _remaining > 0.0:
		return false
	# Long frames cause one scan, never a burst of catch-up scans.
	_remaining = interval - fposmod(-_remaining, interval)
	return true
