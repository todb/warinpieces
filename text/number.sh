#!/usr/bin/env zsh

number=""
input=""
start=""
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
    -s|--start)
      start="$2"
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

if [[ -z "$number" || -z "$input" || -z "$start" || -z "$output" ]]; then
  echo "Usage: $0 -n NUMBER -i INPUT -s STRING -o OUTPUT" >&2
  exit 1
fi

awk -v n="$number" -v s="$start" '
  $0 ~ s { start=1 }
  start { printf "%d. %s\n", n++, $0; next }
  { print }
' "$input" > "$output"
