#!/bin/bash
# Autoteste dos portoes de sigilo (SG-02, L-36).
# Uso: rodar.sh DIRETORIO_SCRATCH [FONTE]
# FONTE padrao: ferramentas/portoes da arvore de trabalho. Modo novo quando FONTE tem instalar.sh;
# modo legado quando nao tem. Cada caso cria repositorio descartavel dentro de DIRETORIO_SCRATCH.
# Sai 0 so se todos os casos baterem com o esperado e com o trecho fixo da saida.
set -u

TST=$(cd "$(dirname "$0")" && pwd) || exit 1
RAIZ=$(cd "$TST/../../.." && pwd) || exit 1
SCR=${1:?"uso: rodar.sh DIRETORIO_SCRATCH [FONTE]"}
mkdir -p "$SCR" && SCR=$(cd "$SCR" && pwd) || exit 1
FONTE=${2:-$RAIZ/ferramentas/portoes}
export RAIZ SCR FONTE

# Ambiente isolado: nenhum hook global nem config global real entra nos casos.
export HOME="$SCR/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.claude/githooks"
printf '#!/bin/sh\necho pre-commit >> "$HOME/marcas"\nexit "${RC_GLOBAL:-0}"\n' > "$HOME/.claude/githooks/pre-commit"
printf '#!/bin/sh\necho commit-msg >> "$HOME/marcas"\nexit 0\n' > "$HOME/.claude/githooks/commit-msg"
chmod 755 "$HOME/.claude/githooks/pre-commit" "$HOME/.claude/githooks/commit-msg"

. "$TST/comum.sh"
cd "$SCR" || exit 1
for grupo in ${GRUPOS:-casos-atuais casos-confianca casos-cifra casos-mensagem casos-travessao casos-tracos casos-sg02c casos-sg02d casos-sg02e casos-sg02f}; do
    . "$TST/$grupo.sh"
done

echo "RESUMO casos=$CASOS falharam=$FALHAS"
[ "$FALHAS" -eq 0 ] && [ "$CASOS" -gt 0 ]
