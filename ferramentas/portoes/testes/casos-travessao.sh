# Grupo TD: travessao no fonte (TD1 a TD10). Carregado por rodar.sh.
# Entidades HTML montadas com AMP (printf), nunca escritas literais aqui.

td_capitulo() { # NOME ARQUIVO-DE-CONTEUDO: repositorio com o capitulo commitado sem erro esperado
    novo_repo "$1" && mkdir -p livro-1/texto && cp "$2" livro-1/texto/c01.md && \
        git add livro-1/texto/c01.md && commita -m "feat: capitulo de teste (SG-02)"
}

printf 'Ele disse %smdash; oi.\n' "$AMP" > "$SCR/td1a.md"
td_capitulo td1a "$SCR/td1a.md"
caso TD1a REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade nomeada de travessao"

printf 'Ele %s#X2013; oi.\n' "$AMP" > "$SCR/td1b.md"
td_capitulo td1b "$SCR/td1b.md"
caso TD1b REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade hexadecimal de meio-travessao"

printf 'Ele %s#08212; oi.\n' "$AMP" > "$SCR/td1c.md"
td_capitulo td1c "$SCR/td1c.md"
caso TD1c REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade decimal com zeros"

printf 'Ele %sndash; oi.\n' "$AMP" > "$SCR/td1d.md"
td_capitulo td1d "$SCR/td1d.md"
caso TD1d REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade nomeada de meio-travessao"

printf 'Ele %sMDash; oi.\n' "$AMP" > "$SCR/td2.md"
td_capitulo td2 "$SCR/td2.md"
caso TD2 OK $? - - "controle: entidade que o pandoc nao decodifica"

printf 'Ele respondeu que sim, e\n#hashtag\n%s Oi.\n' "$TRAV" > "$SCR/td3.md"
td_capitulo td3 "$SCR/td3.md"
caso TD3 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "hashtag sem espaco nao e titulo"

printf 'Abertura.\n\n# Titulo\n%s Fala.\n' "$TRAV" > "$SCR/td4.md"
td_capitulo td4 "$SCR/td4.md"
caso TD4 OK $? - - "controle: titulo com espaco antes de fala"

printf 'Faixa 1--2 do texto.\n' > "$SCR/td5.md"
td_capitulo td5 "$SCR/td5.md"
caso TD5 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "hifens duplos viram travessao"

printf 'E assim --- ou nao.\n' > "$SCR/td6.md"
td_capitulo td6 "$SCR/td6.md"
caso TD6 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "hifens triplos no meio da frase"

printf 'Abertura.\n\n--- Oi, disse ele.\n' > "$SCR/td7.md"
td_capitulo td7 "$SCR/td7.md"
caso TD7 OK $? - - "controle: hifens triplos abrindo fala"

printf 'Abertura.\n\n---\n\n| a | b |\n|---|:--|\n| 1 | 2 |\n' > "$SCR/td8.md"
td_capitulo td8 "$SCR/td8.md"
caso TD8 OK $? - - "controle: regua e tabela"

novo_repo td9 && mkdir -p ferramentas/montagem && printf '#!/bin/sh\npandoc --from markdown\n' > ferramentas/montagem/x.sh && \
    git add ferramentas/montagem/x.sh && commita -m "feat: script de montagem (SG-02)"
caso TD9 OK $? - - "escopo: script com a palavra markdown"

novo_repo td10 && mkdir -p ferramentas/montagem/amostra/texto && \
    sha=$(printf 'a %smdash; b\n' "$AMP" | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,ferramentas/montagem/amostra/texto/c09.md" && \
    commit_sem_gate "feat: entidade em amostra sem gate (SG-02)"
ci_simulado td10 "$ZERO" "$SCR/ci-td10.txt"
caso TD10 REPROVA $? "travessao fora de inicio de fala" "$SCR/ci-td10.txt" "entidade em amostra, CI"
