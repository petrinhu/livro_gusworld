"""Portao de travessao (SG-02): proibido em todo arquivo decifrado, salvo abrindo fala nos textos."""
from portao_cifra import e_binario, falha_teto
from portao_git import conteudos_filtrados
from portao_regras import CABECALHO, FALA, TRAVESSOES


def travessao_fora_de_lugar(texto, fala_permitida):
    """Numero da primeira linha com travessao fora de inicio de fala, ou 0."""
    linhas = texto.split("\n")
    for n, linha in enumerate(linhas):
        for pos, ch in enumerate(linha):
            if ch not in TRAVESSOES:
                continue
            inicio = linha[:pos].strip(" \t") == ""
            anterior = linhas[n - 1] if n > 0 else ""
            paragrafo = n == 0 or anterior.strip() == "" or anterior.lstrip().startswith("#")
            if not (fala_permitida and inicio and paragrafo):
                return n + 1
    return 0


def falha_travessao(caminho, texto):
    """Falha de travessao fora de inicio de fala num texto decifrado ou em claro, ou None (SG-02, S40)."""
    n = travessao_fora_de_lugar(texto, bool(FALA.match(caminho)))
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
