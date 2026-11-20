"""Portao de travessao (SG-02): proibido em todo arquivo decifrado, salvo abrindo fala nos textos.

Antes de julgar: a entidade HTML de travessao vira o caractere (o pandoc decodifica entidade, com ou sem
smart); no fonte do pandoc (texto/*.md), hifen duplo ou triplo vira travessao (extensao smart, D3).
"""
import html.entities
import re

from portao_cifra import e_binario, falha_teto
from portao_git import conteudos_filtrados
from portao_regras import CABECALHO, FALA, TRAVESSOES

# Nome HTML5 (sem ponto e virgula) de cada travessao: lido da tabela da biblioteca padrao, nunca escrito aqui.
_NOMES = sorted((k[:-1] for k, v in html.entities.html5.items() if k.endswith(";") and v in TRAVESSOES),
                key=len, reverse=True)
ENTIDADE = re.compile(r"&(?:(?P<nome>%s);|#(?:[xX](?P<hex>[0-9a-fA-F]+)|(?P<dec>[0-9]+));)"
                      % "|".join(re.escape(n) for n in _NOMES))
TITULO = re.compile(r"#{1,6}(?:[ \t]|$)")
SO_TRACOS = re.compile(r"[\s\-|:+]*")  # regua e linha de tabela: nao e fala


def _troca_entidade(m):
    if m.group("nome") is not None:
        ch = html.entities.html5[m.group("nome") + ";"]
    else:
        cod = int(m.group("hex"), 16) if m.group("hex") is not None else int(m.group("dec"))
        ch = chr(cod) if cod <= 0x10FFFF else ""
    return ch if ch in TRAVESSOES else m.group(0)


def normaliza_texto(texto, fonte_pandoc):
    """Entidade de travessao vira o caractere; no fonte do pandoc, hifen duplo vira travessao (smart)."""
    texto = ENTIDADE.sub(_troca_entidade, texto)
    if not fonte_pandoc:
        return texto
    linhas = [ln if SO_TRACOS.fullmatch(ln) else ln.replace("---", "\u2014").replace("--", "\u2013")
              for ln in texto.split("\n")]
    return "\n".join(linhas)


def _paragrafo(linhas, n):
    """Linha n abre paragrafo: vem depois de linha vazia, ou depois de titulo com espaco que vem de linha vazia."""
    def vazia(i):
        return i < 0 or linhas[i].strip() == ""
    return vazia(n - 1) or (TITULO.match(linhas[n - 1].lstrip()) is not None and vazia(n - 2))


def travessao_fora_de_lugar(texto, fala_permitida):
    """Numero da primeira linha com travessao fora de inicio de fala, ou 0."""
    linhas = texto.split("\n")
    for n, linha in enumerate(linhas):
        for pos, ch in enumerate(linha):
            if ch not in TRAVESSOES:
                continue
            inicio = linha[:pos].strip(" \t") == ""
            if not (fala_permitida and inicio and _paragrafo(linhas, n)):
                return n + 1
    return 0


def falha_travessao(caminho, texto):
    """Falha de travessao fora de inicio de fala num texto decifrado ou em claro, ou None (SG-02, S40, S42, S59)."""
    fala = bool(FALA.match(caminho))
    n = travessao_fora_de_lugar(normaliza_texto(texto, fala and caminho.endswith(".md")), fala)
    return f"travessao fora de inicio de fala, linha {n}: {caminho}" if n else None


def portao_travessao(itens):
    falhas, analisados = [], 0
    alvo = []
    for sha, caminho in itens:
        if "\n" in caminho:
            falhas.append(f"caminho com quebra de linha, nao analisado: {caminho!r}")
        else:
            alvo.append((sha, caminho))
    corpos = conteudos_filtrados(alvo)
    for (_sha, caminho), corpo in zip(alvo, corpos):
        if corpo.startswith(CABECALHO):
            falhas.append("conteudo decifrado ainda comeca com o cabecalho (arquivo de trabalho ja era "
                          f"cifrado): {caminho}")
            continue
        if e_binario(caminho):
            falha = falha_teto(caminho, len(corpo))
            if falha:
                falhas.append(falha)
            else:
                analisados += 1
            continue
        try:
            texto = corpo.decode("utf-8")
        except UnicodeDecodeError:
            falhas.append(f"nao e UTF-8, nao analisado: {caminho}")
            continue
        falha = falha_travessao(caminho, texto)
        if falha:
            falhas.append(falha)
        else:
            analisados += 1
    return analisados, falhas
