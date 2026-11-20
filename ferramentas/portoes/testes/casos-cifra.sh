# Grupo TB: cifra, binario, refs, confianca, modo (TB1 a TB27). Carregado por rodar.sh.

# TB1: .gitattributes da raiz ganha excecao no proprio commit
novo_repo tb1 && printf 'rascunho2/** !filter !diff\n' >> .gitattributes && mkdir -p rascunho2 && \
    printf 'Texto do rascunho.\n' > rascunho2/a.md && git add .gitattributes rascunho2/a.md && \
    commita -m "feat: rascunho sem cifra (SG-02)"
caso TB1 REPROVA $? "sem cabecalho cifrado" "$SCR/saida.txt" "excecao criada pelo proprio commit"

# TB2: o mesmo, sem gate, CI com base da semente
novo_repo tb2 && printf 'rascunho2/** !filter !diff\n' >> .gitattributes && mkdir -p rascunho2 && \
    git add .gitattributes && SEM=$(git rev-parse HEAD) && \
    sha=$(printf 'Texto do rascunho.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,rascunho2/a.md" && commit_sem_gate "feat: rascunho sem gate (SG-02)"
ci_simulado tb2 "$SEM" "$SCR/ci-tb2.txt"
caso TB2 REPROVA $? "sem cabecalho cifrado" "$SCR/ci-tb2.txt" "excecao criada no commit sem gate"

# TB3: .gitattributes aninhado
novo_repo tb3 && mkdir -p novo && printf '* !filter !diff\n' > novo/.gitattributes && \
    printf 'Texto.\n' > novo/a.md && git add novo/.gitattributes novo/a.md && commita -m "feat: atributo aninhado (SG-02)"
caso TB3 REPROVA $? "gitattributes aninhado proibido" "$SCR/saida.txt" "atributo aninhado"

# TB4: excecao em .git/info/attributes
novo_repo tb4 && mkdir -p .git/info pasta3 && printf 'pasta3/** !filter !diff\n' >> .git/info/attributes && \
    printf 'Texto.\n' > pasta3/a.md && git add pasta3/a.md && commita -m "feat: excecao local (SG-02)"
caso TB4 REPROVA $? "sem cabecalho cifrado" "$SCR/saida.txt" "excecao em info/attributes"

# TB5: mesmo blob em ferramentas/ e livro-1/texto/, sem gate
novo_repo tb5 && mkdir -p ferramentas/montagem livro-1/texto && \
    sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,ferramentas/montagem/cap.py" && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/cap.md" && \
    SEM=$(git rev-parse HEAD) && commit_sem_gate "feat: mesmo blob em dois caminhos (SG-02)"
ci_simulado tb5 "$SEM" "$SCR/ci-tb5.txt"
caso TB5 REPROVA $? "sem cabecalho cifrado: livro-1/texto/cap.md" "$SCR/ci-tb5.txt" "blob repetido, caminho cifrado nao pode ser ocultado"

# TB6: mesmo blob em canon/ e ferramentas/
novo_repo tb6 && mkdir -p canon ferramentas/montagem && \
    sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,canon/cap.md" && \
    git update-index --add --cacheinfo "100644,$sha,ferramentas/montagem/cap.py" && \
    commit_sem_gate "feat: mesmo blob em canon e ferramentas (SG-02)"
ci_simulado tb6 "$ZERO" "$SCR/ci-tb6.txt"
caso TB6 REPROVA $? "sem cabecalho cifrado: canon/cap.md" "$SCR/ci-tb6.txt" "blob repetido, ordem da arvore"

# TB7: caminho com quebra de linha, sem gate
novo_repo tb7 && sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && \
    CAM=$(printf 'ferramentas/montagem/a\nb.py') && \
    printf '100644 %s\t%s\0' "$sha" "$CAM" | git update-index -z --index-info && \
    commit_sem_gate "feat: caminho com quebra (SG-02)"
ci_simulado tb7 "$ZERO" "$SCR/ci-tb7.txt"
caso TB7 REPROVA $? "caminho com quebra de linha" "$SCR/ci-tb7.txt" "caminho com quebra de linha no CI"

# TB8 e TB9: prosa em caminho de excecao (commit normal e sem gate)
novo_repo tb8 && mkdir -p ferramentas && printf 'Abertura do capitulo.\n' > ferramentas/cap1.md && \
    git add ferramentas/cap1.md && commita -m "feat: prosa em ferramentas (SG-02)"
caso TB8 REPROVA $? "forma nao aprovada em caminho de excecao" "$SCR/saida.txt" "prosa em ferramentas"

novo_repo tb9 && mkdir -p ferramentas && sha=$(printf 'Abertura do capitulo.\n' | git hash-object -w --stdin) && \
    git update-index --add --cacheinfo "100644,$sha,ferramentas/cap1.md" && \
    commit_sem_gate "feat: prosa em ferramentas sem gate (SG-02)"
ci_simulado tb9 "$ZERO" "$SCR/ci-tb9.txt"
caso TB9 REPROVA $? "forma nao aprovada em caminho de excecao" "$SCR/ci-tb9.txt" "prosa em ferramentas no CI"

# TB10: cabecalho cifrado com corpo legivel, sem gate
novo_repo tb10 && mkdir -p livro-1/texto && blob_falso 60 "$SCR/tb10.bin" && \
    sha=$(git hash-object -w "$SCR/tb10.bin") && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/f.md" && commit_sem_gate "feat: corpo legivel sem gate (SG-02)"
ci_simulado tb10 "$ZERO" "$SCR/ci-tb10.txt"
caso TB10 REPROVA $? "corpo legivel apos o cabecalho cifrado" "$SCR/ci-tb10.txt" "cabecalho falso com texto legivel"

# TB11: controle, texto curto cifrado pelo fluxo normal
novo_repo tb11 && mkdir -p livro-1/texto && head -c 100 /dev/zero | tr '\0' 'b' > livro-1/texto/g.md && \
    git add livro-1/texto/g.md && commita -m "feat: texto curto (SG-02)"
ci_simulado tb11 "$ZERO" "$SCR/ci-tb11.txt"
caso TB11 OK $? "[ci-heuristica]" "$SCR/ci-tb11.txt" "controle: cifra real nao e suspeita"

# TB12a e TB12b: corpo pequeno (resíduo) e envio com chave
novo_repo tb12 && remoto_novo tb12 && empurra tb12 >/dev/null 2>&1
blob_falso 10 "$SCR/tb12.bin" && sha=$(git hash-object -w "$SCR/tb12.bin") && \
    git update-index --add --cacheinfo "100644,$sha,livro-1/texto/f.md" && commit_sem_gate "feat: corpo pequeno sem gate (SG-02)"
ci_simulado tb12 "$ZERO" "$SCR/ci-tb12.txt"; rc12a=$?
caso TB12a OK "$rc12a" "pequenos=1" "$SCR/ci-tb12.txt" "residuo declarado: corpo pequeno passa sem chave"
empurra tb12; rc12b=$?
caso TB12b REPROVA "$rc12b" "blob cifrado adulterado ou ilegivel com a chave" "$SCR/saida-envia.txt" "envio com chave pega o mesmo blob"

# TB13: arquivo cifrado movido para caminho de excecao
novo_repo tb13 && mkdir -p livro-1/texto && printf 'Abertura.\n' > livro-1/texto/a.md && \
    git add livro-1/texto/a.md && commita -m "feat: capitulo cifrado (SG-02)" && \
    mkdir -p ferramentas/montagem && git mv livro-1/texto/a.md ferramentas/montagem/a.py && \
    commita -m "feat: move para ferramentas (SG-02)"
caso TB13 REPROVA $? "cifrado em caminho de excecao" "$SCR/saida.txt" "git mv de cifrado para excecao"

# TB14: arquivo de trabalho ja com cabecalho cifrado
novo_repo tb14 && mkdir -p livro-1/texto && { printf '\000GITCRYPT\000'; printf 'Texto do capitulo.\n'; } > livro-1/texto/h.md && \
    git add livro-1/texto/h.md; commita -m "feat: arquivo ja cifrado (SG-02)"
caso TB14 REPROVA $? "conteudo decifrado ainda comeca com o cabecalho" "$SCR/saida.txt" "cabecalho no arquivo de trabalho"

# TB15: imagem binaria em caminho cifrado
novo_repo tb15 && mkdir -p grafico && head -c 2097152 /dev/urandom > grafico/img.png && \
    git add grafico/img.png && commita -m "feat: imagem binaria (SG-02)"
caso TB15 OK $? "[travessao] encontrados=" "$SCR/saida.txt" "binario legitimo em caminho cifrado"

# TB16: byte invalido em texto
novo_repo tb16 && mkdir -p livro-1/texto && printf 'Texto.\377\n' > livro-1/texto/r.md && \
    git add livro-1/texto/r.md && commita -m "feat: byte invalido (SG-02)"
caso TB16 REPROVA $? "nao e UTF-8" "$SCR/saida.txt" "texto com byte invalido"

# TB17a e TB17b: teto de 50 MiB, mais 1 byte e exato
novo_repo tb17a && mkdir -p grafico && head -c 52428801 /dev/urandom > grafico/g.png && \
    git add grafico/g.png && commita -m "feat: imagem acima do teto (SG-02)"
caso TB17a REPROVA $? "binario acima do teto" "$SCR/saida.txt" "um byte acima do teto"

novo_repo tb17b && mkdir -p grafico && head -c 52428800 /dev/urandom > grafico/g.png && \
    git add grafico/g.png && commita -m "feat: imagem no teto (SG-02)"
caso TB17b OK $? "[travessao] encontrados=" "$SCR/saida.txt" "exatamente no teto"

# TB18: binario em caminho de excecao
novo_repo tb18 && mkdir -p ferramentas/montagem && head -c 2097152 /dev/urandom > ferramentas/montagem/img.bin && \
    git add ferramentas/montagem/img.bin && commita -m "feat: binario em ferramentas (SG-02)"
caso TB18 REPROVA $? "forma nao aprovada em caminho de excecao" "$SCR/saida.txt" "binario em excecao"

# TB19 e TB20: modo de arquivo (submodulo e link simbolico); legado sem exigencia
novo_repo tb19 && SEMENTE=$(git rev-parse HEAD) && \
    git update-index --add --cacheinfo "160000,$SEMENTE,sub" && commita -m "feat: submodulo (SG-02)"
caso TB19 REPROVA $? "modo de arquivo proibido" "$SCR/saida.txt" "submodulo"

novo_repo tb20 && mkdir -p livro-1/texto && ln -s alvo livro-1/texto/l.md && \
    git add livro-1/texto/l.md && commita -m "feat: link simbolico (SG-02)"
caso TB20 REPROVA $? "modo de arquivo proibido" "$SCR/saida.txt" "link simbolico"

# TB21: tag apontando para blob
novo_repo tb21 && sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && git tag t-blob "$sha" && \
    ci_aqui tb21 "$ZERO" "$SCR/ci-tb21.txt"; rc21=$?
caso TB21 REPROVA "$rc21" "aponta para objeto que nao e commit" "$SCR/ci-tb21.txt" "tag que aponta para blob"

# TB22: refs/replace no envio
# A e B ficam em ramos fora da linha enviada (main): replace na linha enviada quebra o fast-forward
novo_repo tb22 && remoto_novo tb22 && empurra tb22 >/dev/null 2>&1 && \
    git switch -q -c x && printf 'a\n' > a.md && git add a.md && commita -m "feat: a (SG-02)" && A=$(git rev-parse HEAD) && \
    git switch -q main && git switch -q -c y && printf 'b\n' > b.md && git add b.md && commita -m "feat: b (SG-02)" && B=$(git rev-parse HEAD) && \
    git switch -q main && printf 'm\n' > m.md && git add m.md && commita -m "feat: m (SG-02)" && \
    git replace "$A" "$B" && empurra tb22; rc22=$?
caso TB22 REPROVA "$rc22" "refs/replace presente" "$SCR/saida-envia.txt" "replace no envio"

# TB23 e TB24: arquivo de confianca alterado (commit normal e sem gate)
novo_repo tb23 && printf '# comentario\n' >> .github/workflows/sigilo.yml && \
    git add .github/workflows/sigilo.yml && printf 'b\n' > b.md && git add b.md && commita -m "feat: workflow alterado (SG-02)"
caso TB23 REPROVA $? "arquivo de confianca nao aprovado" "$SCR/saida.txt" "workflow alterado"

novo_repo tb24 && printf '# comentario\n' >> .github/workflows/sigilo.yml && \
    git add .github/workflows/sigilo.yml && commit_sem_gate "feat: workflow alterado sem gate (SG-02)"
ci_simulado tb24 "$ZERO" "$SCR/ci-tb24.txt"
caso TB24 REPROVA $? "arquivo de confianca nao aprovado" "$SCR/ci-tb24.txt" "workflow alterado no CI"

# TB25: nome com quebra de linha em livro-1/texto/
novo_repo tb25 && mkdir -p livro-1/texto && sha=$(printf 'Abertura.\n' | git hash-object -w --stdin) && \
    CAM=$(printf 'livro-1/texto/capitulo\num.md') && \
    printf '100644 %s\t%s\0' "$sha" "$CAM" | git update-index -z --index-info && \
    commita -m "feat: caminho com quebra (SG-02)"
caso TB25 REPROVA $? "caminho com quebra de linha" "$SCR/saida.txt" "caminho com quebra no commit"

# TB26a e TB26b: forca e acento (controles)
novo_repo tb26a && mkdir -p .insumos && printf 'Nota.\n' > .insumos/x.md && git add -f .insumos/x.md && \
    commita -m "feat: inventario forcado (SG-02)"
caso TB26a OK $? "[cifra] encontrados=" "$SCR/saida.txt" "controle: arquivo forcado em caminho ignorado"

novo_repo tb26b && mkdir -p "livro-1/texto" && printf 'Abertura.\n' > "livro-1/texto/capítulo um.md" && \
    git add "livro-1/texto/capítulo um.md" && commita -m "feat: nome com acento (SG-02)"
caso TB26b OK $? "[cifra] encontrados=" "$SCR/saida.txt" "controle: nome com acento"

# TB27: numero de chamadas git nao cresce com o numero de arquivos
mkdir -p "$SCR/shim" && REAL=$(command -v git) && \
    printf '#!/bin/sh\necho x >> "%s/chamadas"\nexec "%s" "$@"\n' "$SCR/shim" "$REAL" > "$SCR/shim/git" && chmod 755 "$SCR/shim/git"
novo_repo tb27a && mkdir -p livro-1/texto && for i in 1 2 3 4 5; do printf 'Abertura %s.\n' "$i" > livro-1/texto/c$i.md; done && \
    git add -A && commita -m "feat: cinco arquivos (SG-02)"
: > "$SCR/shim/chamadas"
( PATH="$SCR/shim:$PATH" ci_simulado tb27a "$ZERO" "$SCR/ci-tb27a.txt" ); r5=$?
n5=$(wc -l < "$SCR/shim/chamadas")
novo_repo tb27b && mkdir -p livro-1/texto && for i in $(seq 1 300); do printf 'Abertura %s.\n' "$i" > livro-1/texto/c$i.md; done && \
    git add -A && commita -m "feat: trezentos arquivos (SG-02)"
: > "$SCR/shim/chamadas"
( PATH="$SCR/shim:$PATH" ci_simulado tb27b "$ZERO" "$SCR/ci-tb27b.txt" ); r300=$?
n300=$(wc -l < "$SCR/shim/chamadas")
rc27=0; [ "$r5" -eq 0 ] && [ "$r300" -eq 0 ] && [ "$n5" = "$n300" ] || rc27=1
caso TB27 OK "$rc27" - - "chamadas git iguais para 5 e 300 arquivos: $n5 e $n300"
