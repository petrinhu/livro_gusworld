# Grupo TH: segunda re-sabotagem independente (SG-02d). Carregado por rodar.sh depois de casos-sg02c.sh,
# do qual usa heuristica_caso e amostra. Regra: nenhum travessao literal aqui; ele vem de $TRAV (comum.sh).
# Montagem que falha vira FALHOU do caso: rc=0 quando se espera REPROVA, rc=1 quando se espera OK.

letras() { # ARQUIVO TAMANHO: arquivo com TAMANHO letras a
    mkdir -p "$(dirname "$1")" && head -c "$2" /dev/zero | tr '\0' 'a' > "$1"
}

tres_amostras() { # tres arquivos de 6000 bytes na amostra, no indice
    amostra c01.md 6000 && amostra c02.md 6000 && amostra c03.md 6000 &&
        git add ferramentas/montagem/amostra/texto/c01.md ferramentas/montagem/amostra/texto/c02.md \
            ferramentas/montagem/amostra/texto/c03.md
}

aninhada() { # NOME: tag interna (tagger externo, travessao), tag externa noreply sobre ela; apaga a ref interna
    ( cd "$SCR/$1" && GIT_COMMITTER_NAME=Externo GIT_COMMITTER_EMAIL=externo@exemplo.invalid \
        git tag -a interna -m "interna $TRAV externa" ) &&
    git -C "$SCR/$1" -c advice.nestedTag=false tag -a v0-externa -m "externa ok" interna &&
    git -C "$SCR/$1" tag -d interna >/dev/null
}

# TH1 a TH3 (C1, DD1): teto por arquivo em claro
if novo_repo th1 && letras ferramentas/montagem/th.py 16385 && git add ferramentas/montagem/th.py; then
    commita -m "feat: script grande (SG-02)"; rc=$?
else rc=0; fi
caso TH1 REPROVA "$rc" "arquivo em claro acima do teto" "$SCR/saida.txt" "C1: arquivo em claro acima do teto, local"
if novo_repo th2 && letras ferramentas/montagem/th.py 16384 && git add ferramentas/montagem/th.py; then
    commita -m "feat: script no teto (SG-02)"; rc=$?
else rc=1; fi
caso TH2 OK "$rc" - - "C1: arquivo em claro no teto passa"
if novo_repo th3 && SEM=$(git rev-parse HEAD) && letras ferramentas/montagem/th.py 16385 &&
    git add ferramentas/montagem/th.py && commit_sem_gate "feat: script grande sem gate (SG-02)"; then
    ci_simulado th3 "$SEM" "$SCR/ci-th3.txt"; rc=$?
else rc=0; fi
caso TH3 REPROVA "$rc" "arquivo em claro acima do teto" "$SCR/ci-th3.txt" "C1: arquivo em claro acima do teto, CI"

# TH4 a TH7 (C1, DD1): teto total da amostra por arvore
if novo_repo th4 && tres_amostras; then
    commita -m "feat: amostra em tres partes (SG-02)"; rc=$?
else rc=0; fi
caso TH4 REPROVA "$rc" "amostra acima do teto total da arvore" "$SCR/saida.txt" "C1: amostra acima do teto total, local"
if novo_repo th5 && amostra c01.md 8192 && amostra c02.md 8192 &&
    git add ferramentas/montagem/amostra/texto/c01.md ferramentas/montagem/amostra/texto/c02.md; then
    commita -m "feat: amostra no teto total (SG-02)"; rc=$?
else rc=1; fi
caso TH5 OK "$rc" - - "C1: amostra no teto total passa"
if novo_repo th6 && SEM=$(git rev-parse HEAD) && tres_amostras && commit_sem_gate "feat: amostra sem gate (SG-02)"; then
    ci_simulado th6 "$SEM" "$SCR/ci-th6.txt"; rc=$?
else rc=0; fi
caso TH6 REPROVA "$rc" "amostra acima do teto total da arvore" "$SCR/ci-th6.txt" "C1: amostra acima do teto total, CI"
if novo_repo th7 && remoto_novo th7 && empurra th7 >/dev/null 2>&1 && tres_amostras &&
    commit_sem_gate "feat: amostra sem gate (SG-02)"; then
    empurra th7; rc=$?
else rc=0; fi
caso TH7 REPROVA "$rc" "amostra acima do teto total da arvore" "$SCR/saida-envia.txt" "C1: amostra acima do teto total, envio"

# TH8 a TH11 e TH19 (C2, DD2): teto da mensagem e do objeto
CORPO_LONGO=$(head -c 2100 /dev/zero | tr '\0' 'a')
if novo_repo th8 && printf 'b\n' > b.md && git add b.md; then
    commita -m "feat: nota (FU-04)" -m "$CORPO_LONGO"; rc=$?
