#!/usr/bin/env bash
# montar.sh (TE-01): monta um livro em HTML5 navegavel e em ePub 3.
#
# Uso:
#   montar.sh <pasta-do-livro>
#
# Entrada, dentro da pasta do livro:
#   texto/c*.md      capitulos, em ordem de nome (c01, c02, ...)
#   metadados.yaml   titulo, autor, lang e identifier fixo
#
# Saida, na pasta saida/ da raiz do repositorio (ignorada pelo git):
#   saida/<nome-da-pasta>.html   HTML5 de arquivo unico, com sumario e CSS embutido
#   saida/<nome-da-pasta>.epub   ePub 3, com sumario
#
# Os links entre capitulos (arquivo.md ou arquivo.md#id) viram links internos
# pelo filtro-links.lua. Qualquer erro aborta com status diferente de zero.
set -euo pipefail
export LC_ALL=C

if [[ $# -ne 1 ]]; then
  echo "uso: montar.sh <pasta-do-livro>" >&2
  exit 2
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "FALHA: pandoc nao encontrado no PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
CSS="$SCRIPT_DIR/estilo.css"
FILTRO="$SCRIPT_DIR/filtro-links.lua"

if [[ ! -d "$1" ]]; then
  echo "FALHA: pasta do livro nao existe: $1" >&2
  exit 1
fi
LIVRO="$(cd "$1" && pwd)"
NOME="$(basename "$LIVRO")"
if [[ ! "$NOME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "FALHA: nome da pasta fora do padrao seguro: $NOME" >&2
  exit 1
fi

META="$LIVRO/metadados.yaml"
if [[ ! -f "$META" ]]; then
  echo "FALHA: falta o arquivo de metadados: $META" >&2
  exit 1
fi

shopt -s nullglob
CAPITULOS=( "$LIVRO"/texto/c*.md )
shopt -u nullglob
if (( ${#CAPITULOS[@]} == 0 )); then
  echo "FALHA: nenhum capitulo texto/c*.md em $LIVRO" >&2
  exit 1
fi
echo "capitulos: ${#CAPITULOS[@]}"

SAIDA="$REPO/saida"
mkdir -p "$SAIDA"

# HTML5 de arquivo unico. Escreve num .tmp e so troca no fim, para nao deixar
# saida pela metade se o pandoc falhar.
TMP_HTML="$SAIDA/$NOME.html.tmp"
pandoc "${CAPITULOS[@]}" \
  --from markdown --to html5 --standalone --embed-resources \
  --metadata-file="$META" --css="$CSS" \
  --toc --toc-depth=2 \
  --lua-filter="$FILTRO" \
  -o "$TMP_HTML"
mv -f "$TMP_HTML" "$SAIDA/$NOME.html"

# ePub 3, pelo mesmo caminho.
TMP_EPUB="$SAIDA/$NOME.epub.tmp"
pandoc "${CAPITULOS[@]}" \
  --from markdown --to epub3 --standalone \
  --metadata-file="$META" --css="$CSS" \
  --toc --toc-depth=2 \
  --lua-filter="$FILTRO" \
  -o "$TMP_EPUB"
mv -f "$TMP_EPUB" "$SAIDA/$NOME.epub"

for arq in "$SAIDA/$NOME.html" "$SAIDA/$NOME.epub"; do
  if [[ ! -s "$arq" ]]; then
    echo "FALHA: saida vazia: $arq" >&2
    exit 1
  fi
  echo "ok: $arq"
done
