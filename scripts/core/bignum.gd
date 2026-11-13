class_name BigNum
extends RefCounted
## Formats large numbers for an incremental game: 999, 1.25K, 3.4M, 7.1B, 2.0T, then aa, ab…

const SUFFIX := ["", "K", "M", "B", "T"]

static func fmt(v: float) -> String:
	if v < 0.0:
		return "-" + fmt(-v)
	if v < 1000.0:
		return str(int(floor(v)))
	var e := int(floor(log(v) / log(1000.0)))
	var m := v / pow(1000.0, e)
	if m >= 999.995:   # rounding would print "1000K"
		m /= 1000.0
		e += 1
	var suf: String
	if e < SUFFIX.size():
		suf = SUFFIX[e]
	else:
		var k := e - SUFFIX.size()
		suf = char(97 + int(k / 26) % 26) + char(97 + k % 26)
	var digits := 2 if m < 10.0 else (1 if m < 100.0 else 0)
	return ("%." + str(digits) + "f%s") % [m, suf]
