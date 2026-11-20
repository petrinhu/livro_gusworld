# Funcoes comuns dos ganchos instalados (SG-02). Carregado com ". confiavel.sh" pelo gancho.
# Quem julga um commit e o portao do commit anterior (HEAD), extraido para pasta temporaria.
GIT_NO_REPLACE_OBJECTS=1; export GIT_NO_REPLACE_OBJECTS
unset GIT_ATTR_SOURCE
PORTAO_TMP=; ENT=; SAIDA=
limpa_temporarios() {
    [ -z "$PORTAO_TMP" ] || rm -rf "$PORTAO_TMP"
    [ -z "$ENT" ] || rm -f "$ENT"
    [ -z "$SAIDA" ] || rm -f "$SAIDA"
}
trap limpa_temporarios EXIT

extrai_portao() { # REV -> PORTAO_DIR com a subarvore ferramentas/portoes daquela revisao, sem atributos da raiz
    PORTAO_TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/portoes.XXXXXX") || return 1
    PORTAO_DIR="$PORTAO_TMP/ferramentas/portoes"
    mkdir -p "$PORTAO_DIR" || return 1
    git archive --format=tar -o "$PORTAO_TMP/p.tar" "$1:ferramentas/portoes" || return 1
    tar -x -f "$PORTAO_TMP/p.tar" -C "$PORTAO_DIR" || return 1
}

confere_instalacao() { # NOME_DO_GANCHO PASTA_DO_GANCHO
    INST="$(git rev-parse --path-format=absolute --git-common-dir)/portoes-ganchos"
    if ! git cat-file -e HEAD:ferramentas/portoes/confiavel.sh 2>/dev/null; then
        if [ "$2" = "$INST" ]; then echo "  FALHOU HEAD sem portao confiavel"; return 1; fi
        echo "  AVISO transicao: HEAD sem portao confiavel, gancho da arvore de trabalho"; return 0
    fi
    if [ "$2" != "$INST" ]; then
        echo "  FALHOU ganchos fora da instalacao: rode ferramentas/portoes/instalar.sh"; return 1
    fi
    for f in "$1" confiavel.sh; do
        git cat-file blob "HEAD:ferramentas/portoes/$f" 2>/dev/null | cmp -s - "$INST/$f" || {
            echo "  FALHOU ganchos instalados divergem do HEAD: rode ferramentas/portoes/instalar.sh ($f)"; return 1; }
    done
}

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

roda_portao() { # MODO [ARGS]: roda o portao extraido, mostra a saida e confere de novo o veredito
    SAIDA=$(mktemp "${TMPDIR:-/var/tmp}/portoes-saida.XXXXXX") || return 1
    python3 -I "$PORTAO_DIR/portoes.py" "$@" > "$SAIDA" 2>&1
    rc=$?
    cat "$SAIDA"
    confere_saida "$1" "$rc" "$SAIDA"
}
