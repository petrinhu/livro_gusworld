# Grupo TG: re-sabotagem independente (SG-02). Carregado por rodar.sh.
# Regra: nenhum travessao, entidade ou homoglifo literal aqui; tudo nasce por printf em octal.
# Montagem que falha vira FALHOU do caso: rc=0 quando se espera REPROVA, rc=1 quando se espera OK.

plano() { # CAMINHO: blob em claro no indice, sem filtro
    local sha
    sha=$(printf 'Abertura do capitulo.\n' | git hash-object -w --stdin) || return 1
    git update-index --add --cacheinfo "100644,$sha,$1"
}

forja_imprime() { # troca o retorno de imprime por True no portao do repositorio atual e poe no indice
    sed -i 's/^    return (encontrados > 0 or vazia_ok) and analisados == encontrados and not falhas$/    return True/' \
        ferramentas/portoes/portao_git.py || return 1
    ! grep -qF 'and analisados == encontrados and not falhas' ferramentas/portoes/portao_git.py || return 1
    git add ferramentas/portoes/portao_git.py
}

forja_silenciosa() { # troca o portoes.py por um que imprime contagens limpas falsas e sai 0; poe no indice
    printf 'import sys\nfor n in ("ci-refs", "ci-commits", "ci-assuntos", "ci-blobs", "ci-confianca", "ci-tags",\n          "envio-refs", "envio-commits", "envio-assuntos", "envio-blobs", "envio-confianca", "envio-tags", "envio-chave"):\n    print(f"[{n}] encontrados=1 analisados=1 falharam=0")\nprint("[ci-heuristica] cifrados=1 avaliados=1 pequenos=0 suspeitos=0")\nsys.exit(0)\n' \
        > ferramentas/portoes/portoes.py && git add ferramentas/portoes/portoes.py
}

# TG1 (C1): bootstrap do proprio commit com exit 0 e capitulo em claro; CI com base da semente
if novo_repo tg1 && SEM=$(git rev-parse HEAD) && sed -i '1a exit 0' ferramentas/portoes/ci-bootstrap.sh &&
    git add ferramentas/portoes/ci-bootstrap.sh && plano livro-1/texto/c1.md &&
    commit_sem_gate "feat: bootstrap trocado (SG-02)"; then
    ci_simulado tg1 "$SEM" "$SCR/ci-tg1.txt"; rc=$?
else rc=0; fi
caso TG1 REPROVA "$rc" "ci-bootstrap.sh fora do hash fixado no workflow" "$SCR/ci-tg1.txt" "C1: bootstrap do proprio commit nao roda"

# TG2 (fronteira K1): o mesmo, com o hash fixado no workflow trocado no mesmo commit
if novo_repo tg2 && SEM=$(git rev-parse HEAD) && sed -i '1a exit 0' ferramentas/portoes/ci-bootstrap.sh &&
    git add ferramentas/portoes/ci-bootstrap.sh && B=$(git rev-parse :ferramentas/portoes/ci-bootstrap.sh) &&
    sed -i "s/^\( *BOOTSTRAP_BLOB: *\)[0-9a-f]\{40\}/\1$B/" .github/workflows/sigilo.yml &&
    git add .github/workflows/sigilo.yml && plano livro-1/texto/c1.md &&
    commit_sem_gate "feat: workflow e bootstrap trocados (SG-02)"; then
    ci_simulado tg2 "$SEM" "$SCR/ci-tg2.txt"; rc=$?
else rc=1; fi
caso TG2 OK "$rc" - - "fronteira K1: workflow trocado no proprio envio passa no CI"

# TG3 (C2, CI): commit X com imprime forjado; commit Y com capitulo em claro; CI com base X
if novo_repo tg3 && forja_imprime && commit_sem_gate "feat: portao forjado (SG-02)" && X=$(git rev-parse HEAD) &&
    plano livro-1/texto/c1.md && commit_sem_gate "feat: capitulo em claro (SG-02)"; then
    ci_simulado tg3 "$X" "$SCR/ci-tg3.txt"; rc=$?
else rc=0; fi
caso TG3 REPROVA "$rc" "saida do portao com falha impressa" "$SCR/ci-tg3.txt" "C2: veredito lido de novo no CI"

# TG4 (C2, local, sem --no-verify): X normal com imprime forjado; Y normal com capitulo em claro
if novo_repo tg4 && forja_imprime && commita -m "fix: portao forjado (SG-02)" && plano livro-1/texto/c1.md; then
    commita -m "feat: capitulo em claro (SG-02)"; rc=$?
