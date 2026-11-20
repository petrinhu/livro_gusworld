#!/bin/bash
# Autoteste dos portoes de sigilo (SG-02, L-36).
# Uso: rodar.sh DIRETORIO_SCRATCH
# Cada caso cria repositorio descartavel dentro de DIRETORIO_SCRATCH, com o .gitattributes
# deste repositorio, e confere se o portao respondeu como o esperado. Controles positivos
# (passam), negativos (reprovam) e varredura vazia (nunca verde em silencio).
set -u

RAIZ=$(cd "$(dirname "$0")/../../.." && pwd) || exit 1
PORTAO="$RAIZ/ferramentas/portoes"
SCR=${1:?"uso: rodar.sh DIRETORIO_SCRATCH"}
mkdir -p "$SCR" && SCR=$(cd "$SCR" && pwd) || exit 1

NOREPLY=238845971+petrinhu@users.noreply.github.com
TRAV=$(printf '\342\200\224')   # travessao U+2014, em bytes UTF-8
MEIO=$(printf '\342\200\223')   # meio-travessao U+2013, em bytes UTF-8
CASOS=0
FALHAS=0

caso() { # id esperado(OK|REPROVA) rc descricao
    local id=$1 esp=$2 rc=$3 desc=$4 obt st
    CASOS=$((CASOS + 1))
    if [ "$rc" -eq 0 ]; then obt=OK; else obt=REPROVA; fi
    if [ "$obt" = "$esp" ]; then st=ok; else st=FALHOU; FALHAS=$((FALHAS + 1)); fi
    printf '%s esperado=%s obtido=%s rc=%s %s | %s\n' "$id" "$esp" "$obt" "$rc" "$st" "$desc"
}

novo_repo() { # nome: repositorio com git-crypt, .gitattributes real, identidade noreply e portoes
    local d="$SCR/$1"
    rm -rf "$d"
    mkdir -p "$d" && cd "$d" || return 1
    git init -q -b main . || return 1
    cp "$RAIZ/.gitattributes" . || return 1
    git-crypt init >/dev/null 2>&1 || return 1
    git config --local user.name "Teste" || return 1
    git config --local user.email "$NOREPLY" || return 1
    git config --local core.hooksPath "$PORTAO" || return 1
    mkdir -p "$SCR/home/.claude/githooks"
    printf '#!/bin/sh\necho pre-commit >> "$HOME/marcas"\nexit "${RC_GLOBAL:-0}"\n' > "$SCR/home/.claude/githooks/pre-commit"
    printf '#!/bin/sh\necho commit-msg >> "$HOME/marcas"\nexit 0\n' > "$SCR/home/.claude/githooks/commit-msg"
    chmod 755 "$SCR/home/.claude/githooks/pre-commit" "$SCR/home/.claude/githooks/commit-msg"
    rm -f "$SCR/home/marcas"
}

# Commit passando pelo portao, com HOME falso (sem hook global real) e sem config global.
commita() { # argumentos de git commit
    env HOME="$SCR/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PATH="$PATH" \
        git commit -q "$@" >"$SCR/saida.txt" 2>&1
}
marcas() { tr '\n' ' ' < "$SCR/home/marcas" 2>/dev/null; }

# Commit que nao passa por hook nenhum (plumbing), como um commit feito por fora do clone local.
commit_sem_gate() { # mensagem [e-mail do autor]
    local t c email=${2:-}
    t=$(git write-tree) || return 1
    if [ -n "$email" ]; then
        c=$(GIT_AUTHOR_EMAIL="$email" git commit-tree "$t" -p HEAD -m "$1") || return 1
    else
        c=$(git commit-tree "$t" -p HEAD -m "$1") || return 1
    fi
    git update-ref refs/heads/main "$c"
}

# ---------- pre-commit ----------
novo_repo p01 && printf 'texto cifrado\n' > a.md && mkdir -p "livro-1/texto" && \
    printf 'Abertura do capitulo.\n\n%s Oi, disse ele.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && commita -m "feat: caso positivo com fala no inicio de paragrafo (SG-02)"
