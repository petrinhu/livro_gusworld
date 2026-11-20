# Casos atuais dos portoes (P01 a P16, C01 a C05). Todos OK no legado.
# Carregado por rodar.sh; usa as funcoes de comum.sh.

# ---------- pre-commit ----------
novo_repo p01 && printf 'texto cifrado\n' > a.md && mkdir -p "livro-1/texto" && \
    printf 'Abertura do capitulo.\n\n%s Oi, disse ele.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && commita -m "feat: caso positivo com fala no inicio de paragrafo (SG-02)"
caso P01 OK $? - - "positivo: cifra, fala com travessao e ponte de hook global; marcas: $(marcas)"

novo_repo p02 && sha=$(printf 'claro\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,notas/cru.md" && \
    commita -m "feat: caso negativo, blob em claro em caminho cifrado (SG-02)"
caso P02 REPROVA $? - - "negativo: arquivo em claro no indice fora da excecao"

novo_repo p03 && mkdir -p livro-1/texto && printf 'Ele disse %s oi.\n' "$TRAV" > livro-1/texto/c2.md && \
    git add -A && commita -m "feat: caso negativo, travessao no meio da frase (SG-02)"
caso P03 REPROVA $? - - "negativo: travessao fora de inicio de fala no texto"

novo_repo p04 && mkdir -p projeto && printf '%s nota fora do texto\n' "$TRAV" > projeto/a.md && \
    git add -A && commita -m "feat: caso negativo, travessao fora da pasta de texto (SG-02)"
caso P04 REPROVA $? - - "negativo: travessao no inicio de linha fora de livro-*/texto"

novo_repo p05 && mkdir -p livro-1/texto && printf 'Faixa 1%s2 do livro.\n' "$MEIO" > livro-1/texto/c3.md && \
    git add -A && commita -m "feat: caso negativo, meio-travessao no texto (SG-02)"
caso P05 REPROVA $? - - "negativo: meio-travessao U+2013 no meio da linha"

novo_repo p06 && mkdir -p livro-1/texto && printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && git -c user.email=outro@exemplo.invalid commit -q -m "feat: caso negativo, e-mail do autor errado (SG-02)" >"$SCR/saida.txt" 2>&1
caso P06 REPROVA $? - - "negativo: user.email fora do noreply (autor e committer)"

novo_repo p07 && mkdir -p livro-1/texto && printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && \
    git add -A && commita --author="Outro <outro@exemplo.invalid>" -m "feat: caso limite, --author fora do gate local (SG-02)"
caso P07 REPROVA $? - - "negativo: --author fora do noreply tambem e barrado pelo pre-commit"

novo_repo p08 && printf 'x\n' > a.md && git add -A && commita -m "update stuff (SG-02)"
caso P08 REPROVA $? - - "negativo commit-msg: sem tipo Conventional Commits"

novo_repo p09 && printf 'x\n' > a.md && git add -A && commita -m "feat: adiciona teste"
caso P09 REPROVA $? - - "negativo commit-msg: sem ID entre parenteses no assunto"

novo_repo p10 && printf 'x\n' > a.md && git add -A && commita -m "feat: caso (SG-02)" -m "Claude-Session: https://exemplo.invalid/sessao"
caso P10 REPROVA $? - - "negativo commit-msg: linha Claude-Session no corpo"

novo_repo p11 && printf 'x\n' > a.md && git add -A && commita -m "feat: caso positivo com rodape de coautoria (SG-02)" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
caso P11 OK $? - - "positivo: Co-Authored-By permitido"

novo_repo p12 && git rm -r -q --cached . && commita --allow-empty -m "feat: varredura vazia (SG-02)"
caso P12 REPROVA $? - - "varredura vazia: commit sem nenhum arquivo no indice; falhas: $(grep -c FALHOU "$SCR/saida.txt")"

novo_repo p13 && printf 'x\n' > a.md && git add -A && git config --local --unset filter.git-crypt.required && \
    commita -m "feat: caso negativo, filtro sem configuracao local (SG-02)"
caso P13 REPROVA $? - - "negativo: filtro git-crypt sem required=true (falha fechada)"

novo_repo p14 && printf 'x\n' > a.md && git add -A && RC_GLOBAL=1 commita -m "feat: caso negativo, hook global reprova (SG-02)"
caso P14 REPROVA $? - - "negativo do encadeamento: gate local passa, hook global sai com 1; marcas: $(marcas)"

# Lote: os IDs da tabela do TODO.md passam; formatos ruins reprovam. Um processo para o lote inteiro.
cd "$SCR" || exit 1
awk -F'|' '/^\| [0-9.]+ \|/{c=$3; gsub(/ /,"",c); print "feat: teste (" c ")"}' "$RAIZ/TODO.md" > "$SCR/assuntos-ok.txt"
printf 'update: x (SG-02)\nfeat: sem id\nfeat: x (sg-02)\n' > "$SCR/assuntos-ruim.txt"
python3 "$FONTE/portoes.py" assuntos < "$SCR/assuntos-ok.txt" > "$SCR/lote-ok.txt" 2>&1
caso P15 OK $? - - "lote positivo, todos os IDs da tabela: $(head -1 "$SCR/lote-ok.txt")"
python3 "$FONTE/portoes.py" assuntos < "$SCR/assuntos-ruim.txt" > "$SCR/lote-ruim.txt" 2>&1
caso P16 REPROVA $? - - "lote negativo, 3 formatos ruins: $(head -1 "$SCR/lote-ruim.txt")"

# ---------- ci (sem chave) ----------
novo_repo c01 && printf 'x\n' > a.md && mkdir -p livro-1/texto && \
    printf 'Abertura.\n\n%s Oi.\n' "$TRAV" > "livro-1/texto/capitulo um.md" && git add -A && commita -m "feat: base positiva (SG-02)"
ci_simulado c01 "$ZERO" "$SCR/ci-c01.txt"
caso C01 OK $? - - "ci positivo, clone sem chave: $(grep -c FALHOU "$SCR/ci-c01.txt") falha(s)"

novo_repo c02 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    sha=$(printf 'claro\n' | git hash-object -w --stdin) && git update-index --add --cacheinfo "100644,$sha,notas/cru.md" && \
    commit_sem_gate "feat: blob em claro sem gate (SG-02)"
ci_simulado c02 "$ZERO" "$SCR/ci-c02.txt"
caso C02 REPROVA $? - - "ci negativo, blob em claro em caminho cifrado"

novo_repo c03 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    commit_sem_gate "feat: autor fora do noreply (SG-02)" outro@exemplo.invalid
ci_simulado c03 "$ZERO" "$SCR/ci-c03.txt"
caso C03 REPROVA $? - - "ci negativo, autor fora do noreply (commit feito sem gate)"

novo_repo c04 && printf 'x\n' > a.md && git add -A && commita -m "feat: base (SG-02)" && \
    commit_sem_gate "$(printf 'feat: sessao citada (SG-02)\n\nClaude-Session: https://exemplo.invalid/s')"
ci_simulado c04 "$ZERO" "$SCR/ci-c04.txt"
caso C04 REPROVA $? - - "ci negativo, Claude-Session no historico"

# C05 precisa de historico vazio: repositorio nu, sem semente.
mkdir -p "$SCR/c05" && git -C "$SCR/c05" init -q -b main
ci_aqui c05 "$ZERO" "$SCR/ci-c05.txt"
caso C05 REPROVA $? - - "ci varredura vazia, historico sem commit"
