"""Portao de mensagem e autor (SG-02): assunto, ID, sessao, comentario no editor e identidade noreply."""
import re

from portao_git import git_tenta, imprime
from portao_regras import ASSUNTO, ASSUNTO_MAX, NOREPLY, SESSAO


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


def assunto_e_corpo(texto):
    """Assunto e corpo, ignorando as linhas de comentario que o git coloca no editor."""
    linhas = [ln for ln in texto.split("\n") if not ln.startswith("#")]
    assunto = next((ln for ln in linhas if ln.strip()), "")
    return assunto, "\n".join(linhas)


def falhas_mensagem(texto):
    """Falhas da mensagem, sem devolver o texto dela (V11)."""
    assunto, corpo = assunto_e_corpo(texto)
    falhas = []
    if not (ASSUNTO.match(assunto) and len(assunto) <= ASSUNTO_MAX):
        falhas.append("assunto fora de 'tipo(escopo)?: descricao (ID)' ou com mais de 72 caracteres")
    if SESSAO.search(corpo):
        falhas.append("linha de sessao (Claude-Session) proibida na mensagem")
    return falhas


def commit_msg(caminho):
    with open(caminho, "rb") as f:
        bruto = f.read()
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        return imprime("commit-msg", 1, 0, ["mensagem nao e UTF-8"])
    return imprime("commit-msg", 1, 1, falhas_mensagem(texto))


def assuntos(linhas):
    pendentes = [ln.rstrip("\n") for ln in linhas if ln.strip()]
    falhas = []
    for n, ln in enumerate(pendentes, start=1):
        if not (ASSUNTO.match(ln) and len(ln) <= ASSUNTO_MAX):
            falhas.append(f"assunto fora do formato, linha {n} do lote")
    return imprime("assuntos", len(pendentes), len(pendentes), falhas)
