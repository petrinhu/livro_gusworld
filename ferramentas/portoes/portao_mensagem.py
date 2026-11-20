"""Portao de mensagem e autor (SG-02): assunto, ID, sessao, travessao, comentario no inicio e identidade noreply.

Uma funcao so de falhas (falhas_mensagem), usada pelo gancho local (texto acima da tesoura), pelo ci e pelo
envio (mensagem gravada inteira, sem corte).
"""
import html.entities
import re
import unicodedata

from portao_git import git_tenta, imprime
from portao_regras import ASSUNTO, ASSUNTO_MAX, NOREPLY, SESSAO, TESOURA, TRAVESSOES

MENSAGEM_ASSUNTO = "assunto fora de 'tipo(escopo)?: descricao (ID)' ou com mais de 72 caracteres"
MENSAGEM_SESSAO_LOCAL = "linha de sessao (Claude-Session) proibida na mensagem"
MENSAGEM_SESSAO_GRAVADA = "cita sessao (Claude-Session)"  # texto antigo, que os testes do ci e do envio usam
MENSAGEM_TRAVESSAO = "travessao na mensagem"
MENSAGEM_COMENTARIO = "mensagem comeca com linha de comentario"
RODAPE = re.compile(r"Co-Authored-By: [^<>\n]+ <noreply@anthropic\.com>")
MENSAGEM_RODAPE = "rodape fora do modelo 'Co-Authored-By: <modelo> <noreply@anthropic.com>'"

# Codigos de travessao de mensagem e entidades que os nomeiam: a tabela HTML5 da biblioteca padrao.
_CODIGOS = frozenset(ord(c) for c in TRAVESSOES)
_NOMES = sorted((k[:-1] for k, v in html.entities.html5.items()
                 if k.endswith(";") and len(v) == 1 and ord(v) in _CODIGOS), key=len, reverse=True)
_ENTIDADE = re.compile(r"&(?:%s);|&#(?:[xX](?P<hex>[0-9a-fA-F]+)|(?P<dec>[0-9]+));"
                       % "|".join(re.escape(n) for n in _NOMES))


def portao_autor():
    falhas, analisados = [], 0
    for var in ("GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"):
        rc, saida = git_tenta(["var", var])
        m = re.search(r"<([^<>]*)>", saida.decode("utf-8", "replace")) if rc == 0 else None
        if m and m.group(1) == NOREPLY:
            analisados += 1
        else:
            falhas.append(f"{var} nao e o noreply do autor")
    return analisados, falhas


def normaliza_sessao(texto):
    """NFKC, sem caractere de formato (Cf, como largura zero), em caixa baixa: a forma que a sessao casa."""
    t = unicodedata.normalize("NFKC", texto)
    return "".join(c for c in t if unicodedata.category(c) != "Cf").casefold()


def cita_sessao(texto):
    n = normaliza_sessao(texto)
    return any(r.search(n) for r in SESSAO)


def tem_travessao(texto):
    """Travessao de mensagem: caractere da lista fechada ou entidade que o nomeia (checa a forma NFKC)."""
    t = unicodedata.normalize("NFKC", texto)
    if any(c in TRAVESSOES for c in t):
        return True
    for m in _ENTIDADE.finditer(t):
        if m.group("hex") is None and m.group("dec") is None:
            return True
        cod = int(m.group("hex"), 16) if m.group("hex") is not None else int(m.group("dec"))
        if cod in _CODIGOS:
            return True
    return False


def primeira_linha(texto):
    """Primeira linha nao vazia, sem espaco final (o git limpa o espaco final, e o gancho julga isso)."""
    return next((ln for ln in texto.split("\n") if ln.strip()), "").rstrip()


def assunto_ok(linha):
    return ASSUNTO.fullmatch(linha) is not None and len(linha) <= ASSUNTO_MAX


def falha_assunto(texto):
    """Falha do formato do assunto (so o assunto, nao o corpo), ou None."""
    return None if assunto_ok(primeira_linha(texto)) else MENSAGEM_ASSUNTO


def acima_da_tesoura(texto):
    """Texto antes da linha-tesoura do git. Sem tesoura, o texto inteiro."""
    m = TESOURA.search(texto)
    return texto[:m.start()] if m else texto


def falha_rodape(texto):
    """Ultimo paragrafo (quando ha mais de um): toda linha com ':' e Co-Authored-By da Anthropic (SG-02)."""
    paragrafos = [p for p in re.split(r"\n[ \t]*\n", texto.strip("\n")) if p.strip()]
    if len(paragrafos) < 2:
        return None
    for ln in paragrafos[-1].split("\n"):
        ln = ln.rstrip()
        if ln.startswith("#"):
            continue
        if ":" in ln and not RODAPE.fullmatch(ln):
            return MENSAGEM_RODAPE
    return None


def falhas_mensagem(texto, formato, gravada=False):
    """Falhas da mensagem, sem devolver o texto dela (V11).

    formato=False isenta so o formato do assunto (historico ate o MARCO, D5); o resto vale sempre.
    gravada=True: a mensagem ja esta no historico (ci e envio), e a sessao usa o texto gravado.
    """
    linha = primeira_linha(texto)
    falhas = []
    if linha.startswith("#"):
        falhas.append(MENSAGEM_COMENTARIO)
    if formato and not assunto_ok(linha):
        falhas.append(MENSAGEM_ASSUNTO)
    if cita_sessao(texto):
        falhas.append(MENSAGEM_SESSAO_GRAVADA if gravada else MENSAGEM_SESSAO_LOCAL)
    if tem_travessao(texto):
        falhas.append(MENSAGEM_TRAVESSAO)
    rodape = falha_rodape(texto)
    if rodape:
        falhas.append(rodape)
    return falhas


def commit_msg(caminho):
    with open(caminho, "rb") as f:
        bruto = f.read()
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        return imprime("commit-msg", 1, 0, ["mensagem nao e UTF-8"])
    return imprime("commit-msg", 1, 1, falhas_mensagem(acima_da_tesoura(texto), formato=True))


def assuntos(linhas):
    pendentes = [ln.rstrip("\n") for ln in linhas if ln.strip()]
    falhas = []
    for n, ln in enumerate(pendentes, start=1):
        if not assunto_ok(ln):
            falhas.append(f"assunto fora do formato, linha {n} do lote")
    return imprime("assuntos", len(pendentes), len(pendentes), falhas)
