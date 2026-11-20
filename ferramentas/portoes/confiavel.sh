# Funcoes comuns dos ganchos instalados (SG-02). Carregado com ". confiavel.sh" pelo gancho.
# Quem julga um commit e o portao do commit anterior (HEAD), extraido para pasta temporaria.
GIT_NO_REPLACE_OBJECTS=1; export GIT_NO_REPLACE_OBJECTS
unset GIT_ATTR_SOURCE
PORTAO_TMP=; ENT=
limpa_temporarios() {
    [ -z "$PORTAO_TMP" ] || rm -rf "$PORTAO_TMP"
    [ -z "$ENT" ] || rm -f "$ENT"
}
trap limpa_temporarios EXIT

extrai_portao() { # REV -> define PORTAO_DIR com ferramentas/portoes daquela revisao
    PORTAO_TMP=$(mktemp -d "${TMPDIR:-/var/tmp}/portoes.XXXXXX") || return 1
    git archive --format=tar -o "$PORTAO_TMP/p.tar" "$1" ferramentas/portoes || return 1
    tar -x -f "$PORTAO_TMP/p.tar" -C "$PORTAO_TMP" || return 1
    PORTAO_DIR="$PORTAO_TMP/ferramentas/portoes"
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
