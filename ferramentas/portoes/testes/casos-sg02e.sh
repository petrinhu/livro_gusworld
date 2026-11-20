# Grupos TJ e TV: achados da re-SG-03c (SG-02e). Carregado por rodar.sh depois de casos-sg02d.sh; usa so comum.sh.
# Regra: nenhum travessao literal aqui. Montagem que falha vira FALHOU do caso: rc=0 quando se espera REPROVA,
# rc=1 quando se espera OK. Historico longo nasce num processo so: gera_historico.py | git fast-import.

TJF="$SCR/tj-fonte"
rm -rf "$TJF" && mkdir -p "$TJF" && cp "$FONTE"/*.py "$TJF"/

janela_caso() { # ID ESPERADO FORMA TRECHO DESCRICAO: heuristica do portao da FONTE, direto, sem git
    python3 -I -B "$TST/janela_caso.py" "$TJF" "$3" > "$SCR/tj-$1.txt" 2>&1
    caso "$1" "$2" "$?" "$4" "$SCR/tj-$1.txt" "$5"
}

# TJ1 a TJ7 (MEDIO da re-SG-03c, janela de portao_cifra.py): juncao da ultima janela
janela_caso TJ1 OK a4097 "motivo ''" "janela: corpo aleatorio de 4097 bytes passa sem excecao"
janela_caso TJ2 OK a4159 "motivo ''" "janela: corpo aleatorio de 4159 bytes passa sem excecao"
janela_caso TJ3 OK a4160 "motivo ''" "controle: corpo aleatorio de 4160 bytes"
janela_caso TJ4 REPROVA l1de3 "legivel" "janela: texto na 1a de 3 janelas nao e pulado"
janela_caso TJ5 REPROVA l2de4 "legivel" "janela: texto na 2a de 4 janelas nao e pulado"
for tam in 4097 4160; do
    id=TJ6; [ "$tam" = 4160 ] && id=TJ7
    if novo_repo "tj$tam" && SEM=$(git rev-parse HEAD) && mkdir -p livro-1/texto &&
        head -c "$tam" /dev/zero | tr '\0' 'a' > livro-1/texto/c01.md && git add livro-1/texto/c01.md &&
        commita -m "feat: texto de teste (SG-02)"; then
        ci_simulado "tj$tam" "$SEM" "$SCR/ci-tj$tam.txt"; rc=$?
    else rc=1; fi
    caso "$id" OK "$rc" "suspeitos=0" "$SCR/ci-tj$tam.txt" "janela: texto legitimo de $tam bytes cifrado, CI"
done

orc_hist() { # TIPO ARG [REF]: historico sobre o HEAD do repositorio atual, sem gancho
    seguro "$PWD" || return 1
    python3 -I -B "$TST/gera_historico.py" "$1" "$2" "$(git rev-parse HEAD)" "${3:-refs/heads/main}" |
        git fast-import --quiet --force
}

orc_publicado() { # NOME: repositorio novo com remoto de scratch e a semente ja enviada
    novo_repo "$1" && remoto_novo "$1" && empurra "$1" > /dev/null 2>&1
}

orc_envia() { # NOME: envio do main; devolve o rc do push
    empurra "$1"
}

# TV1 a TV8 (CRITICO-1 e CRITICO-2 da re-SG-03c): as quatro formas medidas, num envio so e no CI
for par in "TV1 claro 40,15000 volume" "TV3 amostra 20,8190 amostra" "TV5 mensagem 40,2000 objetos"; do
    set -- $par; id=$1; n=${id#TV}; nome=tv$n; base=
    orc_publicado "$nome" && base=$(git rev-parse HEAD) && orc_hist "$2" "$3" || base=
    if [ -n "$base" ]; then orc_envia "$nome"; rc=$?; else rc=0; fi
    rotulo="volume em claro"; [ "$4" = amostra ] && rotulo=amostra; [ "$4" = objetos ] && rotulo="objetos de commit e tag"
    caso "$id" REPROVA "$rc" "$rotulo acima do teto do envio" "$SCR/saida-envia.txt" "re-SG-03c: $2 $3, envio"
    if [ -n "$base" ]; then ci_simulado "$nome" "$base" "$SCR/ci-$nome.txt"; rc=$?; else rc=0; fi
    caso "TV$((n + 1))" REPROVA "$rc" "$rotulo acima do orcamento desde a linha de base" "$SCR/ci-$nome.txt" "re-SG-03c: $2 $3, CI"
done
ok7=; orc_publicado tv7 && orc_hist tag 36,1900 && ok7=1
if [ -n "$ok7" ]; then git -C "$SCR/tv7" push -q origin 'refs/tags/*:refs/tags/*' > "$SCR/saida-envia.txt" 2>&1; rc=$?; else rc=0; fi
caso TV7 REPROVA "$rc" "objetos de commit e tag acima do teto do envio" "$SCR/saida-envia.txt" "re-SG-03c: 36 tags de 1900, envio"
if [ -n "$ok7" ]; then ci_simulado tv7 "$ZERO" "$SCR/ci-tv7.txt"; rc=$?; else rc=0; fi
caso TV8 REPROVA "$rc" "objetos de commit e tag acima do orcamento desde a linha de base" "$SCR/ci-tv7.txt" "re-SG-03c: 36 tags de 1900, CI"

# TV9 e TV10: a mesma forma fatiada em dois envios dentro do teto; o orcamento do CI pega na soma
b9=; orc_publicado tv9 && orc_hist claro 20,15000 && orc_envia tv9 > /dev/null 2>&1 && b9=$(git rev-parse HEAD) && orc_hist claro 20,15000 || b9=
if [ -n "$b9" ]; then orc_envia tv9; rc=$?; else rc=1; fi
caso TV9 OK "$rc" - - "fatiado: segundo envio dentro do teto passa"
if [ -n "$b9" ]; then ci_simulado tv9 "$b9" "$SCR/ci-tv9.txt"; rc=$?; else rc=0; fi
caso TV10 REPROVA "$rc" "volume em claro acima do orcamento desde a linha de base" "$SCR/ci-tv9.txt" "fatiado: soma no CI"

# TV11 a TV16: trabalho normal com os tamanhos reais por commit das ondas SG-02b, SG-02c e SG-02d; renovacao
OB=0,47712,13947,17690,22673,52391,22235,33202,28158,11777,0,11277,0,0
OC=23033,21572,5417,27320,0,4352,23400,10038
OD=10268,31633,24110,11619,11782
ok11=; orc_publicado tv11 && orc_hist onda "$OB" && ok11=1
if [ -n "$ok11" ]; then orc_envia tv11; rc=$?; else rc=1; fi
caso TV11 OK "$rc" - - "trabalho normal: a maior onda real num envio so passa"
alvo=; if [ -n "$ok11" ] && orc_hist onda "$OC" && orc_envia tv11 > /dev/null 2>&1 && alvo=$(git rev-parse HEAD) &&
    orc_hist renova "$SCR/tv11/ferramentas/portoes/portao_regras.py" && orc_envia tv11 > /dev/null 2>&1 &&
    b11=$(git rev-parse HEAD) && orc_hist onda "$OD" && orc_envia tv11 > /dev/null 2>&1; then
    ci_simulado tv11 "$b11" "$SCR/ci-tv11.txt"; rc=$?
else rc=1; alvo=sem-alvo; fi
caso TV12 OK "$rc" "base=${alvo:0:7}" "$SCR/ci-tv11.txt" "renovacao no prazo: CI da onda seguinte passa e conta da base nova"
b13=; orc_publicado tv13 && orc_hist onda "$OB" && orc_envia tv13 > /dev/null 2>&1 && orc_hist onda "$OC" &&
    orc_envia tv13 > /dev/null 2>&1 && b13=$(git rev-parse HEAD) && orc_hist onda "$OD" && orc_envia tv13 > /dev/null 2>&1 || b13=
if [ -n "$b13" ]; then ci_simulado tv13 "$b13" "$SCR/ci-tv13.txt"; rc=$?; else rc=0; fi
caso TV13 REPROVA "$rc" "volume em claro acima do orcamento desde a linha de base" "$SCR/ci-tv13.txt" "sem renovar: terceira onda estoura o orcamento"
ok14=; [ -n "$b13" ] && orc_hist claros 1000 refs/heads/feat && ok14=1
if [ -n "$ok14" ]; then empurra_ramo tv13 feat; rc=$?; else rc=1; fi
caso TV14 OK "$rc" "claro=1000/" "$SCR/saida-envia.txt" "ramo novo depois do main publicado: conta so o que nao saiu"
alvo15=; [ -n "$b13" ] && alvo15=$(git -C "$SCR/tv13" rev-parse main) && orc_hist renova "$SCR/tv13/ferramentas/portoes/portao_regras.py" || alvo15=
if [ -n "$alvo15" ]; then orc_envia tv13; rc=$?; else rc=1; fi
caso TV15 OK "$rc" - - "renovacao atrasada: o envio da renovacao passa"
b16=; [ -n "$alvo15" ] && b16=$(git rev-parse HEAD) && orc_hist claros 1000 && orc_envia tv13 > /dev/null 2>&1 || b16=
if [ -n "$b16" ]; then ci_simulado tv13 "$b16" "$SCR/ci-tv16.txt"; rc=$?; else rc=1; alvo15=sem-alvo; fi
caso TV16 OK "$rc" "base=${alvo15:0:7}" "$SCR/ci-tv16.txt" "renovacao atrasada: o CI do envio seguinte passa"

# TV17 a TV20: fronteiras do teto do envio (um passo alem de cada teto)
L24=$(printf '16384,%.0s' $(seq 24)); L24=${L24%,}
for par in "TV17 claros $L24 OK -" "TV18 claros $L24,1 REPROVA volume" "TV19 amostras 8192,8192 OK -" "TV20 amostras 8192,8192,1 REPROVA amostra"; do
    set -- $par; nome=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); ok=
    orc_publicado "$nome" && orc_hist "$2" "$3" && ok=1
    if [ -n "$ok" ]; then orc_envia "$nome"; rc=$?; elif [ "$4" = OK ]; then rc=1; else rc=0; fi
    trecho=-; [ "$5" = volume ] && trecho="volume em claro acima do teto do envio"; [ "$5" = amostra ] && trecho="amostra acima do teto do envio"
    caso "$1" "$4" "$rc" "$trecho" "$SCR/saida-envia.txt" "fronteira do envio: $2 $(printf '%s' "$3" | tr ',' '\n' | awk '{s+=$1} END {print s}') bytes"
done
