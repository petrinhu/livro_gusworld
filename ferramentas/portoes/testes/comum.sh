#!/bin/bash
# Funcoes comuns dos autotestes dos portoes (SG-02). Carregado por rodar.sh com ". comum.sh".
# Regra: nenhum caractere de travessao nem entidade HTML literal neste arquivo; eles nascem por printf.
# Regra: todo git que muda estado roda dentro de SCR (funcao seguro), nunca no repositorio real.

TRAV=$(printf '\342\200\224')       # U+2014
MEIO=$(printf '\342\200\223')       # U+2013
AMP=$(printf '\046')                # ampersand, para montar entidades sem o literal
ZWSP=$(printf '\342\200\213')       # U+200B
HIFEN_NB=$(printf '\342\200\221')   # U+2011
NOREPLY=238845971+petrinhu@users.noreply.github.com
ZERO=0000000000000000000000000000000000000000
MODO=legado
[ -f "$FONTE/instalar.sh" ] && MODO=novo
CASOS=0
FALHAS=0

seguro() { # DIR: recusa operar em repositorio fora do scratch
    local top
    top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || { echo "RECUSADO: $1 nao e repositorio" >&2; return 1; }
    case "$top" in
        "$SCR"/*) ;;
        *) echo "RECUSADO: repositorio fora do scratch: $top" >&2; return 1 ;;
    esac
    return 0
}

caso() { # ID ESPERADO(OK|REPROVA) RC TRECHO(ou -) ARQUIVO DESCRICAO
    local id=$1 esp=$2 rc=$3 trecho=$4 arq=$5 desc=$6 obt tr st
    CASOS=$((CASOS + 1))
    if [ "$rc" -eq 0 ]; then obt=OK; else obt=REPROVA; fi
    # Guarda de rc (SG-02): 126, 127 ou acima de 128 = ferramenta quebrada (comando ausente, uso invalido), nunca veredito.
    if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ] || [ "$rc" -gt 128 ]; then
        FALHAS=$((FALHAS + 1))
        printf '%s esperado=%s obtido=%s rc=%s trecho=na FALHOU de ferramenta | %s\n' "$id" "$esp" "$obt" "$rc" "$desc"
        return 0
    fi
    tr=na
    if [ "$trecho" != "-" ]; then
        if [ -f "$arq" ] && grep -qF -- "$trecho" "$arq"; then tr=sim; else tr=nao; fi
    fi
    st=FALHOU
    if [ "$obt" = "$esp" ] && [ "$tr" != nao ]; then st=ok; fi
    [ "$st" = ok ] || FALHAS=$((FALHAS + 1))
    printf '%s esperado=%s obtido=%s rc=%s trecho=%s %s | %s\n' "$id" "$esp" "$obt" "$rc" "$tr" "$st" "$desc"
}

novo_repo() { # NOME: repositorio descartavel com semente, git-crypt e copia dos portoes da FONTE
    local d="$SCR/$1" t c
    rm -rf "$d"
    mkdir -p "$d" && cd "$d" || return 1
    git init -q -b main . || return 1
    cp "$RAIZ/.gitattributes" "$RAIZ/.gitignore" . || return 1
    mkdir -p .github/workflows && cp "$RAIZ/.github/workflows/sigilo.yml" .github/workflows/ || return 1
    git-crypt init >/dev/null 2>&1 || return 1
    git config --local user.name "Teste" || return 1
    git config --local user.email "$NOREPLY" || return 1
    mkdir -p ferramentas/portoes || return 1
    find "$FONTE" -maxdepth 1 -type f -exec cp -t ferramentas/portoes {} + || return 1
    printf 'Semente do teste de cifra, texto generico sem travessao.\n' > semente.md || return 1
    git add .gitattributes .gitignore .github/workflows/sigilo.yml ferramentas/portoes semente.md || return 1
    t=$(git write-tree) || return 1
    c=$(git commit-tree "$t" -m "chore: semente do teste (SG-02)") || return 1
    git update-ref refs/heads/main "$c" || return 1
    if [ "$MODO" = novo ]; then
        sh ferramentas/portoes/instalar.sh > "$SCR/instalar-$1.txt" 2>&1 || return 1
    else
        git config --local core.hooksPath "$PWD/ferramentas/portoes" || return 1
    fi
    rm -f "$SCR/home/marcas"
}

commita() { # argumentos de git commit, no repositorio atual; o commit passa pelos portoes
    seguro "$PWD" || return 1
    rm -f "$SCR/saida.txt"
    git commit -q "$@" >"$SCR/saida.txt" 2>&1
}

marcas() { tr '\n' ' ' < "$SCR/home/marcas" 2>/dev/null; }

commit_sem_gate() { # MENSAGEM [EMAIL-DO-AUTOR]: commit por encanamento, sem nenhum gancho; atualiza o ramo atual
    seguro "$PWD" || return 1
    local t c
    t=$(git write-tree) || return 1
    if [ -n "${2:-}" ]; then
        c=$(GIT_AUTHOR_EMAIL="$2" git commit-tree "$t" -p HEAD -m "$1") || return 1
    else
        c=$(git commit-tree "$t" -p HEAD -m "$1") || return 1
    fi
    git update-ref -m "sem gate" HEAD "$c"
}

blob_falso() { # TAMANHO ARQUIVO: cabecalho GITCRYPT, 12 bytes de nonce e TAMANHO bytes de texto legivel
    { printf '\000GITCRYPT\000'; printf '\001\002\003\004\005\006\007\010\011\012\013\014'; head -c "$1" /dev/zero | tr '\0' 'a'; } > "$2"
}

ci_aqui() { # NOME BASE SAIDA: ci rodado no proprio repositorio, sem clone
    seguro "$SCR/$1" || return 1
    if [ "$MODO" = novo ]; then
        ( cd "$SCR/$1" && BASE_PUSH="$2" sh ferramentas/portoes/ci-bootstrap.sh ) > "$3" 2>&1
    else
        ( cd "$SCR/$1" && python3 ferramentas/portoes/portoes.py ci ) > "$3" 2>&1
    fi
}

remoto_novo() { # NOME: repositorio bare de scratch como origin
    seguro "$SCR/$1" || return 1
    rm -rf "$SCR/$1-remoto.git"
    git init -q --bare "$SCR/$1-remoto.git" && git -C "$SCR/$1" remote add origin "$SCR/$1-remoto.git"
}

empurra() { # NOME: push do main para o origin de scratch; o pre-push passa pelo portao; autoriza o 1o envio (SG-02g)
    seguro "$SCR/$1" || return 1
    PORTOES_PRIMEIRO_ENVIO=$(git -C "$SCR/$1" rev-parse -q --verify refs/heads/main) \
        git -C "$SCR/$1" push -q origin main > "$SCR/saida-envia.txt" 2>&1
}

roda_bloco_yaml() { # CLONE BASE SAIDA: roda o bloco de verificacao do workflow do clone (SG-02)
    local y="$1/.github/workflows/sigilo.yml" b
    b=$(sed -n 's/^ *BOOTSTRAP_BLOB: *\([0-9a-f]\{40\}\) *$/\1/p' "$y")
    sed -n '/# inicio-verificacao/,/# fim-verificacao/p' "$y" | sed 's/^          //' > "$1.bloco.sh" || return 1
    ( cd "$1" && BASE_PUSH="$2" BASE_PR= BASE_PADRAO=main BOOTSTRAP_BLOB="$b" GIT_NO_REPLACE_OBJECTS=1 \
        sh -e "$1.bloco.sh" ) > "$3" 2>&1
}

ci_no_clone() { # CLONE BASE SAIDA: bloco do workflow (novo) ou ci-bootstrap.sh (antes da Fase 5) ou portoes.py ci (legado)
    if [ "$MODO" = novo ] && grep -q '# inicio-verificacao' "$1/.github/workflows/sigilo.yml"; then
        roda_bloco_yaml "$1" "$2" "$3"
    elif [ "$MODO" = novo ]; then
        ( cd "$1" && BASE_PUSH="$2" BASE_PADRAO=main sh ferramentas/portoes/ci-bootstrap.sh ) > "$3" 2>&1
    else
        ( cd "$1" && python3 ferramentas/portoes/portoes.py ci ) > "$3" 2>&1
    fi
}

ci_simulado() { # NOME BASE SAIDA: clone sem chave do HEAD e CI
    local cl="$SCR/$1-ci"
    seguro "$SCR/$1" || return 1
    rm -rf "$cl" "$cl.bloco.sh"
    git clone -q "$SCR/$1" "$cl" 2>/dev/null || return 1
    test ! -e "$cl/.git/git-crypt/keys/default" || return 1
    ci_no_clone "$cl" "$2" "$3"
}

ci_simulado_ramo() { # NOME RAMO BASE SAIDA: como ci_simulado, com RAMO em checkout no clone
    local cl="$SCR/$1-ci"
    seguro "$SCR/$1" || return 1
    rm -rf "$cl" "$cl.bloco.sh"
    git clone -q "$SCR/$1" "$cl" 2>/dev/null || return 1
    test ! -e "$cl/.git/git-crypt/keys/default" || return 1
    git -C "$cl" switch -q "$2" || return 1
    ci_no_clone "$cl" "$3" "$4"
}

empurra_ramo() { # NOME RAMO: push do RAMO para o origin de scratch; o pre-push passa pelo portao
    seguro "$SCR/$1" || return 1
    git -C "$SCR/$1" push -q origin "$2" > "$SCR/saida-envia.txt" 2>&1
}
