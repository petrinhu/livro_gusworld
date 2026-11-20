# Grupo TW: o que o remoto ja tem vem do remoto, nunca de refs/remotes locais (SG-02f, A1 da re-SG-03d).
# Carregado por rodar.sh depois de casos-sg02e.sh; usa comum.sh e as funcoes orc_hist e orc_publicado de casos-sg02e.sh.
# Regra: nenhum travessao literal aqui. Montagem que falha vira FALHOU do caso: rc=0 quando se espera REPROVA.
TETO_MSG="volume em claro acima do teto do envio"

afrouxa() { # no repositorio atual: commit com gancho que sobe o TETO_ENVIO para 999999999 (portao so local)
    seguro "$PWD" || return 1
    sed -i 's/^TETO_ENVIO = .*/TETO_ENVIO = {"claro": 999999999, "amostra": 999999999, "objetos": 999999999}/' \
        ferramentas/portoes/portao_regras.py && git add ferramentas/portoes/portao_regras.py &&
        commita -m "fix: afrouxa o teto do envio (SG-02)"
}

# TW1 e TW2: ref local forjada em refs/remotes zera a conta (A1 medido); TW2 sob outro nome de remoto
for par in "TW1 refs/remotes/origin/forja" "TW2 refs/remotes/espelho/x"; do
    set -- $par; n=$(printf '%s' "$1" | tr 'A-Z' 'a-z'); ok=
    orc_publicado "$n" && cd "$SCR/$n" && orc_hist claro 35,15000 && git update-ref "$2" HEAD && ok=1
    if [ -n "$ok" ]; then empurra "$n"; rc=$?; else rc=0; fi
    caso "$1" REPROVA "$rc" "$TETO_MSG" "$SCR/saida-envia.txt" "ref local forjada em $2 nao zera a conta do envio"
done

# TW3: caminho sem forja e sem pular gancho: o conteudo chega por fetch de outro clone (remote add, fetch, merge)
ok=; orc_publicado tw3 && git clone -q "$SCR/tw3" "$SCR/tw3-outro" && ( cd "$SCR/tw3-outro" && orc_hist claro 35,15000 ) &&
    git -C "$SCR/tw3" remote add outro "$SCR/tw3-outro" && git -C "$SCR/tw3" fetch -q outro &&
    git -C "$SCR/tw3" merge -q --ff-only outro/main > /dev/null 2>&1 && ok=1
if [ -n "$ok" ]; then empurra tw3; rc=$?; else rc=0; fi
caso TW3 REPROVA "$rc" "$TETO_MSG" "$SCR/saida-envia.txt" "outro remoto buscado com o conteudo nao zera a conta do envio"

# TW4 e TW5: gemeo. Portao afrouxado so local vira juiz por refs/remotes/origin/main forjado; TW5 em ramo novo
ok=; orc_publicado tw4 && cd "$SCR/tw4" && afrouxa && git update-ref refs/remotes/origin/main HEAD && orc_hist claro 35,15000 && ok=1
if [ -n "$ok" ]; then empurra tw4; rc=$?; else rc=0; fi
caso TW4 REPROVA "$rc" "$TETO_MSG" "$SCR/saida-envia.txt" "juiz do envio e o main do remoto, nao a ref local forjada"
ok=; orc_publicado tw5 && cd "$SCR/tw5" && git switch -q -c feat && afrouxa && git update-ref refs/remotes/origin/main HEAD &&
    orc_hist claro 35,15000 refs/heads/feat && ok=1
if [ -n "$ok" ]; then empurra_ramo tw5 feat; rc=$?; else rc=0; fi
caso TW5 REPROVA "$rc" "$TETO_MSG" "$SCR/saida-envia.txt" "ramo novo: juiz do envio e o main do remoto, nao a ref local forjada"

# TW6: remoto a frente (main publicado que nao existe aqui): o envio fecha em vez de escolher outro juiz
ok=; orc_publicado tw6 && git clone -q -b main "$SCR/tw6-remoto.git" "$SCR/tw6-b" &&
    git -C "$SCR/tw6-b" -c user.email="$NOREPLY" -c user.name=Teste commit -q --allow-empty -m "chore: avanca o remoto (SG-02)" &&
    git -C "$SCR/tw6-b" push -q origin main && cd "$SCR/tw6" && git switch -q -c feat && orc_hist claros 1000 refs/heads/feat && ok=1
if [ -n "$ok" ]; then empurra_ramo tw6 feat; rc=$?; else rc=0; fi
caso TW6 REPROVA "$rc" "main publicado ausente aqui" "$SCR/saida-envia.txt" "remoto a frente: o envio fecha"

# TW7: endereco ilegivel no pre-push instalado: o envio fecha
ok=; novo_repo tw7 && ok=1
if [ -n "$ok" ]; then ( cd "$SCR/tw7" && sh .git/portoes-ganchos/pre-push origin "$SCR/tw7-nao-existe.git" < /dev/null ) > "$SCR/saida-tw7.txt" 2>&1; rc=$?; else rc=0; fi
caso TW7 REPROVA "$rc" "remoto ilegivel" "$SCR/saida-tw7.txt" "pre-push com endereco ilegivel fecha"

# TW8: portao de envio chamado sem a lista do remoto: fecha
ok=; novo_repo tw8 && ok=1
if [ -n "$ok" ]; then ( cd "$SCR/tw8" && env -u PORTOES_PUBLICADOS python3 -I ferramentas/portoes/portoes.py envio < /dev/null ) > "$SCR/saida-tw8.txt" 2>&1; rc=$?; else rc=0; fi
caso TW8 REPROVA "$rc" "lista do remoto ausente" "$SCR/saida-tw8.txt" "portao de envio sem a lista do remoto fecha"

# TW9: endereco que comeca com -- nao vira opcao do git ls-remote (sem --, --upload-pack executaria um comando): o envio fecha e nada roda
ok=; novo_repo tw9 && git init -q --bare "$SCR/tw9-semente.git" && git -C "$SCR/tw9" remote add origin "$SCR/tw9-semente.git" && ok=1
if [ -n "$ok" ]; then ( cd "$SCR/tw9" && sh .git/portoes-ganchos/pre-push origin "--upload-pack=touch $SCR/tw9-marca" < /dev/null ) > "$SCR/saida-tw9.txt" 2>&1; rc=$?; [ ! -e "$SCR/tw9-marca" ] || rc=0; else rc=0; fi
caso TW9 REPROVA "$rc" "remoto ilegivel" "$SCR/saida-tw9.txt" "endereco com -- nao vira opcao e nao executa comando"