caso P01 OK $? "positivo: cifra, fala com travessao e ponte de hook global; marcas: $(marcas)"

novo_repo p02 && sha=$(printf 'claro\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,notas/cru.md" && \
    commita -m "feat: caso negativo, blob em claro em caminho cifrado (SG-02)"
caso P02 REPROVA $? "negativo: arquivo em claro no indice fora da excecao; gate: $(head -1 "$SCR/saida.txt")"

novo_repo p03 && mkdir -p livro-1/texto && printf 'Ele disse %s oi.\n' "$TRAV" > livro-1/texto/c2.md && \
    git add -A && commita -m "feat: caso negativo, travessao no meio da frase (SG-02)"
caso P03 REPROVA $? "negativo: travessao fora de inicio de fala no texto"

novo_repo p04 && mkdir -p projeto && printf '%s nota fora do texto\n' "$TRAV" > projeto/a.md && \
    git add -A && commita -m "feat: caso negativo, travessao fora da pasta de texto (SG-02)"
caso P04 REPROVA $? "negativo: travessao no inicio de linha fora de livro-*/texto"

novo_repo p05 && mkdir -p livro-1/texto && printf 'Faixa 1%s2 do livro.\n' "$MEIO" > livro-1/texto/c3.md && \
    git add -A && commita -m "feat: caso negativo, meio-travessao no texto (SG-02)"
caso P05 REPROVA $? "negativo: meio-travessao U+2013 no meio da linha"

novo_repo p06 && mkdir -p livro-1/texto && printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && env HOME="$SCR/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PATH="$PATH" git -c user.email=outro@exemplo.invalid commit -q -m "feat: caso negativo, e-mail do autor errado (SG-02)" >"$SCR/saida.txt" 2>&1
caso P06 REPROVA $? "negativo: user.email fora do noreply (autor e committer)"

novo_repo p07 && mkdir -p livro-1/texto && printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && commita --author="Outro <outro@exemplo.invalid>" -m "feat: caso limite, --author fora do gate local (SG-02)"
caso P07 REPROVA $? "negativo: --author fora do noreply tambem e barrado pelo pre-commit (medido); gate: $(grep FALHOU "$SCR/saida.txt" | head -1)"

novo_repo p08 && printf 'x\n' > a.md && git add -A && commita -m "update stuff (SG-02)"
caso P08 REPROVA $? "negativo commit-msg: sem tipo Conventional Commits; gate: $(head -1 "$SCR/saida.txt")"

novo_repo p09 && printf 'x\n' > a.md && git add -A && commita -m "feat: adiciona teste"
caso P09 REPROVA $? "negativo commit-msg: sem ID entre parenteses no assunto"

novo_repo p10 && printf 'x\n' > a.md && git add -A && commita -m "feat: caso (SG-02)" -m "Claude-Session: https://exemplo.invalid/sessao"
caso P10 REPROVA $? "negativo commit-msg: linha Claude-Session no corpo"

novo_repo p11 && printf 'x\n' > a.md && git add -A && commita -m "feat: caso positivo com rodape de coautoria (SG-02)" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
caso P11 OK $? "positivo: Co-Authored-By permitido"

novo_repo p12 && commita --allow-empty -m "feat: varredura vazia (SG-02)"
caso P12 REPROVA $? "varredura vazia: commit sem nenhum arquivo no indice; gate: $(grep -c FALHOU "$SCR/saida.txt") falha(s)"

novo_repo p13 && printf 'x\n' > a.md && git add -A && git config --local --unset filter.git-crypt.required && \
    commita -m "feat: caso negativo, filtro sem configuracao local (SG-02)"
caso P13 REPROVA $? "negativo: filtro git-crypt sem required=true (falha fechada); gate: $(grep FALHOU "$SCR/saida.txt" | head -1)"

novo_repo p14 && printf 'x\n' > a.md && git add -A && RC_GLOBAL=1 commita -m "feat: caso negativo, hook global reprova (SG-02)"
caso P14 REPROVA $? "negativo do encadeamento: gate local passa, hook global sai com 1; marcas: $(marcas)"

# Lote: os IDs da tabela do TODO.md passam; formatos ruins reprovam. Um processo para o lote inteiro.
awk -F'|' '/^\| [0-9.]+ \|/{c=$3; gsub(/ /,"",c); print "feat: teste (" c ")"}' "$RAIZ/TODO.md" > "$SCR/assuntos-ok.txt"
printf 'update: x (SG-02)\nfeat: sem id\nfeat: x (sg-02)\n' > "$SCR/assuntos-ruim.txt"
python3 "$PORTAO/portoes.py" assuntos < "$SCR/assuntos-ok.txt" > "$SCR/lote-ok.txt" 2>&1
caso P15 OK $? "lote positivo, todos os IDs da tabela: $(head -1 "$SCR/lote-ok.txt")"
python3 "$PORTAO/portoes.py" assuntos < "$SCR/assuntos-ruim.txt" > "$SCR/lote-ruim.txt" 2>&1
caso P16 REPROVA $? "lote negativo, 3 formatos ruins: $(head -1 "$SCR/lote-ruim.txt")"

# ---------- ci (sem chave) ----------
novo_repo c01 && printf 'x\n' > a.md && mkdir -p livro-1/texto && \
    printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && git add -A && commita -m "feat: base positiva (SG-02)"
git clone -q "$SCR/c01" "$SCR/c01-clone" 2>/dev/null
( cd "$SCR/c01-clone" && test ! -e .git/git-crypt/keys/default && python3 "$PORTAO/portoes.py" ci >"$SCR/ci-c01.txt" 2>&1 )
caso C01 OK $? "ci positivo, clone sem chave: $(grep -c 'FALHOU' "$SCR/ci-c01.txt") falha(s); $(head -2 "$SCR/ci-c01.txt" | tr '\n' ' ')"

novo_repo c02 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    sha=$(printf 'claro\n' | git hash-object -w --stdin) && git update-index --add --cacheinfo "100644,$sha,notas/cru.md" && \
    commit_sem_gate "feat: blob em claro sem gate (SG-02)" && git clone -q "$SCR/c02" "$SCR/c02-clone" 2>/dev/null
( cd "$SCR/c02-clone" && python3 "$PORTAO/portoes.py" ci >"$SCR/ci-c02.txt" 2>&1 )
caso C02 REPROVA $? "ci negativo, blob em claro em caminho cifrado: $(grep FALHOU "$SCR/ci-c02.txt" | head -1 | cut -c1-60)"

novo_repo c03 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    commit_sem_gate "feat: autor fora do noreply (SG-02)" outro@exemplo.invalid && git clone -q "$SCR/c03" "$SCR/c03-clone" 2>/dev/null
( cd "$SCR/c03-clone" && python3 "$PORTAO/portoes.py" ci >"$SCR/ci-c03.txt" 2>&1 )
caso C03 REPROVA $? "ci negativo, autor fora do noreply (commit feito sem gate): $(grep FALHOU "$SCR/ci-c03.txt" | head -1 | cut -c1-70)"

novo_repo c04 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    commit_sem_gate "$(printf 'feat: sessao citada (SG-02)\n\nClaude-Session: https://exemplo.invalid/s')" && git clone -q "$SCR/c04" "$SCR/c04-clone" 2>/dev/null
( cd "$SCR/c04-clone" && python3 "$PORTAO/portoes.py" ci >"$SCR/ci-c04.txt" 2>&1 )
caso C04 REPROVA $? "ci negativo, Claude-Session no historico: $(grep FALHOU "$SCR/ci-c04.txt" | head -1 | cut -c1-60)"

novo_repo c05 && (cd "$SCR/c05" && git init -q -b main . 2>/dev/null; true)
( cd "$SCR/c05" && python3 "$PORTAO/portoes.py" ci >"$SCR/ci-c05.txt" 2>&1 )
caso C05 REPROVA $? "ci varredura vazia, historico sem commit: $(grep FALHOU "$SCR/ci-c05.txt" | head -1 | cut -c1-60)"

# ---------- resumo ----------
echo "RESUMO casos=$CASOS falharam=$FALHAS"
[ "$FALHAS" -eq 0 ] && [ "$CASOS" -gt 0 ]
