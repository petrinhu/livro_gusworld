#!/bin/sh
# Portao do CI sem chave (SG-02). O HEAD e julgado pelo portao da base (commit anterior), extraido do
# proprio repositorio: o workflow nunca roda o codigo do commit que esta sendo julgado.
# Base: BASE_PR, senao BASE_PUSH; vazia, zero ou ausente vira o proprio HEAD.
GIT_NO_REPLACE_OBJECTS=1; export GIT_NO_REPLACE_OBJECTS
unset GIT_ATTR_SOURCE
git rev-parse -q --verify HEAD >/dev/null || { echo "  FALHOU historico vazio: sem HEAD"; exit 1; }
TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/ci-portoes.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
BASE=${BASE_PR:-}
[ -n "$BASE" ] || BASE=${BASE_PUSH:-}
case "$BASE" in
    *[!0]*) ;;
    *) BASE=HEAD ;;
esac
if [ "$BASE" = HEAD ]; then
    echo "[ci-origem] portao de proprio-commit"
else
    git cat-file -e "$BASE^{commit}" 2>/dev/null || { echo "  FALHOU base sem commit no repositorio: $BASE"; exit 1; }
    echo "[ci-origem] portao da base $BASE"
fi
git archive --format=tar -o "$TMP/p.tar" "$BASE" ferramentas/portoes || exit 1
tar -x -f "$TMP/p.tar" -C "$TMP" || exit 1
[ -f "$TMP/ferramentas/portoes/ci-base.sh" ] || { echo "  FALHOU portao da base sem ci-base.sh"; exit 1; }
sh "$TMP/ferramentas/portoes/ci-base.sh"
