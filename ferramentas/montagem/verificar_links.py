#!/usr/bin/env python3
"""Verifica os links relativos entre arquivos .md do repositório.

Uso: verificar_links.py [raiz]     (raiz padrão: a raiz deste repositório)

Varre os .md rastreados pelo git e os novos ainda não ignorados, deixando de
fora .insumos/ e saida/. Para cada link relativo [texto](alvo) confere se o
destino existe e, quando há #ancora num destino .md, se a âncora existe.
Links com esquema (https:, mailto:) não são verificados.

Âncoras: slug no estilo GitHub (minúsculas, pontuação removida, espaço vira
hífen, acento mantido; títulos repetidos ganham -1, -2...), mais
<a name="..."> / <a id="..."> e {#...}.

Saída: uma linha por problema, e sempre a linha de resumo
  encontrados=N analisados=N links=N quebrados=N
seguida de resultado=OK ou resultado=REPROVADO.
Código de saída: 0 só se tudo foi analisado, nada quebrou e havia ao menos
um .md; 1 nos demais casos (inclusive varredura vazia).
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import unquote

EXCLUIDOS = (".insumos", "saida")
MAGICO_GITCRYPT = b"\x00GITCRYPT\x00"
RE_COMENTARIO = re.compile(r"<!--.*?-->", re.DOTALL)
RE_CERCA = re.compile(r"^[ \t]*(?:```|~~~)")
RE_CODIGO_EM_LINHA = re.compile(r"`[^`]*`")
RE_LINK = re.compile(r"\[[^\]]*\]\(\s*<?([^)\s>]*)>?(?:\s+\"[^\"]*\")?\s*\)")
RE_ESQUEMA = re.compile(r"^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)")
RE_TITULO = re.compile(r"^[ \t]{0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$")
RE_ANCORA_HTML = re.compile(r"<a\s[^>]*?(?:name|id)=\"([^\"]+)\"|\{#([^}\s]+)\}")
RE_LINK_NO_TITULO = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def linhas_visiveis(texto: str):
    """Pares (número, linha) fora de cerca de código, comentário e código em linha."""
    texto = RE_COMENTARIO.sub(lambda m: "\n" * m.group(0).count("\n"), texto)
    em_cerca = False
    for numero, linha in enumerate(texto.split("\n"), start=1):
        if RE_CERCA.match(linha):
            em_cerca = not em_cerca
            continue
        if not em_cerca:
            yield numero, RE_CODIGO_EM_LINHA.sub(lambda m: " " * len(m.group(0)), linha)


def slug(titulo: str) -> str:
    limpo = RE_LINK_NO_TITULO.sub(r"\1", titulo).replace("*", "").replace("`", "")
    limpo = re.sub(r"[^\w\- ]", "", limpo.strip().lower())
    return limpo.replace(" ", "-")


def ancoras_do_texto(texto: str) -> set[str]:
    ids: set[str] = set()
    vistos: dict[str, int] = {}
    for _, linha in linhas_visiveis(texto):
        titulo = RE_TITULO.match(linha)
        if titulo:
            base = slug(titulo.group(1))
            n = vistos.get(base, 0)
            ids.add(base if n == 0 else f"{base}-{n}")
            vistos[base] = n + 1
        for ancora in RE_ANCORA_HTML.finditer(linha):
            ids.add(ancora.group(1) or ancora.group(2))
    return ids


def ler_arquivo(caminho: Path) -> tuple[str | None, str | None]:
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


def listar_markdown(raiz: Path) -> tuple[list[str], str | None]:
    """Uma única chamada ao git: rastreados mais novos não ignorados, só .md."""
    comando = ["git", "-C", str(raiz), "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    try:
        proc = subprocess.run(comando, capture_output=True, check=False)
    except OSError as erro:
        return [], f"git indisponível ({erro.strerror})"
    if proc.returncode != 0:
        return [], "git falhou (a raiz é um repositório?)"
    nomes: set[str] = set()
    for bruto in proc.stdout.split(b"\0"):
        if not bruto:
            continue
        nome = os.fsdecode(bruto)
        if not nome.endswith(".md") or PurePosixPath(nome).parts[0] in EXCLUIDOS:
            continue
        nomes.add(nome)
    return sorted(nomes), None


def ancoras_do_destino(raiz: Path, destino: str, cache: dict) -> tuple[set[str] | None, str | None]:
    if destino not in cache:
        texto, motivo = ler_arquivo(raiz / destino)
        cache[destino] = (ancoras_do_texto(texto), None) if texto is not None else (None, motivo)
    return cache[destino]


def checar_alvo(raiz: Path, origem: str, alvo: str, cache: dict) -> str | None:
    """Devolve o motivo do link quebrado, ou None se o link está certo."""
    caminho_txt, _, ancora = alvo.partition("#")
    caminho_txt = unquote(caminho_txt)
    ancora = unquote(ancora)
    if caminho_txt == "":
        destino = origem
    else:
        if caminho_txt.startswith("/"):
            base = caminho_txt.lstrip("/")
        else:
            base = (PurePosixPath(origem).parent / caminho_txt).as_posix()
        destino = os.path.normpath(base).replace(os.sep, "/")
        if destino == ".." or destino.startswith("../"):
            return "destino fora do repositório"
        if not (raiz / destino).exists():
            return "arquivo inexistente"
    if ancora == "" or not destino.endswith(".md"):
        return None
    ids, motivo = ancoras_do_destino(raiz, destino, cache)
    if ids is None:
        return f"âncora não verificável: {motivo}"
    return None if ancora in ids else "âncora inexistente"


def problemas_do_arquivo(raiz: Path, rel: str, texto: str, cache: dict) -> tuple[int, list[str]]:
    links = 0
    problemas: list[str] = []
    for numero, linha in linhas_visiveis(texto):
        for casado in RE_LINK.finditer(linha):
            alvo = casado.group(1)
            if not alvo or RE_ESQUEMA.match(alvo):
                continue
            links += 1
            motivo = checar_alvo(raiz, rel, alvo, cache)
            if motivo:
                problemas.append(f"QUEBRADO {rel}:{numero} -> {alvo} ({motivo})")
    return links, problemas


def main(argv: list[str]) -> int:
    raiz = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[2]
    arquivos, erro_git = listar_markdown(raiz)
    saidas: list[str] = []
    if erro_git:
        saidas.append(f"ERRO {erro_git}")

    analisados = 0
    links_total = 0
    cache: dict = {}
    for rel in arquivos:
        texto, motivo = ler_arquivo(raiz / rel)
        if texto is None:
            saidas.append(f"NAO-ANALISADO {rel} ({motivo})")
            continue
        analisados += 1
        n, achados = problemas_do_arquivo(raiz, rel, texto, cache)
        links_total += n
        saidas.extend(achados)

    quebrados = sum(1 for linha in saidas if linha.startswith("QUEBRADO"))
    encontrados = len(arquivos)
    for linha in saidas:
        print(linha)
    print(f"encontrados={encontrados} analisados={analisados} links={links_total} quebrados={quebrados}")

    motivos = []
    if erro_git:
        motivos.append("git")
    if encontrados == 0:
        motivos.append("varredura vazia")
    if analisados != encontrados:
        motivos.append(f"{encontrados - analisados} não analisado(s)")
    if quebrados:
        motivos.append(f"{quebrados} link(s) quebrado(s)")
    if motivos:
        print("resultado=REPROVADO: " + "; ".join(motivos))
        return 1
    print("resultado=OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
