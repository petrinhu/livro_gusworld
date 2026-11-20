"""Soma do que sai em claro (SG-02e). Envio: teto sobre o que ainda nao saiu. CI: orcamento desde a linha de base.

Fecha o acumulo em varios commits (CRITICO-1) e em varias mensagens ou tags (CRITICO-2) da re-SG-03c, que os
tetos por arvore e por commit nao alcancam. Uma linha informativa por modo; as falhas entram nas linhas atuais.
"""
from portao_cifra import e_excecao
from portao_git import git, git_tenta, pares_do_historico, tamanhos
from portao_regras import AMOSTRA, LINHA_DE_BASE, ORCAMENTO, TETO_ENVIO

ROTULOS = {"claro": "volume em claro", "amostra": "amostra", "objetos": "objetos de commit e tag"}


def base_presente():
    """A LINHA_DE_BASE existe aqui como commit? Sem ela, nada fica de fora (falha fechada)."""
    return git_tenta(["cat-file", "-e", LINHA_DE_BASE + "^{commit}"])[0] == 0


def intervalo(positivos, negativos):
    """Revisoes de positivos, sem negativos e sem o historico ate a LINHA_DE_BASE quando ela existe."""
    fora = [*negativos, *([LINHA_DE_BASE] if base_presente() else [])]
    return [*positivos, "--not", *fora] if fora else list(positivos)


def medida(revs, tags):
    """Bytes de blobs em claro unicos introduzidos em revs, os da amostra, e objetos commit de revs mais tags."""
    claros, amostra = set(), set()
    for sha, caminho, _modo in pares_do_historico(revs):
        if e_excecao(caminho):
            claros.add(sha)
            if AMOSTRA.fullmatch(caminho):
                amostra.add(sha)
    commits = set(git(["rev-list", *revs]).decode("ascii").split())
    tam = tamanhos(sorted(claros | commits | set(tags)))
    return {"claro": sum(tam[s] for s in claros), "amostra": sum(tam[s] for s in amostra),
            "objetos": sum(tam[s] for s in commits | set(tags))}


def falhas_orcamento(modo, positivos, negativos, tags):
    """(falhas de blob, falhas de objeto) contra o teto do envio ou o orcamento do ci; imprime a linha do modo."""
    tetos, onde = (TETO_ENVIO, "do teto do envio") if modo == "envio" else (ORCAMENTO, "do orcamento desde a linha de base")
    usado = medida(intervalo(positivos, negativos), tags) if positivos else {k: 0 for k in tetos}
    base = LINHA_DE_BASE[:7] if base_presente() else "ausente"
    print(f"[{modo}-orcamento] base={base} " + " ".join(f"{k}={usado[k]}/{tetos[k]}" for k in tetos))
    falhas = {k: f"{ROTULOS[k]} acima {onde}" for k in tetos if usado[k] > tetos[k]}
    return [falhas[k] for k in ("claro", "amostra") if k in falhas], [falhas[k] for k in ("objetos",) if k in falhas]
