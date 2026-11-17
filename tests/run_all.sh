#!/bin/sh
# Lance les 352 combinaisons : 11 langues x DialogueUI x Spoken x variantes. Usage : sh tests/run_all.sh
cd "$(dirname "$0")"; D=".."; n=0; bad=0
for loc in enUS frFR deDE esES esMX itIT ptBR ruRU koKR zhCN zhTW; do for dui in 0 1; do for sp in 0 1; do
for g in 0 1; do for ng in 0 1; do for nb in 0 1; do
out=$(GLOBALS=$g NOGRADIENT=$ng NOBUBBLEART=$nb texlua run.lua $loc $dui $sp $D 2>&1 | tail -1); n=$((n+1))
echo "$out" | grep -q " 0 failed, 0 runtime" || { bad=$((bad+1)); echo "$loc dui=$dui spoken=$sp G=$g NG=$ng NB=$nb: $out"; }
done; done; done; done; done; done; echo "runs=$n failed=$bad"