else rc=0; fi
caso TG4 REPROVA "$rc" "saida do portao com falha impressa" "$SCR/saida.txt" "C2: veredito lido de novo no gancho local"

# TG5 (sumidouro): ci() que devolve True; capitulo em claro; portoes.py ci direto, sem bootstrap
if novo_repo tg5 &&
    sed -i 's/^    return all(\[ok_refs, ok_commits, ok_assuntos, ok_blobs, not falhas_heu, ok_conf, ok_tags\])$/    return True/' \
        ferramentas/portoes/portao_historico.py &&
    ! grep -qF 'return all([ok_refs, ok_commits, ok_assuntos, ok_blobs, not falhas_heu' ferramentas/portoes/portao_historico.py &&
    git add ferramentas/portoes/portao_historico.py && commit_sem_gate "feat: ci que ignora o resultado (SG-02)" &&
    plano livro-1/texto/c1.md && commit_sem_gate "feat: capitulo em claro (SG-02)" &&
    rm -rf "$SCR/tg5-cl" && git clone -q "$SCR/tg5" "$SCR/tg5-cl"; then
    ( cd "$SCR/tg5-cl" && python3 -I ferramentas/portoes/portoes.py ci ) > "$SCR/ci-tg5.txt" 2>&1; rc=$?
else rc=0; fi
caso TG5 REPROVA "$rc" "sem cabecalho cifrado" "$SCR/ci-tg5.txt" "sumidouro: linha FALHOU impressa forca codigo 1"

# TG6 (A1, CI): main limpo; ramo b novo com portao forjado silencioso e capitulo em claro; base zero
if novo_repo tg6 && git switch -q -c b && forja_silenciosa && plano livro-1/texto/c1.md &&
    commit_sem_gate "feat: ramo novo forjado (SG-02)"; then
    ci_simulado_ramo tg6 b "$ZERO" "$SCR/ci-tg6.txt"; rc=$?
else rc=0; fi
caso TG6 REPROVA "$rc" "sem cabecalho cifrado" "$SCR/ci-tg6.txt" "A1: base zero usa a ponta publicada do ramo padrao"

# TG7 (A1, CI): sem ramo padrao publicado, base zero fecha
if novo_repo tg7 && git branch -m main b; then
    ci_simulado tg7 "$ZERO" "$SCR/ci-tg7.txt"; rc=$?
else rc=0; fi
caso TG7 REPROVA "$rc" "base zero sem ramo padrao publicado" "$SCR/ci-tg7.txt" "A1: sem ramo padrao publicado o CI fecha"

# TG8 (A1, envio): main publicado limpo; ramo b novo com portao forjado silencioso; push de b
if novo_repo tg8 && remoto_novo tg8 && empurra tg8 && git switch -q -c b && forja_silenciosa &&
    plano livro-1/texto/c1.md && commit_sem_gate "feat: ramo novo forjado (SG-02)"; then
    empurra_ramo tg8 b; rc=$?
else rc=0; fi
caso TG8 REPROVA "$rc" "sem cabecalho cifrado" "$SCR/saida-envia.txt" "A1 no envio: ramo novo julgado pelo ramo padrao publicado"

# TG9 a TG16 (A2, H7): corpo forjado com cabecalho; CI com base da semente
heuristica_caso() { # ID TIPO N ESPERADO TRECHO DESCRICAO
    local nome sha
    nome=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
    if novo_repo "$nome" && SEM=$(git rev-parse HEAD) &&
        python3 -I "$TST/gera_corpo.py" "$2" "$3" > "$SCR/$nome.bin" &&
        sha=$(git hash-object -w --no-filters "$SCR/$nome.bin") &&
        git update-index --add --cacheinfo "100644,$sha,livro-1/texto/h.md" &&
        commit_sem_gate "feat: corpo forjado (SG-02)"; then
        ci_simulado "$nome" "$SEM" "$SCR/ci-$nome.txt"; rc=$?
    elif [ "$4" = OK ]; then rc=1; else rc=0; fi
    caso "$1" "$4" "$rc" "$5" "$SCR/ci-$nome.txt" "$6"
}
heuristica_caso TG9 utf16 240 REPROVA "corpo legivel apos o cabecalho cifrado" "A2: texto em UTF-16"
heuristica_caso TG10 gzip 370 REPROVA "corpo legivel apos o cabecalho cifrado" "A2: texto em gzip"
heuristica_caso TG11 intercalado 120 REPROVA "corpo legivel apos o cabecalho cifrado" "A2: controle a cada 3 letras"
heuristica_caso TG12 razao079 100 REPROVA "corpo legivel apos o cabecalho cifrado" "A2: razao de imprimiveis 0,79"
heuristica_caso TG13 xor80 150 REPROVA "corpo legivel apos o cabecalho cifrado" "A2: texto com o bit alto trocado"
heuristica_caso TG14 letras 12 REPROVA "corpo legivel apos o cabecalho cifrado" "H7: corpo de 12 bytes legivel"
heuristica_caso TG15 letras 11 OK "pequenos=1" "fronteira K3: corpo de 11 bytes passa sem chave"
heuristica_caso TG16 deflate 370 OK "[ci-heuristica]" "fronteira K3: deflate sem cabecalho passa sem chave"

