#!/bin/sh
# Portao do CI sem chave (SG-02). Roda do banco de objetos, com hash fixado no workflow. O HEAD e julgado pelo
# portao da base: BASE_PR, senao BASE_PUSH; vazia ou zero vira a ponta publicada do ramo padrao.
# A saida do portao e conferida de novo aqui, fora do codigo do portao.
GIT_NO_REPLACE_OBJECTS=1; export GIT_NO_REPLACE_OBJECTS
unset GIT_ATTR_SOURCE

confere_saida() { # MODO RC ARQUIVO: segunda leitura do veredito (SG-02). Sai 0 so com rc 0 e saida limpa.
    awk -v modo="$1" -v rc="$2" '
        BEGIN {
            if (modo == "ci") lista = "ci-refs ci-commits ci-assuntos ci-blobs ci-heuristica ci-confianca ci-tags"
            else if (modo == "envio") lista = "envio-refs envio-commits envio-assuntos envio-blobs envio-confianca envio-tags envio-chave"
            else if (modo == "pre-commit") lista = "cifra confianca travessao autor"
            else if (modo == "commit-msg") lista = "commit-msg"
            else { print "  FALHOU saida: modo desconhecido " modo; erro = 1 }
            n = split(lista, nomes, " ")
            for (i = 1; i <= n; i++) visto[nomes[i]] = 0
            if (rc != 0) { print "  FALHOU saida: portao saiu com rc=" rc; erro = 1 }
        }
        /^ *FALHOU/ || /^ERRO/ { falhas++ }
        /^\[[a-z-]+\] / {
            nome = substr($1, 2, length($1) - 2)
            if (nome in visto) visto[nome]++
            split("", val)
            for (i = 2; i <= NF; i++) { if (split($i, kv, "=") == 2) val[kv[1]] = kv[2] }
            if (("falharam" in val && val["falharam"] != "0") || ("suspeitos" in val && val["suspeitos"] != "0") ||
                ("encontrados" in val && "analisados" in val && val["encontrados"] != val["analisados"])) ruins++
        }
        END {
            for (nome in visto) if (visto[nome] != 1) { print "  FALHOU saida: linha de contagem ausente ou repetida: " nome; erro = 1 }
            if (falhas > 0) { print "  FALHOU saida do portao com falha impressa (" falhas " linhas)"; erro = 1 }
            if (ruins > 0) { print "  FALHOU saida do portao com contagem fora de zero (" ruins " linhas)"; erro = 1 }
            printf "[saida] modo=%s rc=%s falhas=%d contagens_ruins=%d\n", modo, rc, falhas, ruins
            exit erro
        }' "$3"
}

git rev-parse -q --verify HEAD >/dev/null || { echo "  FALHOU historico vazio: sem HEAD"; exit 1; }
TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/ci-portoes.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
BASE=${BASE_PR:-}
[ -n "$BASE" ] || BASE=${BASE_PUSH:-}
case "$BASE" in
    *[!0]*) ;;
    *)
        REF="refs/remotes/origin/${BASE_PADRAO:-main}"
        BASE=$(git rev-parse -q --verify "$REF^{commit}") || {
            echo "  FALHOU base zero sem ramo padrao publicado: $REF"; exit 1; }
        echo "[ci-origem] base zero: ponta publicada de $REF"
        ;;
esac
git cat-file -e "$BASE^{commit}" 2>/dev/null || { echo "  FALHOU base sem commit no repositorio: $BASE"; exit 1; }
echo "[ci-origem] portao da base $BASE"
mkdir -p "$TMP/ferramentas/portoes" || exit 1
git archive --format=tar -o "$TMP/p.tar" "$BASE:ferramentas/portoes" || exit 1
tar -x -f "$TMP/p.tar" -C "$TMP/ferramentas/portoes" || exit 1
[ -f "$TMP/ferramentas/portoes/ci-base.sh" ] || { echo "  FALHOU portao da base sem ci-base.sh"; exit 1; }
sh "$TMP/ferramentas/portoes/ci-base.sh" > "$TMP/saida.txt" 2>&1
rc=$?
cat "$TMP/saida.txt"
confere_saida ci "$rc" "$TMP/saida.txt"
