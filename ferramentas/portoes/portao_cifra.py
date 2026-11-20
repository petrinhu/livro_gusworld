"""Portao de cifra (SG-02): classificacao de caminho (lista fechada), modo, binario, heuristica e confianca.

Uma funcao de classificacao so (falha_caminho), usada por pre-commit, ci e envio (L-17).
"""
import math

from portao_git import conteudos, git_tenta
from portao_regras import (AMOSTRA, APROVADOS, ASSINATURAS, BINARIOS, CABECALHO, CONTROLE,
                           CORPO_CURTO, CORPO_ESTATISTICO, CORPO_MIN, EXCECOES, FAIXA_ALTOS, FALA, FILTRO_EXIGIDO,
                           IMPRIMIVEIS, JANELA, K_SIGMA, LIMIAR_LEGIVEL, MODOS_PROIBIDOS, TAMANHO_CABECALHO,
                           TETO_AMOSTRA, TETO_AMOSTRA_ARVORE, TETO_BINARIO, TETO_CLARO, TETO_CLARO_ARVORE,
                           ZONAS_DE_EXCECAO)

# Bytes que nao sao legiveis, para contar por translate (C, sem laco Python por byte).
NAO_IMPRIMIVEIS = bytes(b for b in range(256) if b not in IMPRIMIVEIS)
P_IMPRIMIVEL = len(IMPRIMIVEIS) / 256  # fracao de bytes imprimiveis esperada em bytes aleatorios (98/256)


def filtro_falhas():
    """Filtro git-crypt configurado no repositorio (fail-open sem required, S57)."""
    falhas = []
    for chave, valor_exigido in FILTRO_EXIGIDO:
        rc, val = git_tenta(["config", "--get", chave])
        valor = val.decode("utf-8").strip() if rc == 0 else ""
        if not valor or (valor_exigido is not None and valor != valor_exigido):
            falhas.append(f"filtro sem configuracao local: {chave}")
    return falhas


def modo_falha(modo, caminho):
    if modo in MODOS_PROIBIDOS:
        return f"modo de arquivo proibido (submodulo ou link simbolico): {caminho}"
    return None


def e_excecao(caminho):
    return any(p.fullmatch(caminho) for p in EXCECOES)


def e_zona(caminho):
    return any(p.fullmatch(caminho) for p in ZONAS_DE_EXCECAO)


def e_binario(caminho):
    return caminho.endswith(BINARIOS)


def falha_caminho(caminho, cifrado, rotulo=""):
    """Regras 1 a 5 da OS 5.3, nesta ordem. cifrado: o blob tem o cabecalho. Devolve a falha ou None."""
    if CONTROLE.search(caminho):
        return f"caminho com quebra de linha ou caractere de controle: {caminho!r}"
    if caminho.endswith("/.gitattributes"):
        return f"gitattributes aninhado proibido: {caminho}"
    if FALA.match(caminho) and not caminho.endswith(".md"):
        return f"forma nao aprovada em pasta de texto: {caminho}"
    if e_excecao(caminho):
        return f"cifrado em caminho de excecao, refaca o git add: {caminho}" if cifrado else None
    if e_zona(caminho):
        return f"forma nao aprovada em caminho de excecao: {caminho}"
    if not cifrado:
        return f"{rotulo}sem cabecalho cifrado: {caminho}"
    return None


def falha_amostra(caminho, tamanho):
    """Amostra em claro acima do teto (SG-02, M1). tamanho: bytes do blob (sem cabecalho, ele nao tem)."""
    if AMOSTRA.fullmatch(caminho) and tamanho > TETO_AMOSTRA:
        return f"amostra acima do teto: {caminho}"
    return None


def falha_claro(caminho, tamanho):
    """Arquivo em claro acima do teto, fora da amostra, que tem teto proprio (SG-02d, C1)."""
    if e_excecao(caminho) and not AMOSTRA.fullmatch(caminho) and tamanho > TETO_CLARO:
        return f"arquivo em claro acima do teto: {caminho}"
    return None


def falhas_volume(pares, tamanho):
    """Soma em claro de UMA arvore (SG-02d, C1). pares: (hash, caminho); tamanho: hash -> bytes do blob."""
    claros = [(s, c) for s, c in pares if e_excecao(c)]
    falhas = []
    if sum(tamanho[s] for s, _ in claros) > TETO_CLARO_ARVORE:
        falhas.append("volume em claro acima do teto da arvore")
    if sum(tamanho[s] for s, c in claros if AMOSTRA.fullmatch(c)) > TETO_AMOSTRA_ARVORE:
        falhas.append("amostra acima do teto total da arvore")
    return falhas


def falha_teto(caminho, tamanho):
    """Binario cifrado com conteudo decifrado acima do teto (D7)."""
    if e_binario(caminho) and tamanho > TETO_BINARIO:
        return f"binario acima do teto: {caminho}"
    return None