# TG17 (controle): sete corpos aleatorios de 12 a 4096 bytes nao sao suspeitos
if novo_repo tg17 && SEM=$(git rev-parse HEAD) && rm -rf "$SCR/tg17-lote" && mkdir -p "$SCR/tg17-lote" &&
    python3 -I "$TST/gera_corpo.py" aleatorio-lote "$SCR/tg17-lote" &&
    shas=$(cd "$SCR/tg17-lote" && git -C "$SCR/tg17" hash-object -w --no-filters \
        "$SCR/tg17-lote/r12.bin" "$SCR/tg17-lote/r23.bin" "$SCR/tg17-lote/r24.bin" "$SCR/tg17-lote/r63.bin" \
        "$SCR/tg17-lote/r64.bin" "$SCR/tg17-lote/r188.bin" "$SCR/tg17-lote/r4096.bin") &&
    printf '%s\n' $shas | paste - <(printf 'livro-1/texto/r%s.md\n' 12 23 24 63 64 188 4096) |
        sed 's/^/100644 /' | git update-index --index-info &&
    commit_sem_gate "feat: corpos aleatorios (SG-02)"; then
    ci_simulado tg17 "$SEM" "$SCR/ci-tg17.txt"; rc=$?
else rc=1; fi
caso TG17 OK "$rc" "suspeitos=0" "$SCR/ci-tg17.txt" "controle: corpo aleatorio de 12 a 4096 bytes nao e suspeito"

# TG18a e TG18b (M2): arquivo que nao e .md em pasta de texto
if novo_repo tg18a && mkdir -p livro-1/texto && printf '%%PDF-1.4\n' > livro-1/texto/anexo.pdf &&
    git add livro-1/texto/anexo.pdf; then
    commita -m "feat: anexo (SG-02)"; rc=$?
else rc=0; fi
caso TG18a REPROVA "$rc" "forma nao aprovada em pasta de texto" "$SCR/saida.txt" "M2: binario em pasta de texto, local"
if novo_repo tg18b && SEM=$(git rev-parse HEAD) && mkdir -p livro-1/texto && printf '%%PDF-1.4\n' > livro-1/texto/anexo.pdf &&
    git add livro-1/texto/anexo.pdf && commit_sem_gate "feat: anexo sem gate (SG-02)"; then
    ci_simulado tg18b "$SEM" "$SCR/ci-tg18b.txt"; rc=$?
else rc=0; fi
caso TG18b REPROVA "$rc" "forma nao aprovada em pasta de texto" "$SCR/ci-tg18b.txt" "M2: binario em pasta de texto, CI"

# TG19a a TG19c (M1): teto da amostra em claro
amostra() { # ARQUIVO TAMANHO: arquivo da amostra com TAMANHO letras
    mkdir -p ferramentas/montagem/amostra/texto && head -c "$2" /dev/zero | tr '\0' 'a' > "ferramentas/montagem/amostra/texto/$1"
}
if novo_repo tg19a && amostra c98.md 8193 && git add ferramentas/montagem/amostra/texto/c98.md; then
    commita -m "feat: amostra (SG-02)"; rc=$?
else rc=0; fi
caso TG19a REPROVA "$rc" "amostra acima do teto" "$SCR/saida.txt" "M1: amostra um byte acima do teto, local"
if novo_repo tg19b && amostra c97.md 8192 && git add ferramentas/montagem/amostra/texto/c97.md; then
    commita -m "feat: amostra (SG-02)"; rc=$?
