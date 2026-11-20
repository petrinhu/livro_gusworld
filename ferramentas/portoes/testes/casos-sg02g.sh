# Grupo TY: achados da re-SG-03e (SG-02g). Carregado por rodar.sh depois de casos-sg02f.sh; usa comum.sh,
# orc_publicado e orc_hist de casos-sg02e.sh e afrouxa e TETO_MSG de casos-sg02f.sh.
# Regra: nenhum travessao literal aqui. Montagem que falha vira FALHOU do caso: rc=0 quando se espera REPROVA,
# rc=1 quando se espera OK.
APAGA="envio apaga refs/heads/main"
VAZIO="remoto vazio: o primeiro envio pede"

apaga_main() { # NOME FORMA: envio que apaga o main publicado, pela FORMA; a saida vai para saida-envia.txt
    seguro "$SCR/$1" || return 1
    case "$2" in
        dois-pontos) git -C "$SCR/$1" push -q origin :main ;;
        delete) git -C "$SCR/$1" push -q --delete origin main ;;
        prune) git -C "$SCR/$1" branch -q -m main outro && git -C "$SCR/$1" push -q --prune origin 'refs/heads/*:refs/heads/*' ;;
    esac > "$SCR/saida-envia.txt" 2>&1
}

# TY1 a TY3 (F1a): main publicado e portao afrouxado so local; o envio que apaga o main fecha (formas que o git mostra ao gancho)
for par in "TY1 dois-pontos" "TY2 delete" "TY3 prune"; do
    set -- $par; n=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); ok=
    orc_publicado "$n" && cd "$SCR/$n" && afrouxa && ok=1
    if [ -n "$ok" ]; then apaga_main "$n" "$2"; rc=$?; else rc=0; fi
    caso "$1" REPROVA "$rc" "$APAGA" "$SCR/saida-envia.txt" "envio que apaga o main fecha ($2)"
done

# TY4 (F1a e F1b, passo alem): no --mirror o git nao entrega ao gancho a linha de apagar (medido, git 2.56.1).
# Um mirror com HEAD solto e so refs/x/y apaga o main e deixa o remoto so com refs/x/y; o envio seguinte fecha
ok=; orc_publicado ty4 && cd "$SCR/ty4" && s0=$(git rev-parse main) && afrouxa && orc_hist claro 35,15000 &&
    h=$(git rev-parse main) && git switch -q --detach "$s0" && git for-each-ref --format='delete %(refname)' | git update-ref --stdin &&
    git update-ref refs/x/y "$s0" && git push -q --mirror origin > /dev/null 2>&1 &&
    test "$(git ls-remote --refs origin | cut -f2)" = refs/x/y && git update-ref refs/heads/main "$h" && git switch -q main && ok=1
if [ -n "$ok" ]; then empurra ty4; rc=$?; else rc=0; fi
caso TY4 REPROVA "$rc" "main publicado ausente aqui" "$SCR/saida-envia.txt" "mirror apaga o main sem o gancho ver; o envio seguinte fecha"

# TY5 (F1b): remoto so com ref fora de ramos e tags nao e remoto vazio; sem main, o envio fecha
ok=; novo_repo ty5 && remoto_novo ty5 && git -C "$SCR/ty5-remoto.git" fetch -q "$SCR/ty5" main:refs/x/y &&
    cd "$SCR/ty5" && afrouxa && orc_hist claro 35,15000 && ok=1
if [ -n "$ok" ]; then empurra ty5; rc=$?; else rc=0; fi
caso TY5 REPROVA "$rc" "main publicado ausente aqui" "$SCR/saida-envia.txt" "remoto so com refs/x/y: o envio fecha"

# TY6 e TY7 (F1a, passo alem): remoto esvaziado por fora; sem autorizacao, ou com ela errada, o envio fecha
for par in "TY6 nenhuma" "TY7 errada"; do
    set -- $par; n=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); ok=
    orc_publicado "$n" && git -C "$SCR/$n-remoto.git" update-ref -d refs/heads/main && cd "$SCR/$n" && afrouxa &&
        orc_hist claro 35,15000 && ok=1
    if [ -z "$ok" ]; then rc=0
    elif [ "$2" = nenhuma ]; then env -u PORTOES_PRIMEIRO_ENVIO git -C "$SCR/$n" push -q origin main > "$SCR/saida-envia.txt" 2>&1; rc=$?
    else PORTOES_PRIMEIRO_ENVIO=$(git -C "$SCR/$n" rev-parse main~1) git -C "$SCR/$n" push -q origin main > "$SCR/saida-envia.txt" 2>&1; rc=$?; fi
    caso "$1" REPROVA "$rc" "$VAZIO" "$SCR/saida-envia.txt" "remoto esvaziado por fora, autorizacao $2: o envio fecha"
