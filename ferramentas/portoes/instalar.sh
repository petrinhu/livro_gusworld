#!/bin/sh
# Instala os ganchos de sigilo fora da arvore de trabalho (SG-02). Copia do HEAD, nunca da arvore:
# editar um gancho na arvore nao muda o que roda. Liga core.hooksPath e filter.git-crypt.required.
GIT_NO_REPLACE_OBJECTS=1; export GIT_NO_REPLACE_OBJECTS
unset GIT_ATTR_SOURCE
DEST="$(git rev-parse --path-format=absolute --git-common-dir)/portoes-ganchos" || exit 1
mkdir -p "$DEST" || exit 1
for f in pre-commit commit-msg pre-push post-commit post-checkout post-merge prepare-commit-msg confiavel.sh; do
    if ! git cat-file blob "HEAD:ferramentas/portoes/$f" > "$DEST/$f.novo"; then
        rm -f "$DEST/$f.novo"
        echo "[instalar] FALHOU: HEAD sem ferramentas/portoes/$f"
        exit 1
    fi
    chmod 755 "$DEST/$f.novo" && mv -f "$DEST/$f.novo" "$DEST/$f" || exit 1
done
git config --local core.hooksPath "$DEST" || exit 1
git config --local filter.git-crypt.required true || exit 1
echo "[instalar] ganchos copiados do HEAD para $DEST"
echo "[instalar] core.hooksPath=$DEST filter.git-crypt.required=true"
