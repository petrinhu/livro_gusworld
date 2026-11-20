"""Portao de historico sem chave (SG-02), modo ci: commits, blobs e a regra de cifra no historico inteiro."""
from portao_git import atributos, conteudos, git, imprime
from portao_regras import CABECALHO, NOREPLY, SESSAO


def ci():
    falhas_commit, n_commits = [], 0
    if not git(["rev-list", "--all"]).strip():
        print("[ci-commits] FALHOU historico vazio")
        return False
    reg = git(["log", "--all", "--format=%H%x00%ae%x00%ce%x00%B%x1e"]).decode("utf-8")
    for rec in reg.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        n_commits += 1
        h, ae, ce, corpo = rec.split("\x00", 3)
        if ae != NOREPLY or ce != NOREPLY:
            falhas_commit.append(f"commit {h[:7]}: autor ou committer fora do noreply")
        if SESSAO.search(corpo):
            falhas_commit.append(f"commit {h[:7]}: cita sessao (Claude-Session)")
    ok_commits = imprime("ci-commits", n_commits, n_commits, falhas_commit)

    pares = []
    for linha in git(["rev-list", "--all", "--objects"]).decode("utf-8").splitlines():
        sha, _, caminho = linha.partition(" ")
        pares.append((sha, caminho))
    shas = sorted({s for s, _ in pares})
    tipos = {}
    for linha in git(["cat-file", "--batch-check=%(objectname) %(objecttype)"],
                     "".join(s + "\n" for s in shas).encode()).decode("utf-8").splitlines():
        s, t = linha.split(" ")
        tipos[s] = t
    blobs = [(s, c) for s, c in pares if tipos.get(s) == "blob"]
    atr = atributos([c for _, c in blobs if c])
    corpos = dict(zip(sorted({s for s, _ in blobs}),
                      conteudos(sorted({s for s, _ in blobs}))))
    falhas_blob, analisados = [], 0
    for s, c in blobs:
        if not c:
            falhas_blob.append(f"blob {s[:7]} sem caminho")
            continue
        valor = atr.get(c, "")
        if valor == "git-crypt":
            if corpos[s].startswith(CABECALHO):
                analisados += 1
            else:
                falhas_blob.append(f"blob {s[:7]} sem cabecalho cifrado: {c}")
        elif valor == "unspecified":
            analisados += 1
        else:
            falhas_blob.append(f"blob {s[:7]} com atributo filter={valor!r}: {c}")
    ok_blobs = imprime("ci-blobs", len(blobs), analisados, falhas_blob)
    return ok_commits and ok_blobs
