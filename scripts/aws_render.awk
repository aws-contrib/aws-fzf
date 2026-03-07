#!/usr/bin/awk -f
#
# aws_render.awk - Column-aware TSV renderer with per-column ANSI styling
#
# Replaces `column -t -s $'\t' | _colorize_status` with a single pass that
# handles both alignment and per-column styling — similar to gh-fzf Go templates.
#
# USAGE:
#   jq -r "... | @tsv" | awk -v styles="bold,faint,status,faint" -f aws_render.awk
#
# PARAMETERS (via -v styles="..."):
#   Comma-separated style name per column. Missing entries default to "normal".
#
#   bold    Bright/bold text          — resource names, identifiers
#   faint   Dimmed text               — dates, ARNs, secondary metadata
#   normal  Default terminal color    — counts, sizes, general fields
#   status  Value-based color:
#             green  — available, ACTIVE, RUNNING
#             red    — stopped, STOPPED, INACTIVE, failed
#             yellow — creating, modifying, PENDING, DRAINING, PROVISIONING,
#                      DEPROVISIONING, starting, stopping, STOPPING, deleting,
#                      upgrading, maintenance, rebooting
#
# NOTES:
#   - Input must be tab-separated (output of jq @tsv or similar)
#   - Header row (NR==1) is emitted without ANSI codes; fzf --color='header:yellow' styles it
#   - Two-pass design: first pass stores rows and tracks column widths, END renders

BEGIN {
	FS = "\t"

	# Parse styles spec into 1-based array
	n = split(styles, _s, ",")
	for (i = 1; i <= n; i++) col_style[i] = _s[i]

	# Status colour buckets (exact cell-value match — no false positives on names)
	green["available"] = green["ACTIVE"] = green["RUNNING"] = 1

	red["stopped"] = red["STOPPED"] = red["INACTIVE"] = red["failed"] = 1

	split("creating,CREATING,modifying,PENDING,pending,DRAINING,PROVISIONING," \
	      "DEPROVISIONING,starting,stopping,STOPPING,deleting,upgrading," \
	      "maintenance,rebooting", _y, ",")
	for (k in _y) yellow[_y[k]] = 1
}

# First pass: store every cell, track max visible width per column
{
	nrow++
	if (NF > ncol) ncol = NF
	for (c = 1; c <= NF; c++) {
		cell[nrow, c] = $c
		if (length($c) > width[c]) width[c] = length($c)
	}
}

# Apply ANSI styling to a cell value based on its column style
function style(val, col,    st, r) {
	st = (col in col_style) ? col_style[col] : "normal"
	r  = "\033[0m"
	if      (st == "bold")   return "\033[1m"  val r
	else if (st == "faint")  return "\033[2m"  val r
	else if (st == "status") {
		if (val in green)  return "\033[32m" val r
		if (val in red)    return "\033[31m" val r
		if (val in yellow) return "\033[33m" val r
	}
	return val
}

END {
	for (r = 1; r <= nrow; r++) {
		line = ""
		for (c = 1; c <= ncol; c++) {
			val = cell[r, c]

			# Header row: plain text — let fzf colour it via --color='header:yellow'
			out = (r == 1) ? val : style(val, c)

			# Pad using the plain value length (ANSI codes are invisible width)
			if (c < ncol) {
				pad = width[c] - length(val) + 2
				for (i = 0; i < pad; i++) out = out " "
			}
			line = line out
		}
		print line
	}
}
