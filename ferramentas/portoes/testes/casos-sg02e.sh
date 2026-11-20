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