def portao_cifra(itens):
    """itens: (modo, hash, caminho) do indice. Devolve (analisados, falhas)."""
    falhas = filtro_falhas()
    regulares = []
    for modo, sha, caminho in itens:
        falha = modo_falha(modo, caminho)
        if falha:
            falhas.append(falha)
        else:
            regulares.append((sha, caminho))
    corpos = dict(zip(sorted({s for s, _ in regulares}), conteudos(sorted({s for s, _ in regulares}))))
    analisados, cifrados = 0, 0
    for sha, caminho in regulares:
        cifrado = corpos[sha].startswith(CABECALHO)
        cifrados += cifrado
        falha = (falha_caminho(caminho, cifrado, rotulo="") or falha_amostra(caminho, len(corpos[sha]))
                 or falha_claro(caminho, len(corpos[sha])))
        if falha is None:
            analisados += 1
        else:
            falhas.append(falha)
    falhas.extend(falhas_volume(regulares, {s: len(c) for s, c in corpos.items()}))
    if cifrados == 0:
        falhas.append("nenhum arquivo cifrado no indice")
    return analisados, falhas


def exige_aprovado(caminho):
    """Arquivos de confianca: todo workflow e o ci-bootstrap.sh (SG-02, D2)."""
    return caminho.startswith(".github/workflows/") or caminho == "ferramentas/portoes/ci-bootstrap.sh"


def falhas_confianca(pares):
    """Hash de blob de cada arquivo de confianca tem que estar em APROVADOS. Devolve (exigidos, falhas)."""
    exigidos = [(s, c) for s, c in pares if exige_aprovado(c)]
    falhas = [f"arquivo de confianca nao aprovado: {c}"
              for s, c in exigidos if s not in APROVADOS.get(c, ())]
    return len(exigidos), falhas


BAIXOS = bytes(range(0x80))  # para contar bytes de 0x80 para cima por translate, sem laco por byte


def janelas(cauda):
    """Janelas de JANELA bytes; a ultima, se menor que CORPO_ESTATISTICO, junta-se a anterior (SG-02d)."""
    partes = [cauda[i:i + JANELA] for i in range(0, len(cauda), JANELA)]
    if len(partes) > 1 and len(partes[-1]) < CORPO_ESTATISTICO:
        partes[-2:] = [partes[-2] + partes[-1]]
    return partes


def fora_da_banda(fracao, p, k):
    """Fracao a mais de K_SIGMA desvios-padrao do esperado p de bytes aleatorios numa janela de k bytes."""
    return abs(fracao - p) > K_SIGMA * math.sqrt(p * (1 - p) / k)


def motivo_janela(janela):
    """Motivo da suspeita de uma janela; '' se nao suspeita (SG-02d, C3 e A1)."""
    k = len(janela)
    imprimiveis = len(janela.translate(None, NAO_IMPRIMIVEIS)) / k
    altos = len(janela.translate(None, BAIXOS)) / k
    if imprimiveis >= LIMIAR_LEGIVEL:
        return "legivel"
    if fora_da_banda(imprimiveis, P_IMPRIMIVEL, k):
        return "imprimiveis"
    if not FAIXA_ALTOS[0] <= altos <= FAIXA_ALTOS[1] or fora_da_banda(altos, 0.5, k):
        return "altos"
    if len(set(janela)) < 256 * (1 - (255 / 256) ** k) / 2:
        return "distintos"
    return ""


def motivo_suspeito(corpo):
    """Motivo da suspeita do corpo depois do cabecalho; '' se nao suspeito; None se pequeno (S14, SG-02)."""
    cauda = corpo[TAMANHO_CABECALHO:]
    n = len(cauda)
    if cauda.startswith(ASSINATURAS):
        return "assinatura"
    if n < CORPO_MIN:
        return None
    imprimiveis = len(cauda.translate(None, NAO_IMPRIMIVEIS))
    if n < CORPO_CURTO:
        return "curto" if imprimiveis == n else ""
    if imprimiveis / n >= LIMIAR_LEGIVEL:
        return "legivel"
    if n >= CORPO_ESTATISTICO:
        for janela in janelas(cauda):
            motivo = motivo_janela(janela)
            if motivo:
                return motivo
    return ""


def heuristica(cifrados):
    """cifrados: (caminho, corpo) de cada blob com cabecalho. Devolve (linha, falhas), sem chave (S14, SG-02)."""
    avaliados, pequenos, suspeitos = 0, 0, []
    for caminho, corpo in cifrados:
        motivo = motivo_suspeito(corpo)
        if motivo is None:
            pequenos += 1
            continue
        avaliados += 1
        if motivo:
            suspeitos.append((caminho, motivo))
    linha = (f"[ci-heuristica] cifrados={len(cifrados)} avaliados={avaliados} pequenos={pequenos} "
             f"suspeitos={len(suspeitos)}")
    return linha, [f"corpo legivel apos o cabecalho cifrado ({motivo}): {c}" for c, motivo in suspeitos]
