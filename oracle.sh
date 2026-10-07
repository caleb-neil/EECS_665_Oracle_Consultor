#!/bin/bash
# Submit each test's .ds file to the P4 oracle and save its output as the
# expected files:
#   OUTPUT FILE -> <name>/<name>.out.expected
#   STDERR      -> <name>/<name>.err.expected
#
# ./oracle.sh              run every test (every */*.ds)
# ./oracle.sh a b          run only the listed tests

ORACLE_URL="https://compilers.cool/oracles/o4/"
cd "$(dirname "$0")" || exit 1

if [ $# -gt 0 ]; then
	tests=("$@")
else
	tests=()
	for ds in */*.ds; do
		[ -f "$ds" ] && tests+=("$(dirname "$ds")")
	done
fi

# Pull the <pre> contents of the section labeled $1 out of the HTML on stdin,
# dropping the trailing <br /> and decoding HTML entities.
extract() {
	perl -0777 -ne '
		if (/\Q'"$1"'\E<br \/><pre[^>]*>(.*?)<\/pre>/s) {
			my $s = $1;
			$s =~ s/<br \/>$//;
			$s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g;
			$s =~ s/&#0?39;/\x27/g; $s =~ s/&amp;/&/g;
			print $s;
		}'
}

for t in "${tests[@]}"; do
	t="${t%/}"
	ds="$t/$t.ds"
	if [ ! -f "$ds" ]; then
		echo "SKIP $t (no $ds)"
		continue
	fi

	if ! html=$(curl -sS --fail -F "input=@$ds" "$ORACLE_URL"); then
		echo "FAIL $t (request failed)"
		continue
	fi
	if ! grep -q 'OUTPUT FILE\|STDERR\|no error output' <<< "$html"; then
		echo "FAIL $t (no output from oracle, possibly timed out)"
		continue
	fi

	extract "OUTPUT FILE" <<< "$html" > "$t/$t.out.expected"
	extract "STDERR" <<< "$html" > "$t/$t.err.expected"
	echo "DONE $t"
done
