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
#   Emits profiles that resolve to an sso_start_url, whether it is set
#   directly on the profile (legacy format) or inherited from an
#   [sso-session] block via sso_session = <name> (AWS CLI v2 format).

BEGIN { print "PROFILE\tNAME\tTYPE\tACCOUNT\tROLE\tREGION" }

# Skip comment and blank lines
/^[[:space:]]*[#;]/ || /^[[:space:]]*$/ { next }

# New section — save the previous one, then classify this header.
# We can't emit yet: a profile may reference an [sso-session] block that
# appears later in the file, so everything is buffered until END.
/^\[/ {
	save()
	s = $0
	sub(/[[:space:]]*[#;].*$/, "", s)       # strip inline comment
	gsub(/^\[[[:space:]]*|[[:space:]]*\].*$/, "", s)  # strip [ ] and padding
	stype = ""; sname = ""
	if      (s == "default")                { stype = "profile"; sname = "default" }
	else if (s ~ /^profile[[:space:]]+/)    { stype = "profile"; sname = s; sub(/^profile[[:space:]]+/, "", sname) }
	else if (s ~ /^sso-session[[:space:]]+/) { stype = "session"; sname = s; sub(/^sso-session[[:space:]]+/, "", sname) }
	sso_url = account = role = region = name = type = sess = ""
	next
}

# Key=value lines inside a recognised section
stype != "" && index($0, "=") {
	eq = index($0, "=")
	k = substr($0, 1, eq-1); gsub(/[[:space:]]/, "", k)
	v = substr($0, eq+1); sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
	if      (k == "sso_start_url")  sso_url = v
	else if (k == "sso_account_id") account = v
	else if (k == "sso_role_name")  role    = v
	else if (k == "region")         region  = v
	else if (k == "name")           name    = v
	else if (k == "type")           type    = v
	else if (k == "sso_session")    sess    = v
}

# Buffer the section that just ended into the appropriate table.
function save() {
	if (stype == "profile" && sname != "") {
		order[++n]        = sname
		p_url[sname]      = sso_url
		p_account[sname]  = account
		p_role[sname]     = role
		p_region[sname]   = region
		p_name[sname]     = name
		p_type[sname]     = type
		p_sess[sname]     = sess
	} else if (stype == "session" && sname != "") {
		sess_url[sname] = sso_url
	}
	stype = ""; sname = ""
}

# Resolve references and emit. Extra params after the space are locals.
END {
	save()
	for (i = 1; i <= n; i++) {
		prof = order[i]
		url  = p_url[prof]
		if (url == "" && p_sess[prof] != "") url = sess_url[p_sess[prof]]
		if (url == "") continue
		nm = (p_name[prof]    != "") ? p_name[prof]    : "N/A"
		tp = (p_type[prof]    != "") ? p_type[prof]    : "N/A"
		ac = (p_account[prof] != "") ? p_account[prof] : "N/A"
		rl = (p_role[prof]    != "") ? p_role[prof]    : "N/A"
		rg = (p_region[prof]  != "") ? p_region[prof]  : "N/A"
		print prof "\t" nm "\t" tp "\t" ac "\t" rl "\t" rg
	}
}
