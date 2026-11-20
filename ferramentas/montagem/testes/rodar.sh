#!/usr/bin/env bash
# Autoteste de contar_palavras.py e verificar_links.py (L-36).
# Cada ferramenta tem caso bom (passa), caso ruim (reprova) e varredura vazia (reprova).
# As fixtures são genéricas e nascem num diretório temporário fora do repositório.
# Uso: testes/rodar.sh   Sai 1 se algum caso falhar ou se nenhum caso rodou.

set -u

aqui=$(cd "$(dirname "$0")" && pwd)
montagem=$(dirname "$aqui")
contar="$montagem/contar_palavras.py"
verificar="$montagem/verificar_links.py"
# Travessão montado em tempo de execução: o fonte não carrega o caractere.
trav=$(printf '\342\200\224')

tmp=$(mktemp -d "${TMPDIR:-/var/tmp}/te02-XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

total=0
falhas=0

afirma() {
  # afirma <nome> <rc_esperado> <trecho_fixo> <comando...>
  local nome=$1 rc_esp=$2 trecho=$3
  shift 3
  local saida rc
  saida=$("$@" 2>&1)
  rc=$?
  total=$((total + 1))
  if [ "$rc" -eq "$rc_esp" ] && printf '%s\n' "$saida" | grep -qF -- "$trecho"; then
    echo "OK     $nome (rc=$rc)"
  else
    echo "FALHA  $nome (rc=$rc, esperado rc=$rc_esp com \"$trecho\")"
    falhas=$((falhas + 1))
  fi
  printf '%s\n' "$saida" | sed 's/^/       | /'
}

capitulo_bom() {
  # Contagem esperada: título 3, parágrafo 7 (comentário e imagem fora),
  # diálogo 5, linha com tag 3, item de lista 3 = 21. Metadados (2 palavras) fora.
  cat <<'FIM' | sed "s/@TRAV@/$trav/g" > "$1"
---
titulo: Teste
---
# Título do capítulo

Uma *frase* com [um link](outro.md) e <!-- oculto aqui --> fim.

![legenda da imagem](img.png)

@TRAV@ Oi, disse ela. Guarda-chuva novo.

<span>tag</span> e `codigo`.

- item de lista
FIM
}

gera_livro() {
  # gera_livro <pasta> <n_palavras>: um capítulo com exatamente n palavras
  mkdir -p "$1/texto"
  python3 -c 'import sys; open(sys.argv[1], "w", encoding="utf-8").write("palavra " * int(sys.argv[2]) + "\n")' "$1/texto/c01.md" "$2"
}

repo_novo() {
  mkdir -p "$1" && git -C "$1" init -q
}

echo "== contar_palavras.py"

mkdir -p "$tmp/bom/texto"
capitulo_bom "$tmp/bom/texto/c01.md"
afirma "contar: capítulo bom, faixa de teste" 0 \
  "TOTAL palavras=21 capitulos=1 faixa=1-100 resultado=DENTRO" \
  python3 "$contar" "$tmp/bom" --min 1 --max 100

afirma "contar: mesmo livro fora da faixa" 1 \
  "TOTAL palavras=21 capitulos=1 faixa=50-100 resultado=FORA" \
  python3 "$contar" "$tmp/bom" --min 50 --max 100

mkdir -p "$tmp/vazio/texto"
afirma "contar: pasta sem capítulos reprova (varredura vazia)" 2 \
  "nenhum texto/c*.md" \
  python3 "$contar" "$tmp/vazio"

mkdir -p "$tmp/sem_texto"
afirma "contar: pasta sem pasta texto/ reprova" 2 \
  "nenhum texto/c*.md" \
  python3 "$contar" "$tmp/sem_texto"

mkdir -p "$tmp/cifrado/texto"
printf '\000GITCRYPT\000\001\002\377' > "$tmp/cifrado/texto/c01.md"
afirma "contar: capítulo cifrado não vira verde" 2 \
  "cifrado" \
  python3 "$contar" "$tmp/cifrado"

afirma "contar: faixa invertida é erro de uso" 2 \
  "faixa inválida" \
  python3 "$contar" "$tmp/bom" --min 10 --max 5

gera_livro "$tmp/abaixo" 74999
afirma "contar: 74999 palavras reprovam (abaixo de 75000)" 1 \
  "TOTAL palavras=74999 capitulos=1 faixa=75000-87500 resultado=FORA" \
  python3 "$contar" "$tmp/abaixo"

gera_livro "$tmp/piso" 75000
afirma "contar: 75000 palavras passam (piso incluído)" 0 \
  "TOTAL palavras=75000 capitulos=1 faixa=75000-87500 resultado=DENTRO" \
  python3 "$contar" "$tmp/piso"

gera_livro "$tmp/teto" 87500
afirma "contar: 87500 palavras passam (teto incluído)" 0 \
  "TOTAL palavras=87500 capitulos=1 faixa=75000-87500 resultado=DENTRO" \
  python3 "$contar" "$tmp/teto"

gera_livro "$tmp/acima" 87501
afirma "contar: 87501 palavras reprovam (acima de 87500)" 1 \
  "TOTAL palavras=87501 capitulos=1 faixa=75000-87500 resultado=FORA" \
  python3 "$contar" "$tmp/acima"

echo "== verificar_links.py"

r="$tmp/ok"
repo_novo "$r"
cat > "$r/a.md" <<'FIM'
# Início

Veja [a seção](b.md#se%C3%A7%C3%A3o-um), o [topo](#início), a [nota](b.md#nota-1) e a [imagem](img/pic.png).
Externo [site](https://exemplo.invalido/x) não conta.
FIM
cat > "$r/b.md" <<'FIM'
# Outro

## Seção Um

## Nota

## Nota

texto
FIM
mkdir -p "$r/c" "$r/img" "$r/.insumos"
cat > "$r/c/d.md" <<'FIM'
# Topo

Voltar para [o início](../a.md) e [topo](#topo).
FIM
printf 'Quebrado [q](nada.md).\n' > "$r/.insumos/x.md"
printf 'x\n' > "$r/img/pic.png"
afirma "verificar: repositório bom (inclui não rastreado, exclui .insumos/)" 0 \
  "encontrados=3 analisados=3 links=6 quebrados=0" \
  python3 "$verificar" "$r"

q1="$tmp/quebra_arquivo"
cp -R "$r" "$q1"
printf 'Falta [x](naoexiste.md).\n' >> "$q1/a.md"
afirma "verificar: arquivo inexistente reprova" 1 \
  "encontrados=3 analisados=3 links=7 quebrados=1" \
  python3 "$verificar" "$q1"

q2="$tmp/quebra_ancora"
cp -R "$r" "$q2"
printf 'Falta [y](b.md#nao-existe).\n' >> "$q2/a.md"
afirma "verificar: âncora inexistente reprova" 1 \
  "encontrados=3 analisados=3 links=7 quebrados=1" \
  python3 "$verificar" "$q2"

q3="$tmp/quebra_fora"
cp -R "$r" "$q3"
printf 'Fora [x](../../fora.md).\n' >> "$q3/a.md"
afirma "verificar: link que escapa do repositório reprova" 1 \
  "destino fora do repositório" \
  python3 "$verificar" "$q3"

c1="$tmp/repo_cifrado"
repo_novo "$c1"
printf '# A\n' > "$c1/a.md"
printf '\000GITCRYPT\000\001\002\377' > "$c1/e.md"
afirma "verificar: .md cifrado não analisado reprova (analisados != encontrados)" 1 \
  "encontrados=2 analisados=1 links=0 quebrados=0" \
  python3 "$verificar" "$c1"

z1="$tmp/vazio"
repo_novo "$z1"
printf 'texto sem markdown\n' > "$z1/leia.txt"
afirma "verificar: varredura vazia reprova" 1 \
  "encontrados=0 analisados=0 links=0 quebrados=0" \
  python3 "$verificar" "$z1"

mkdir -p "$tmp/nao_repo"
afirma "verificar: raiz que não é repositório reprova" 1 \
  "encontrados=0 analisados=0 links=0 quebrados=0" \
  python3 "$verificar" "$tmp/nao_repo"

echo
echo "casos=$total falhas=$falhas"
if [ "$total" -eq 0 ] || [ "$falhas" -ne 0 ]; then
  echo "RESULTADO: REPROVADO"
  exit 1
fi
echo "RESULTADO: OK"
exit 0