done

# TY8 (controle): primeiro envio com a autorizacao igual ao commit enviado ao main passa
ok=; novo_repo ty8 && remoto_novo ty8 && ok=1
if [ -n "$ok" ]; then PORTOES_PRIMEIRO_ENVIO=$(git -C "$SCR/ty8" rev-parse main) git -C "$SCR/ty8" push -q origin main > "$SCR/saida-envia.txt" 2>&1; rc=$?; else rc=1; fi
caso TY8 OK "$rc" - "$SCR/saida-envia.txt" "primeiro envio autorizado pelo commit do main passa"

# TY9 (F3): remoto a com url igual ao nome do remoto b; o conteudo ja esta no remoto do nome b, e o caminho b esta vazio
ok=; orc_publicado ty9 && cd "$SCR/ty9" && orc_hist claro 20,15000 && empurra ty9 && git init -q --bare "$SCR/ty9/b" &&
    git remote add b "$SCR/ty9-remoto.git" && git remote add a b && ok=1
if [ -n "$ok" ]; then git -C "$SCR/ty9" push -q a main:refs/heads/novo > "$SCR/saida-envia.txt" 2>&1; rc=$?; else rc=0; fi
caso TY9 REPROVA "$rc" "nome de remoto" "$SCR/saida-envia.txt" "endereco do envio igual a nome de remoto: o envio fecha"

# TY10 (F3, passo alem): pushInsteadOf leva ao destino vazio e insteadOf leva o ls-remote ao remoto cheio
ok=; orc_publicado ty10 && cd "$SCR/ty10" && orc_hist claro 20,15000 && empurra ty10 && git init -q --bare "$SCR/ty10-c.git" &&
    git config "url.$SCR/ty10-c.git.pushInsteadOf" "$SCR/ty10-b.git" &&
    git config "url.$SCR/ty10-remoto.git.insteadOf" "$SCR/ty10-c.git" && ok=1
if [ -n "$ok" ]; then git -C "$SCR/ty10" push -q "$SCR/ty10-b.git" main:refs/heads/novo > "$SCR/saida-envia.txt" 2>&1; rc=$?; else rc=0; fi
caso TY10 REPROVA "$rc" "reescrita de endereco" "$SCR/saida-envia.txt" "reescrita de endereco na config: o envio fecha"

# TY11 (F3, no portao julgado): o sha remoto que o git entrega diverge da lista do remoto: fecha
ok=; novo_repo ty11 && h=$(git rev-parse main) && printf '%s\trefs/heads/main\n' "$h" > "$SCR/ty11-lista.txt" &&
    printf 'refs/heads/main %s refs/heads/main %s\n' "$h" "$ZERO" > "$SCR/ty11-ent.txt" && ok=1
if [ -n "$ok" ]; then ( cd "$SCR/ty11" && PORTOES_PUBLICADOS="$SCR/ty11-lista.txt" python3 -I ferramentas/portoes/portoes.py envio < "$SCR/ty11-ent.txt" ) > "$SCR/saida-ty11.txt" 2>&1; rc=$?; else rc=0; fi
caso TY11 REPROVA "$rc" "diverge da lista do remoto" "$SCR/saida-ty11.txt" "entrada do git diverge da lista do remoto: fecha"

# TY12 e TY13 (F2): ramo com nome fora do ASCII no remoto nao trava os envios seguintes; TY13 com nome que nem e UTF-8
for par in "TY12 $(printf 'ramo-\303\251')" "TY13 $(printf 'ramo-\351')"; do
    set -- $par; n=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); ok=
    orc_publicado "$n" && git -C "$SCR/$n-remoto.git" update-ref "refs/heads/$2" main && cd "$SCR/$n" && orc_hist claros 1000 && ok=1
    if [ -n "$ok" ]; then empurra "$n"; rc=$?; else rc=1; fi
    caso "$1" OK "$rc" - "$SCR/saida-envia.txt" "ramo com nome fora do ASCII no remoto nao trava o envio"
done
