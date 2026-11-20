#!/usr/bin/env bash
# Autoteste do backup diario (TE-03, L-35, L-36). Uso: testes/rodar.sh <pasta-temporaria-vazia>
# Cada caso roda uma copia do roteiro num repositorio descartavel dentro da pasta, com HOME, TMPDIR
# e configuracao global do git apontados para la. Nada toca o repositorio real nem a pasta pessoal.
set -u
export LC_ALL=C

[[ $# -eq 1 && -d "$1" ]] || { echo "uso: $0 <pasta-temporaria-vazia>" >&2; exit 2; }
SCR=$(cd "$1" && pwd) || exit 2
[[ -z "$(ls -A "$SCR")" ]] || { echo "FALHA: a pasta temporaria precisa estar vazia: $SCR" >&2; exit 2; }
ROTEIRO="$(cd "$(dirname "$0")/.." && pwd)/bundle-diario.sh"
[[ -f "$ROTEIRO" ]] || { echo "FALHA: roteiro ausente: $ROTEIRO" >&2; exit 2; }

mkdir -p "$SCR/home" "$SCR/tmp" "$SCR/destino" || exit 2
export HOME="$SCR/home" TMPDIR="$SCR/tmp" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset BACKUPS_BASE GIT_DIR GIT_WORK_TREE

CASOS=0
FALHAS=0

novo_repo() { # NOME: repositorio descartavel com um commit e a copia do roteiro
  local r="$SCR/$1"
  mkdir -p "$r/ferramentas/backup" && cp "$ROTEIRO" "$r/ferramentas/backup/bundle-diario.sh" &&
    git -C "$r" init -q && printf 'x\n' > "$r/a.txt" && git -C "$r" add -A &&
    git -C "$r" -c user.name=Teste -c user.email=teste@exemplo.invalid commit -q -m "chore: base (TE-03)"
}

caso() { # ID RC_ESPERADO RC_OBTIDO TRECHO(ou -) ARQUIVO_DE_SAIDA DESCRICAO
  local st=ok
  CASOS=$((CASOS + 1))
  [[ "$3" == "$2" ]] || st=FALHOU
  if [[ "$4" != "-" ]] && ! grep -qF -- "$4" "$5"; then st=FALHOU; fi
  [[ $st == ok ]] || FALHAS=$((FALHAS + 1))
  echo "$1 esperado=$2 obtido=$3 $st $6"
}

novo_repo b01 || exit 1
bash "$SCR/b01/ferramentas/backup/bundle-diario.sh" > "$SCR/b01.out" 2>&1
caso B01 1 $? "BACKUPS_BASE precisa" "$SCR/b01.out" "sem BACKUPS_BASE: falha fechada"

novo_repo b02 || exit 1
env BACKUPS_BASE=relativo bash "$SCR/b02/ferramentas/backup/bundle-diario.sh" > "$SCR/b02.out" 2>&1
caso B02 1 $? "BACKUPS_BASE precisa" "$SCR/b02.out" "caminho relativo: falha fechada"

novo_repo b03 || exit 1
env BACKUPS_BASE="$SCR/nao-existe" bash "$SCR/b03/ferramentas/backup/bundle-diario.sh" > "$SCR/b03.out" 2>&1
caso B03 1 $? "BACKUPS_BASE precisa" "$SCR/b03.out" "pasta inexistente: falha fechada"

novo_repo b04 || exit 1
mkdir -p "$SCR/b04/dentro"
env BACKUPS_BASE="$SCR/b04/dentro" bash "$SCR/b04/ferramentas/backup/bundle-diario.sh" > "$SCR/b04.out" 2>&1
caso B04 1 $? "dentro do repositorio" "$SCR/b04.out" "pasta dentro do repositorio: falha fechada"

novo_repo b05 || exit 1
env BACKUPS_BASE="$SCR/destino" bash "$SCR/b05/ferramentas/backup/bundle-diario.sh" > "$SCR/b05.out" 2>&1
caso B05 0 $? "Bundle criado e verificado" "$SCR/b05.out" "pasta valida: cria e verifica"

n=$(find "$SCR/destino/b05" -maxdepth 1 -name 'b05-*.bundle' 2>/dev/null | wc -l)
[[ $n -eq 1 ]]
caso B06 0 $? - - "um bundle na pasta de destino (achados: $n)"

arq=$(find "$SCR/destino/b05" -maxdepth 1 -name 'b05-*.bundle' 2>/dev/null | head -n 1)
env -u BACKUPS_BASE bash "$SCR/b05/ferramentas/backup/bundle-diario.sh" --verificar "${arq:-$SCR/nao-existe.bundle}" > "$SCR/b07.out" 2>&1
caso B07 0 $? "OK: bundle integro" "$SCR/b07.out" "verificacao avulsa sem BACKUPS_BASE"

[[ -z "$(find "$SCR/home" -mindepth 1 -print -quit)" ]]
caso B08 0 $? - - "nada escrito na pasta pessoal"

echo "RESUMO casos=$CASOS falharam=$FALHAS"
[[ $CASOS -eq 8 && $FALHAS -eq 0 ]]
