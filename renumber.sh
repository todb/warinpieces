#!/bin/zsh

fix=35 # whatever number XX should be to fix the count

awk -v fix="$fix" '
  /^XX\. /      { renum=1; n=fix; sub(/^XX/, n++); print; next }
  /^[0-9]+\. /  { renum ? sub(/^[0-9]+/, n++) : n=$1+1; print; next }
                { print }
' in.txt > out.txt