else rc=0; fi
caso TH8 REPROVA "$rc" "mensagem acima do teto de bytes" "$SCR/saida.txt" "C2: corpo de commit acima do teto, local"
if novo_repo th9 && printf 'b\n' > b.md && git add b.md; then
    commita -m "feat: nota (FU-04)" -m "$(head -c 1900 /dev/zero | tr '\0' 'a')"; rc=$?
else rc=1; fi
caso TH9 OK "$rc" - - "C2: corpo de commit abaixo do teto passa"
if novo_repo th10 && SEM=$(git rev-parse HEAD) && printf 'b\n' > b.md && git add b.md &&
    commit_sem_gate "$(printf 'feat: nota (FU-04)\n\n%s' "$CORPO_LONGO")"; then
    ci_simulado th10 "$SEM" "$SCR/ci-th10.txt"; rc=$?
else rc=0; fi
caso TH10 REPROVA "$rc" "mensagem acima do teto de bytes" "$SCR/ci-th10.txt" "C2: corpo de commit acima do teto, CI"
if novo_repo th11 && printf 'x\n' > a.md && git add a.md && commita -m "feat: base (SG-02)" &&
    printf 'v0 th11\n\n%s\n' "$CORPO_LONGO" > "$SCR/msg-th11.txt" &&
    git -C "$SCR/th11" tag -a v0-th11 -F "$SCR/msg-th11.txt"; then
    ci_simulado th11 "$ZERO" "$SCR/ci-th11.txt"; rc=$?
else rc=0; fi
caso TH11 REPROVA "$rc" "mensagem acima do teto de bytes" "$SCR/ci-th11.txt" "C2: mensagem de tag acima do teto, CI"
if novo_repo th19 && SEM=$(git rev-parse HEAD) && printf 'b\n' > b.md && git add b.md &&
    ( export GIT_AUTHOR_NAME="$(head -c 4000 /dev/zero | tr '\0' 'a')" && commit_sem_gate "feat: nota (FU-04)" ); then
    ci_simulado th19 "$SEM" "$SCR/ci-th19.txt"; rc=$?
else rc=0; fi
caso TH19 REPROVA "$rc" "objeto commit acima do teto de bytes" "$SCR/ci-th19.txt" "C2: objeto commit acima do teto, CI"

# TH12 a TH14 (A2, DD4): tag julgada pelo objeto
if novo_repo th12 && printf 'x\n' > a.md && git add a.md && commita -m "feat: base (SG-02)" && aninhada th12; then
    ci_simulado th12 "$ZERO" "$SCR/ci-th12.txt"; rc=$?
else rc=0; fi
caso TH12 REPROVA "$rc" "tag aninhada" "$SCR/ci-th12.txt" "A2: tag aninhada, CI"
if novo_repo th13 && remoto_novo th13 && empurra th13 >/dev/null 2>&1 && aninhada th13; then
    git -C "$SCR/th13" push -q origin refs/tags/v0-externa > "$SCR/saida-envia.txt" 2>&1; rc=$?
else rc=0; fi
caso TH13 REPROVA "$rc" "tag aninhada" "$SCR/saida-envia.txt" "A2: tag aninhada, envio"
if novo_repo th14 && remoto_novo th14 && empurra th14 >/dev/null 2>&1 &&
    ( cd "$SCR/th14" && GIT_COMMITTER_NAME=Externo GIT_COMMITTER_EMAIL=externo@exemplo.invalid \
        git tag -a v0-solta -m "solta" ) &&
    T=$(git -C "$SCR/th14" rev-parse v0-solta) && git -C "$SCR/th14" tag -d v0-solta >/dev/null; then
    git -C "$SCR/th14" push -q origin "$T:refs/tags/v0-solta" > "$SCR/saida-envia.txt" 2>&1; rc=$?
else rc=0; fi
caso TH14 REPROVA "$rc" "tagger fora do noreply" "$SCR/saida-envia.txt" "A2: tag enviada por hash, sem ref local, envio"

# TH15 a TH18 (C3 e A1, DD3): heuristica por janela
heuristica_caso TH15 prefixo 20480 REPROVA "corpo legivel apos o cabecalho cifrado" "C3: texto depois de 64 KiB aleatorios"
heuristica_caso TH16 ruido79 4096 REPROVA "corpo legivel apos o cabecalho cifrado" "A1: texto com 21 por cento de bytes altos"
heuristica_caso TH17 aleatorio 86016 OK "suspeitos=0" "controle: 86016 bytes aleatorios em 21 janelas"
heuristica_caso TH18 diluido05 4096 OK "suspeitos=0" "fronteira K3: texto diluido a 5 por cento passa sem chave"