else rc=1; fi
caso TG19b OK "$rc" - - "M1: amostra no teto passa"
if novo_repo tg19c && SEM=$(git rev-parse HEAD) && amostra c96.md 8193 &&
    git add ferramentas/montagem/amostra/texto/c96.md && commit_sem_gate "feat: amostra sem gate (SG-02)"; then
    ci_simulado tg19c "$SEM" "$SCR/ci-tg19c.txt"; rc=$?
else rc=0; fi
caso TG19c REPROVA "$rc" "amostra acima do teto" "$SCR/ci-tg19c.txt" "M1: amostra acima do teto, CI"

# TG20a e TG20b (M3): rotulo com C cirilico (U+0421) no rodape
printf 'feat: nota (FU-04)\n\n\320\241laude-Session: x\n' > "$SCR/msg-tg20.txt"
if novo_repo tg20a && printf 'b\n' > b.md && git add b.md; then
    commita -F "$SCR/msg-tg20.txt"; rc=$?
else rc=0; fi
caso TG20a REPROVA "$rc" "rodape fora do modelo" "$SCR/saida.txt" "M3: homoglifo no rodape, local"
if novo_repo tg20b && SEM=$(git rev-parse HEAD) && printf 'b\n' > b.md && git add b.md &&
    commit_sem_gate "$(cat "$SCR/msg-tg20.txt")"; then
    ci_simulado tg20b "$SEM" "$SCR/ci-tg20b.txt"; rc=$?
else rc=0; fi
caso TG20b REPROVA "$rc" "rodape fora do modelo" "$SCR/ci-tg20b.txt" "M3: homoglifo no rodape, CI"

# TG21a a TG21c (M5): coautor fora do noreply da Anthropic
if novo_repo tg21a && printf 'b\n' > b.md && git add b.md; then
    commita -m "feat: nota (FU-04)" -m "Co-Authored-By: Fulano <fulano@exemplo.com>"; rc=$?
else rc=0; fi
caso TG21a REPROVA "$rc" "rodape fora do modelo" "$SCR/saida.txt" "M5: coautor externo, local"
if novo_repo tg21b && printf 'b\n' > b.md && git add b.md; then
    commita -m "feat: nota (FU-04)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; rc=$?
else rc=1; fi
caso TG21b OK "$rc" - - "M5: rodape no modelo passa"
if novo_repo tg21c && SEM=$(git rev-parse HEAD) && printf 'b\n' > b.md && git add b.md &&
    commit_sem_gate "$(printf 'feat: nota (FU-04)\n\nCo-Authored-By: Fulano <fulano@exemplo.com>')"; then
    ci_simulado tg21c "$SEM" "$SCR/ci-tg21c.txt"; rc=$?
else rc=0; fi
caso TG21c REPROVA "$rc" "rodape fora do modelo" "$SCR/ci-tg21c.txt" "M5: coautor externo, CI"

# TG22a e TG22b (A3): export-ignore no .gitattributes da raiz nao tira arquivo do portao extraido
if novo_repo tg22a && printf 'ferramentas/portoes/portao_cifra.py export-ignore\n' >> .gitattributes &&
    git add .gitattributes && commit_sem_gate "chore: atributo de exportacao (SG-02)" &&
    printf 'b\n' > b.md && git add b.md; then
    commita -m "feat: b (SG-02)"; rc=$?
else rc=1; fi
caso TG22a OK "$rc" "[cifra] encontrados=" "$SCR/saida.txt" "A3: portao extraido inteiro, local"
if novo_repo tg22b && printf 'ferramentas/portoes/ci-base.sh export-ignore\n' >> .gitattributes &&
    git add .gitattributes && commit_sem_gate "chore: atributo de exportacao (SG-02)" && X=$(git rev-parse HEAD) &&
    printf 'b\n' > b.md && git add b.md && commit_sem_gate "feat: b (SG-02)"; then
    ci_simulado tg22b "$X" "$SCR/ci-tg22b.txt"; rc=$?
else rc=1; fi
caso TG22b OK "$rc" "[ci-blobs] encontrados=" "$SCR/ci-tg22b.txt" "A3: portao da base extraido inteiro, CI"

# TG23: as duas copias de confere_saida sao iguais e nao vazias
a=$(sed -n '/^confere_saida() {/,/^}/p' "$FONTE/confiavel.sh")
b=$(sed -n '/^confere_saida() {/,/^}/p' "$FONTE/ci-bootstrap.sh")
[ -n "$a" ] && [ "$a" = "$b" ]; rc=$?
caso TG23 OK "$rc" - - "copias de confere_saida iguais em confiavel.sh e ci-bootstrap.sh"
