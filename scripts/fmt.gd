class_name Fmt
extends RefCounted

## Number / time formatting helpers.
##
## Idle games spend most of their life well past the point where "%.0f" produces
## an unreadable wall of digits, so every player-facing number goes through here.

const SUFFIXES: Array[String] = [
	"", "K", "M", "B", "T",
	"Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg",
]

## 1234.5 -> "1.23K", 5_600_000 -> "5.60M", 42 -> "42"
static func chips(value: float) -> String:
	if is_nan(value):
		return "0"
	if is_inf(value):
		return "∞"
	var sign_str := "-" if value < 0.0 else ""
	var v := absf(value)
	if v < 1000.0:
		if v < 10.0 and not is_equal_approx(v, floorf(v)):
			return sign_str + ("%.1f" % v)
		return sign_str + ("%d" % int(v))

	var tier := int(floorf(log(v) / log(1000.0)))
	tier = maxi(tier, 1)
	var scaled := v / pow(1000.0, tier)
	# Guard against float error nudging 999.9996 up to 1000.
	if scaled >= 1000.0:
		scaled /= 1000.0
		tier += 1
	if tier >= SUFFIXES.size():
		return sign_str + ("%.2e" % v)

	var suffix: String = SUFFIXES[tier]
	if scaled < 10.0:
		return sign_str + ("%.2f" % scaled) + suffix
	if scaled < 100.0:
		return sign_str + ("%.1f" % scaled) + suffix
	return sign_str + ("%.0f" % scaled) + suffix


## Chips-per-second, e.g. "12.3K/s"
static func rate(value: float) -> String:
	return chips(value) + "/s"


## Whole-number multiplier display, e.g. "x2.50"
static func mult(value: float) -> String:
	if value < 10.0:
		return "x%.2f" % value
	if value < 1000.0:
		return "x%.1f" % value
	return "x" + chips(value)


## 0.075 -> "7.5%"
static func percent(value: float, digits: int = 1) -> String:
	if digits <= 0:
		return "%.0f%%" % (value * 100.0)
	if digits == 1:
		return "%.1f%%" % (value * 100.0)
	return "%.2f%%" % (value * 100.0)


## 9312.0 -> "2h 35m"
static func duration(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	if s < 60:
		return "%ds" % s
	var m := s / 60
	if m < 60:
		return "%dm %ds" % [m, s % 60]
	var h := m / 60
	if h < 24:
		return "%dh %dm" % [h, m % 60]
	var d := h / 24
	return "%dd %dh" % [d, h % 24]


## "1 in 100,545" style odds from a probability.
static func odds(probability: float) -> String:
	if probability <= 0.0:
		return "never"
	return "1 in " + commas(roundf(1.0 / probability))


static func commas(value: float) -> String:
	var s := "%d" % int(absf(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0.0 else "") + out
