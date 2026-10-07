#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 INPUT.txt OUTPUT.png" >&2
  exit 2
fi

input=$1
output=$2
tmp_pdf=$(mktemp -t devops-homework.XXXXXX.pdf)
tmp_txt=$(mktemp -t devops-homework.XXXXXX.txt)
tmp_jpg=$(mktemp -t devops-homework.XXXXXX.jpg)
trap 'rm -f "$tmp_pdf" "$tmp_txt" "$tmp_jpg"' EXIT

mkdir -p "$(dirname "$output")"
perl -pe 's/\e\[[0-9;]*[mK]//g; s/\r//g' "$input" >"$tmp_txt"
/usr/sbin/cupsfilter "$tmp_txt" >"$tmp_pdf" 2>/dev/null
# PDF-to-PNG preserves a transparent background. Passing through JPEG flattens
# it to white so black terminal text stays visible in light and dark viewers.
/usr/bin/sips -s format jpeg "$tmp_pdf" --out "$tmp_jpg" >/dev/null
/usr/bin/sips -s format png "$tmp_jpg" --out "$output" >/dev/null
echo "rendered $output"
