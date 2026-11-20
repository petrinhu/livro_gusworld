#!/bin/sh
# Roda o portao ci extraido da base e exige as linhas de contagem (SG-02). Sai 0 so se o portao saiu 0
# e todas as linhas exigidas estao presentes. A lista exigida cresce por fase, sempre junto da linha nova.
D=$(cd "$(dirname "$0")" && pwd) || exit 1
python3 -I "$D/portoes.py" ci > "$D/saida.txt" 2>&1
rc=$?
cat "$D/saida.txt"
falhou=0
[ "$rc" -eq 0 ] || { echo "  FALHOU portao da base saiu com rc=$rc"; falhou=1; }
for nome in ci-commits ci-blobs ci-confianca; do
    grep -q "^\[$nome\] encontrados=[1-9]" "$D/saida.txt" || {
        echo "  FALHOU saida do portao sem linha de contagem: $nome"; falhou=1; }
done
grep -q "^\[ci-heuristica\] cifrados=[1-9]" "$D/saida.txt" || {
    echo "  FALHOU saida do portao sem linha de heuristica: ci-heuristica"; falhou=1; }
exit "$falhou"
