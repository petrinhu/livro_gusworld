#!/usr/bin/env python3
"""Conta palavras de história nos capítulos de um livro.

Uso: contar_palavras.py <pasta-do-livro> [--min N] [--max N]

Lê texto/c*.md e tira a marcação Markdown: bloco de metadados inicial,
comentários HTML e imagens saem; links ficam só com o texto; cabeçalhos,
ênfase, listas e citações perdem a marcação. Palavra é uma sequência de
letras e dígitos, com hífen ou apóstrofo interno contando como uma só
(guarda-chuva = 1). Travessões e pontuação não contam.

Imprime uma linha por capítulo, o total e se o total está dentro da faixa.
A faixa padrão (75000 a 87500) é o critério de pronto de cada livro.

Códigos de saída:
  0  total dentro da faixa
  1  total fora da faixa
  2  nada para julgar: sem texto/c*.md, capítulo cifrado ou ilegível, uso inválido
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FAIXA_MIN = 75_000
FAIXA_MAX = 87_500

MAGICO_GITCRYPT = b"\x00GITCRYPT\x00"
PADRAO_PALAVRA = re.compile(r"[^\W_]+(?:['’-][^\W_]+)*")
RE_METADADOS = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)
RE_COMENTARIO = re.compile(r"<!--.*?-->", re.DOTALL)
RE_CERCA = re.compile(r"^[ \t]*(?:```|~~~).*$", re.MULTILINE)
RE_IMAGEM = re.compile(r"!\[[^\]]*\]\([^)]*\)")
RE_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
RE_DEFINICAO = re.compile(r"^[ \t]{0,3}\[[^\]]+\]:.*$", re.MULTILINE)
RE_TAG = re.compile(r"</?[A-Za-z][^>]*>")
RE_PREFIXO = re.compile(
    r"^[ \t]{0,3}(?:#{1,6}[ \t]+|>[ \t]?|(?:[-*+]|\d+[.)])[ \t]+)", re.MULTILINE
)


def texto_puro(md: str) -> str:
    """Devolve o texto de história sem a marcação Markdown."""
    texto = RE_METADADOS.sub("", md, count=1)
    texto = RE_COMENTARIO.sub(" ", texto)
    texto = RE_CERCA.sub("", texto)
    texto = RE_IMAGEM.sub(" ", texto)
    texto = RE_LINK.sub(r"\1", texto)
    texto = RE_DEFINICAO.sub("", texto)
    texto = RE_TAG.sub(" ", texto)
    return RE_PREFIXO.sub("", texto)


def contar_palavras(md: str) -> int:
    return len(PADRAO_PALAVRA.findall(texto_puro(md)))


def capitulos(pasta: Path) -> list[Path]:
    return sorted(p for p in (pasta / "texto").glob("c*.md") if p.is_file())


def ler_capitulo(caminho: Path) -> tuple[str | None, str | None]:
    """Devolve (texto, motivo). Motivo é None quando a leitura deu certo."""
    try:
        dados = caminho.read_bytes()
    except OSError:
        return None, "leitura falhou"
    if dados.startswith(MAGICO_GITCRYPT):
        return None, "cifrado, git-crypt bloqueado"
    try:
        return dados.decode("utf-8"), None
    except UnicodeDecodeError:
        return None, "não é UTF-8"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Conta palavras de história por capítulo.")
    ap.add_argument("pasta", type=Path, help="pasta do livro (contém texto/c*.md)")
    ap.add_argument("--min", dest="minimo", type=int, default=FAIXA_MIN)
    ap.add_argument("--max", dest="maximo", type=int, default=FAIXA_MAX)
    args = ap.parse_args(argv)
    if args.minimo < 0 or args.minimo > args.maximo:
        ap.error("faixa inválida: é preciso 0 <= min <= max")

    caps = capitulos(args.pasta)
    if not caps:
        print(f"ERRO: nenhum texto/c*.md em {args.pasta}; sem contagem não há veredito")
        return 2

    total = 0
    for cap in caps:
        texto, motivo = ler_capitulo(cap)
        if texto is None:
            print(f"ERRO: {cap.name} ilegível ({motivo}); sem contagem não há veredito")
            return 2
        n = contar_palavras(texto)
        total += n
        print(f"{cap.name} palavras={n}")

    dentro = args.minimo <= total <= args.maximo
    resultado = "DENTRO" if dentro else "FORA"
    print(
        f"TOTAL palavras={total} capitulos={len(caps)} "
        f"faixa={args.minimo}-{args.maximo} resultado={resultado}"
    )
    return 0 if dentro else 1


if __name__ == "__main__":
    sys.exit(main())
