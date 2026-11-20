#!/usr/bin/env bash
# Copia privada diaria do repositorio por git bundle (TE-03, L-24 emenda 14/11/2026).
#
# Uso:
#   BACKUPS_BASE=<pasta> bundle-diario.sh     cria, verifica e rotaciona (mantem 7)
#   bundle-diario.sh --verificar <arquivo>    so verifica o bundle; sai 0 (integro) ou 1 (falha)
#
# Verificacao: git bundle verify + clone bare + git fsck --full. O verify sozinho
# aceita bundle truncado (medido); o clone e o fsck que acusam o corte.
# O bundle nao contem a chave do git-crypt nem as pastas ignoradas pelo git.
set -euo pipefail
shopt -s nullglob
export LC_ALL=C

MANTER=7
# Pasta-base das copias: vem do ambiente, definida fora do repositorio (unidade do agendador).
BACKUPS_BASE="${BACKUPS_BASE:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
NOME="$(basename "$REPO")"

if [[ ! "$NOME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "FALHA: nome do repositorio fora do padrao seguro: $NOME" >&2
  exit 1
fi

verificar_bundle() {
  local arq="$1" base tmp rc=0
  base="${TMPDIR:-/var/tmp}"

  if ! git -C "$REPO" bundle verify -q "$arq"; then
    echo "FALHA: git bundle verify reprovou: $arq" >&2
    return 1
  fi

  tmp="$(mktemp -d "$base/bundle-verify.XXXXXX")"
  if ! git clone -q --bare "$arq" "$tmp/repo.git" 2>/dev/null; then
    echo "FALHA: clone do bundle falhou (bundle truncado ou corrompido): $arq" >&2
    rc=1
  elif ! git -C "$tmp/repo.git" fsck --full >/dev/null 2>&1; then
    echo "FALHA: git fsck --full reprovou o clone do bundle: $arq" >&2
    rc=1
  fi

  case "$tmp" in
    "$base"/bundle-verify.*) rm -rf -- "$tmp" ;;
    *) echo "AVISO: temporario fora do padrao, nao apagado: $tmp" >&2; return 1 ;;
  esac
  return $rc
}

if [[ "${1:-}" == "--verificar" ]]; then
  if [[ -z "${2:-}" || ! -f "$2" ]]; then
    echo "uso: $0 --verificar <arquivo.bundle>" >&2
    exit 2
  fi
  if verificar_bundle "$(readlink -f -- "$2")"; then
    echo "OK: bundle integro (verify + clone + fsck): $2"
    exit 0
  fi
  exit 1
fi

if [[ -z "$BACKUPS_BASE" || "$BACKUPS_BASE" != /* || ! -d "$BACKUPS_BASE" ]]; then
  echo "FALHA: BACKUPS_BASE precisa ser o caminho absoluto de uma pasta existente, definido fora do repositorio" >&2
  exit 1
fi
case "$(readlink -f -- "$BACKUPS_BASE")/" in
  "$REPO"/*) echo "FALHA: BACKUPS_BASE dentro do repositorio: $BACKUPS_BASE" >&2; exit 1 ;;
esac
DEST="$BACKUPS_BASE/$NOME"

case "$DEST" in
  "$BACKUPS_BASE/$NOME") ;;
  *) echo "FALHA: destino fora do padrao: $DEST" >&2; exit 1 ;;
esac

mkdir -p -- "$DEST"

STAMP="$(date +%Y%m%d-%H%M%S)"
FINAL="$DEST/$NOME-$STAMP.bundle"
PARCIAL="$FINAL.parcial"
HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"

if ! git -C "$REPO" bundle create -q "$PARCIAL" --all; then
  rm -f -- "$PARCIAL"
  echo "FALHA: git bundle create falhou" >&2
  exit 1
fi

if ! verificar_bundle "$PARCIAL"; then
  rm -f -- "$PARCIAL"
  echo "FALHA: bundle novo reprovado; nada foi rotacionado (os antigos foram preservados)" >&2
  exit 1
fi

if ! git -C "$REPO" bundle list-heads "$PARCIAL" | awk -v h="$HEAD_SHA" '$1==h {f=1} END {exit !f}'; then
  rm -f -- "$PARCIAL"
  echo "FALHA: HEAD $HEAD_SHA nao esta no bundle; nada foi rotacionado" >&2
  exit 1
fi

mv -- "$PARCIAL" "$FINAL"
echo "Bundle criado e verificado: $FINAL"
echo "HEAD empacotado: $HEAD_SHA"
echo "Tamanho: $(du -h -- "$FINAL" | cut -f1)"

ARQS=( "$DEST"/"$NOME"-????????-??????.bundle )
TOTAL=${#ARQS[@]}
EXCESSO=$(( TOTAL - MANTER ))
APAGADOS=0
if (( EXCESSO > 0 )); then
  APAGAR=( "${ARQS[@]:0:EXCESSO}" )
  for f in "${APAGAR[@]}"; do
    echo "Apagando antigo (fora dos $MANTER mais recentes): $f"
  done
  rm -- "${APAGAR[@]}"
  APAGADOS=$EXCESSO
fi
echo "Rotacao: $TOTAL encontrados, $APAGADOS apagados, $(( TOTAL - APAGADOS )) mantidos em $DEST"
