# Grupo TA: confianca (TA1 a TA10). Carregado por rodar.sh.

# TA1: subprocess.py sombra da biblioteca padrao, na pasta do portao, sem rastreio
novo_repo ta1 && rm -f "$SCR/marca-a1" && \
    printf 'open("%s", "w").close()\n' "$SCR/marca-a1" > ferramentas/portoes/subprocess.py && \
    printf 'b\n' > b.md && git add b.md && commita -m "feat: b (SG-02)"
[ ! -e "$SCR/marca-a1" ]; rcm=$?
caso TA1 OK "$rcm" "[cifra] encontrados=" "$SCR/saida.txt" "sombra subprocess.py nao executa; marca ausente"

# TA2: o mesmo sombra, commitado sem gate; CI com base da semente e com base zero
novo_repo ta2 && rm -f "$SCR/marca-a2" && \
    printf 'open("%s", "w").close()\n' "$SCR/marca-a2" > ferramentas/portoes/subprocess.py && \
    git add ferramentas/portoes/subprocess.py && printf 'b\n' > b.md && git add b.md && \
    SEM=$(git rev-parse HEAD) && commit_sem_gate "feat: sombra no portao (SG-02)"
ci_simulado ta2 "$SEM" "$SCR/ci-ta2-semente.txt"; r1=$?
ci_simulado ta2 "$ZERO" "$SCR/ci-ta2-zero.txt"; r2=$?
cat "$SCR/ci-ta2-semente.txt" "$SCR/ci-ta2-zero.txt" > "$SCR/ci-ta2.txt"
[ ! -e "$SCR/marca-a2" ]; rcm=$?
rc=0; for x in $r1 $r2 $rcm; do [ "$x" -eq 0 ] || rc=1; done
caso TA2 OK "$rc" "[ci-blobs] encontrados=" "$SCR/ci-ta2.txt" "sombra no commit nao roda no CI, nas duas bases"

# TA3 e TA4: portao do proprio commit trocado por saida limpa, capitulo em claro
novo_repo ta3 && printf 'import sys\nsys.exit(0)\n' > ferramentas/portoes/portoes.py && \
    git add ferramentas/portoes/portoes.py && SEM=$(git rev-parse HEAD) && \
    sha=$(printf 'Abertura do capitulo.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/x.md" && \
    commit_sem_gate "feat: portao trocado e capitulo em claro (SG-02)"
ci_simulado ta3 "$SEM" "$SCR/ci-ta3-semente.txt"; rc3=$?
caso TA3 REPROVA "$rc3" "sem cabecalho cifrado" "$SCR/ci-ta3-semente.txt" "CI com base da semente reprova"
ci_simulado ta3 "$ZERO" "$SCR/ci-ta4.txt"; rc4=$?
caso TA4 REPROVA "$rc4" "saida do portao sem linha de contagem" "$SCR/ci-ta4.txt" "CI com base zero exige linha de contagem"

# TA5: gancho da arvore sobrescrito com exit 0, blob em claro no indice
novo_repo ta5 && printf '#!/bin/sh\nexit 0\n' > ferramentas/portoes/pre-commit && chmod 755 ferramentas/portoes/pre-commit && \
    sha=$(printf 'claro\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,notas/cru.md" && \
    commita -m "feat: gancho da arvore alterado (SG-02)"
caso TA5 REPROVA $? "sem cabecalho cifrado" "$SCR/saida.txt" "gancho da arvore nao decide o commit"

# TA6a e TA6b: gancho instalado diverge do HEAD; depois a reinstalacao devolve o portao
novo_repo ta6 && printf '# comentario\n' >> ferramentas/portoes/pre-commit && \
    git add ferramentas/portoes/pre-commit && commit_sem_gate "feat: comentario no gancho (SG-02)" && \
    printf 'b\n' > b.md && git add b.md && commita -m "feat: b (SG-02)"
caso TA6a REPROVA $? "ganchos instalados divergem do HEAD" "$SCR/saida.txt" "divergencia do gancho instalado"
sh ferramentas/portoes/instalar.sh > "$SCR/instalar-ta6b.txt" 2>&1
printf 'b2\n' > b2.md && git add b2.md && commita -m "feat: b2 (SG-02)"
caso TA6b OK $? - - "reinstalacao devolve o portao ao HEAD"

# TA7: instalacao restaura required e hooksPath
novo_repo ta7 && git config --local --unset filter.git-crypt.required
sh ferramentas/portoes/instalar.sh > "$SCR/saida.txt" 2>&1; rc7=$?
[ "$(git config --get filter.git-crypt.required)" = true ] || rc7=1
git config --get core.hooksPath | grep -q '/portoes-ganchos$' || rc7=1
caso TA7 OK "$rc7" "[instalar]" "$SCR/saida.txt" "instalar restaura required=true e hooksPath"

# TA8a: envio de historico limpo; TA8b: envio com blob cifrado adulterado
novo_repo ta8a && printf 'b\n' > b.md && git add b.md && commita -m "feat: b (SG-02)" && \
    remoto_novo ta8a && empurra ta8a; rc8a=$?
caso TA8a OK "$rc8a" "[envio-chave] encontrados=" "$SCR/saida-envia.txt" "envio do historico limpo"

novo_repo ta8b && remoto_novo ta8b && empurra ta8b >/dev/null 2>&1
blob_falso 60 "$SCR/ta8b.bin" && sha=$(git hash-object -w "$SCR/ta8b.bin") && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/f.md" && \
    commit_sem_gate "feat: blob adulterado sem gate (SG-02)" && empurra ta8b; rc8b=$?
caso TA8b REPROVA "$rc8b" "blob cifrado adulterado ou ilegivel com a chave" "$SCR/saida-envia.txt" "blob cifrado com texto legivel no envio"

# TA9: ramo com blob em claro, merge --no-ff, envio
novo_repo ta9 && printf 'b\n' > b.md && git add b.md && commita -m "feat: base (SG-02)" && \
    remoto_novo ta9 && empurra ta9
git switch -q -c b && sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/m.md" && \
    commit_sem_gate "feat: ramo b sem gate (SG-02)"
git switch -q main && git merge -q --no-ff -m "feat: merge do teste (SG-02)" b > "$SCR/saida.txt" 2>&1
empurra ta9; rc9=$?
caso TA9 REPROVA "$rc9" "sem cabecalho cifrado" "$SCR/saida-envia.txt" "merge traz blob em claro"

# TA10: cherry-pick de commit sem gate, envio
novo_repo ta10 && printf 'b\n' > b.md && git add b.md && commita -m "feat: base (SG-02)" && \
    remoto_novo ta10 && empurra ta10
git switch -q -c c && sha=$(printf 'Canon.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,canon/k.md" && \
    commit_sem_gate "feat: canon sem gate (SG-02)" && CH=$(git rev-parse HEAD)
git switch -q main && git cherry-pick -q "$CH" > "$SCR/saida.txt" 2>&1
empurra ta10; rc10=$?
caso TA10 REPROVA "$rc10" "sem cabecalho cifrado" "$SCR/saida-envia.txt" "cherry-pick traz blob em claro"
