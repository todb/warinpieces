#!/usr/bin/env zsh

number=""
input=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--number)
      number="$2"
      shift 2
      ;;
    -i|--input)
      input="$2"
      shift 2
      ;;
    -o|--output)
      output="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$number" || -z "$input" || -z "$output" ]]; then
  echo "Usage: $0 -n NUMBER -i INPUT -o OUTPUT" >&2
  exit 1
fi

awk -v n="$number" '
  start==0 && $0 !~ /^[[:space:]]*(#|$)/ { start=1 }
  start { printf "%d. %s\n", n++, $0; next }
  { print }
' "$input" > "$output"
