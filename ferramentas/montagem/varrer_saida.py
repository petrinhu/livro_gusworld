#!/usr/bin/env python3
"""Varredura da saida da montagem (SG-02, OS 5.5): travessao so abrindo fala, dentro de <p>.

Uso: varrer_saida.py HTML EPUB
Confere o HTML e cada .xhtml, .html, .htm, .ncx e .opf do EPUB (zip). Entidade de travessao vira o caractere
antes da varredura. Imprime [saida] encontrados=D analisados=D falharam=F e, por falha, arquivo e linha, nunca
o texto. Sai 0 so se todo documento passa; varredura vazia reprova.
"""
import html.entities
import os
import re
import sys
import zipfile

sys.dont_write_bytecode = True

TRAVESSOES = ("\u2014", "\u2013")
TRAV = re.compile("[\u2014\u2013]")
ABRE_P = re.compile(r"<p(?:\s[^<>]*)?>\s*\Z")
EXTENSOES = (".xhtml", ".html", ".htm", ".ncx", ".opf")
_NOMES = sorted((k[:-1] for k, v in html.entities.html5.items() if k.endswith(";") and v in TRAVESSOES),
                key=len, reverse=True)
ENTIDADE = re.compile(r"&(?:(?P<nome>%s);|#(?:[xX](?P<hex>[0-9a-fA-F]+)|(?P<dec>[0-9]+));)"
                      % "|".join(re.escape(n) for n in _NOMES))


def _troca_entidade(m):
    if m.group("nome") is not None:
        ch = html.entities.html5[m.group("nome") + ";"]
    else:
        cod = int(m.group("hex"), 16) if m.group("hex") is not None else int(m.group("dec"))
        ch = chr(cod) if cod <= 0x10FFFF else ""
    return ch if ch in TRAVESSOES else m.group(0)


def linhas_com_falha(texto):
    """Numero (1-based) da linha de cada travessao que nao abre <p>, depois de trocar entidades."""
    texto = ENTIDADE.sub(_troca_entidade, texto)
    achados = []
    for m in TRAV.finditer(texto):
        if not ABRE_P.search(texto[max(0, m.start() - 300):m.start()]):
            achados.append(texto.count("\n", 0, m.start()) + 1)
    return achados


def documentos(html_path, epub_path):
    """(nome, bytes) de cada documento: o HTML e as entradas do EPUB com extensao de texto."""
    with open(html_path, "rb") as f:
        docs = [(os.path.basename(html_path), f.read())]
    with zipfile.ZipFile(epub_path) as z:
        for info in z.infolist():
            if info.filename.lower().endswith(EXTENSOES):
                docs.append((f"{os.path.basename(epub_path)}!{info.filename}", z.read(info)))
    return docs


def main(argv):
    if len(argv) != 3:
        print("uso: varrer_saida.py HTML EPUB", file=sys.stderr)
        return 2
    try:
        docs = documentos(argv[1], argv[2])
    except (OSError, zipfile.BadZipFile) as e:
        print(f"ERRO (varredura fecha por seguranca): {e}")
        return 1
    falhas, analisados = [], 0
    for nome, bruto in docs:
        try:
            texto = bruto.decode("utf-8")
        except UnicodeDecodeError:
            falhas.append(f"nao e UTF-8, nao analisado na saida: {nome}")
            continue
        for n in linhas_com_falha(texto):
            falhas.append(f"travessao fora de inicio de fala na saida: {nome} ({n})")
        analisados += 1
    encontrados = len(docs)
    print(f"[saida] encontrados={encontrados} analisados={analisados} falharam={len(falhas)}")
    if encontrados == 0:
        print("  FALHOU varredura vazia: piso de verificacao zero (L-36)")
    for f in falhas:
        print(f"  FALHOU {f}")
    return 0 if encontrados > 0 and analisados == encontrados and not falhas else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
