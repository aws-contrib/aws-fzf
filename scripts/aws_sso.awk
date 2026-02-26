#!/usr/bin/awk -f
#
# aws_sso.awk - Parse ~/.aws/config and output SSO profiles as TSV
#
# USAGE:
#   awk -f aws_sso.awk ~/.aws/config
#   AWS_CONFIG_FILE=~/.aws/config awk -f aws_sso.awk ~/.aws/config
#
# OUTPUT:
#   Tab-separated rows: PROFILE  NAME  TYPE  ACCOUNT  ROLE  REGION
#   Only profiles with sso_start_url are emitted.

BEGIN { print "PROFILE\tNAME\tTYPE\tACCOUNT\tROLE\tREGION" }

# Skip comment and blank lines
/^[[:space:]]*[#;]/ || /^[[:space:]]*$/ { next }

# New section — flush previous profile, reset state
/^\[/ {
	flush()
	s = $0; gsub(/^\[|\]/, "", s)
	if      (s == "default")  profile = "default"
	else if (s ~ /^profile /) profile = substr(s, 9)
	else                      profile = ""
	sso_url = account = role = region = name = type = ""
}

# Key=value lines inside a recognised profile section
profile != "" && /=/ {
	eq = index($0, "=")
	k = substr($0, 1, eq-1); sub(/[[:space:]]+$/, "", k)
	v = substr($0, eq+1);    sub(/^[[:space:]]+/, "", v)
	if (k == "sso_start_url")  sso_url = v
	if (k == "sso_account_id") account  = v
	if (k == "sso_role_name")  role     = v
	if (k == "region")         region   = v
	if (k == "name")           name     = v
	if (k == "type")           type     = v
}

# Emit a profile row if it has sso_start_url
# Extra params after the space are local variables (idiomatic awk)
function flush(    n, t, a, r, g) {
	if (profile != "" && sso_url != "") {
		n = (name    != "") ? name    : "NONE"
		t = (type    != "") ? type    : "NONE"
		a = (account != "") ? account : "N/A"
		r = (role    != "") ? role    : "N/A"
		g = (region  != "") ? region  : "N/A"
		print profile "\t" n "\t" t "\t" a "\t" r "\t" g
	}
}

# Handle the last profile (no following [ to trigger flush)
END { flush() }
