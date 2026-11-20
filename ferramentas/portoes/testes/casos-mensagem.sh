# Grupo TC: mensagem e tags (TC1 a TC19). Carregado por rodar.sh.

# TC1 a TC7: sessao em varias formas
novo_repo tc1 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "# Claude-Session: x"
caso TC1 REPROVA $? "linha de sessao" "$SCR/saida.txt" "sessao em linha de comentario"

novo_repo tc2 && printf 'x\n' > a.md && git add a.md && printf '# lixo\nfeat: valido (SG-02)\n' > "$SCR/msg-tc2.txt" && \
    commita -F "$SCR/msg-tc2.txt"
caso TC2 REPROVA $? "mensagem comeca com linha de comentario" "$SCR/saida.txt" "comentario no inicio"

novo_repo tc3 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "https://claude.ai/code/session_abc123XYZ"
caso TC3 REPROVA $? "linha de sessao" "$SCR/saida.txt" "link de sessao sem rotulo"

novo_repo tc4 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "Claude Session: x"
caso TC4 REPROVA $? "linha de sessao" "$SCR/saida.txt" "rotulo com espaco"

novo_repo tc5 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "Claude${ZWSP}-Session: x"
caso TC5 REPROVA $? "linha de sessao" "$SCR/saida.txt" "rotulo com largura zero"

novo_repo tc6 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "CLAUDE-SESSION: x"
caso TC6 REPROVA $? "linha de sessao" "$SCR/saida.txt" "controle: caixa alta"

novo_repo tc7 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (SG-02)" -m "Claude${HIFEN_NB}Session: x"
caso TC7 REPROVA $? "linha de sessao" "$SCR/saida.txt" "hifen nao separador"

# TC8 a TC14: assunto
novo_repo tc8 && printf 'x\n' > a.md && git add a.md && commita -m "feat: id com palavra livre (CAP-NARNIA)"
caso TC8 REPROVA $? "assunto fora de" "$SCR/saida.txt" "ID de palavra livre"

novo_repo tc9 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso com ${TRAV} travessao (SG-02)"
caso TC9 REPROVA $? "travessao na mensagem" "$SCR/saida.txt" "travessao no assunto"

novo_repo tc10 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso com dois itens (CA-01, AR-01)"
caso TC10 OK $? - - "dois IDs separados por virgula e espaco"

novo_repo tc11 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso com sete itens (CA-01, AR-01, TE-01, TE-02, TE-03, SG-01, SG-02)"
caso TC11 REPROVA $? "assunto fora de" "$SCR/saida.txt" "sete IDs"

novo_repo tc12 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso (CA-01,AR-01)"
caso TC12 REPROVA $? "assunto fora de" "$SCR/saida.txt" "IDs sem espaco"

novo_repo tc13 && printf 'x\n' > a.md && git add a.md && \
    A72=$(python3 -c 'print("feat: " + "x" * (72 - len("feat: ") - len(" (SG-02)")) + " (SG-02)")') && \
    commita -m "$A72"
caso TC13 OK $? - - "assunto com 72 caracteres"

novo_repo tc14 && printf 'x\n' > a.md && git add a.md && \
    A73=$(python3 -c 'print("feat: " + "x" * (73 - len("feat: ") - len(" (SG-02)")) + " (SG-02)")') && \
    commita -m "$A73"
caso TC14 REPROVA $? "assunto fora de" "$SCR/saida.txt" "assunto com 73 caracteres"

# TC15: tesoura do git corta a mensagem antes do gancho
novo_repo tc15 && printf 'x\n' > a.md && git add a.md && \
    printf 'feat: caso com tesoura (SG-02)\n\n# ------------------------ >8 ------------------------\nTexto abaixo da tesoura. %s Claude-Session: x\n' "$TRAV" > "$SCR/msg-tc15.txt" && \
    commita --cleanup=scissors -F "$SCR/msg-tc15.txt"
caso TC15 OK $? - - "conteudo abaixo da tesoura nao conta"

# TC16a e TC16b: assunto ruim e travessao em blob de ferramentas, CI com base da semente
novo_repo tc16 && printf 'x\n' > a.md && git add a.md && commita -m "feat: base (SG-02)" && \
    mkdir -p ferramentas/montagem && sha=$(printf 'x = 1 %s y\n' "$TRAV" | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,ferramentas/montagem/x.py" && \
    SEM=$(git rev-parse HEAD~0) && commit_sem_gate "update stuff"
ci_simulado tc16 "$SEM" "$SCR/ci-tc16.txt"; rc16=$?
caso TC16a REPROVA "$rc16" "assunto fora de" "$SCR/ci-tc16.txt" "assunto livre no CI"
caso TC16b REPROVA "$rc16" "travessao fora de inicio de fala" "$SCR/ci-tc16.txt" "travessao em ferramentas no CI"

# TC17a e TC17b: tag com tagger externo e sessao na mensagem
novo_repo tc17 && printf 'x\n' > a.md && git add a.md && commita -m "feat: base (SG-02)" && \
    ( cd "$SCR/tc17" && GIT_COMMITTER_NAME=Externo GIT_COMMITTER_EMAIL=externo@exemplo.invalid \
        git tag -a v0-tc17 -m "Claude-Session: x" )
ci_simulado tc17 "$ZERO" "$SCR/ci-tc17.txt"; rc17=$?
caso TC17a REPROVA "$rc17" "tagger fora do noreply" "$SCR/ci-tc17.txt" "tagger externo na tag"
caso TC17b REPROVA "$rc17" "cita sessao" "$SCR/ci-tc17.txt" "sessao na mensagem da tag"

# TC18: revert sem formato, no envio
novo_repo tc18 && printf 'x\n' > a.md && git add a.md && commita -m "feat: caso reverter (SG-02)" && \
    remoto_novo tc18 && empurra tc18 >/dev/null 2>&1 && \
    env HOME="$HOME" git -C "$SCR/tc18" revert --no-edit HEAD > "$SCR/saida.txt" 2>&1 && empurra tc18; rc18=$?
caso TC18 REPROVA "$rc18" "assunto fora de" "$SCR/saida-envia.txt" "revert com assunto fora do formato"

# TC19: merge com mensagem sem formato
novo_repo tc19 && printf 'x\n' > a.md && git add a.md && commita -m "feat: base (SG-02)" && \
    git switch -q -c b && printf 'y\n' > y.md && git add y.md && commita -m "feat: ramo b (SG-02)" && \
    git switch -q main && printf 'z\n' > z.md && git add z.md && commita -m "feat: ramo main (SG-02)" && \
    git merge --no-ff -m "merge sem formato" b > "$SCR/saida.txt" 2>&1
caso TC19 REPROVA $? "assunto fora de" "$SCR/saida.txt" "merge com mensagem sem formato"
