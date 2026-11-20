"""Portao de historico (SG-02): modo ci (historico inteiro, sem chave) e modo envio (pontas do pre-push)."""
import os

from portao_git import (ErroGit, atributos, cat_file_filtrado_bruto, conteudos, git, git_tenta, imprime,
                        separa_batch)
from portao_regras import CABECALHO, NOREPLY, SESSAO


def eh_zero(sha):
    return not sha or set(sha) == {"0"}


def verifica_commits(revs):
    """Autor, committer e sessao de cada commit de revs (um processo git). Devolve (n, falhas)."""
    falhas, n = [], 0
    reg = git(["log", *revs, "--format=%H%x00%ae%x00%ce%x00%B%x1e"]).decode("utf-8")
    for rec in reg.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        n += 1
        h, ae, ce, corpo = rec.split("\x00", 3)
        if ae != NOREPLY or ce != NOREPLY:
            falhas.append(f"commit {h[:7]}: autor ou committer fora do noreply")
        if SESSAO.search(corpo):
            falhas.append(f"commit {h[:7]}: cita sessao (Claude-Session)")
    return n, falhas


def blobs_do_intervalo(revs):
    """Pares (hash, caminho) dos blobs introduzidos em revs (dois processos git no total)."""
    pares = []
    for linha in git(["rev-list", *revs, "--objects"]).decode("utf-8").splitlines():
        sha, _, caminho = linha.partition(" ")
        pares.append((sha, caminho))
    shas = sorted({s for s, _ in pares})
    tipos = {}
    for linha in git(["cat-file", "--batch-check=%(objectname) %(objecttype)"],
                     "".join(s + "\n" for s in shas).encode()).decode("utf-8").splitlines():
        s, t = linha.split(" ")
        tipos[s] = t
    return [(s, c) for s, c in pares if tipos.get(s) == "blob"]


def confere_blobs(blobs):
    """Cabecalho cifrado nos caminhos git-crypt. Devolve (analisados, falhas)."""
    falhas, analisados = [], 0
    atr = atributos([c for _, c in blobs if c])
    hashes = sorted({s for s, _ in blobs})
    corpos = dict(zip(hashes, conteudos(hashes)))
    for s, c in blobs:
        if not c:
            falhas.append(f"blob {s[:7]} sem caminho")
            continue
        valor = atr.get(c, "")
        if valor == "git-crypt":
            if corpos[s].startswith(CABECALHO):
                analisados += 1
            else:
                falhas.append(f"blob {s[:7]} sem cabecalho cifrado: {c}")
        elif valor == "unspecified":
            analisados += 1
        else:
            falhas.append(f"blob {s[:7]} com atributo filter={valor!r}: {c}")
    return analisados, falhas


def ci():
    if not git(["rev-list", "--all"]).strip():
        print("[ci-commits] FALHOU historico vazio")
        return False
    n, falhas_commit = verifica_commits(["--all"])
    ok_commits = imprime("ci-commits", n, n, falhas_commit)
    blobs = blobs_do_intervalo(["--all"])
    analisados, falhas_blob = confere_blobs(blobs)
    ok_blobs = imprime("ci-blobs", len(blobs), analisados, falhas_blob)
    return ok_commits and ok_blobs


def revs_da_entrada(texto):
    """Pontas locais a enviar e revisoes remotas ja conhecidas, a partir da entrada do pre-push."""
    locais, remotos = [], []
    for ln in texto.splitlines():
        if not ln.strip():
            continue
        partes = ln.split()
        if len(partes) != 4:
            raise ErroGit("linha inesperada na entrada do pre-push")
        _ref_l, sha_l, _ref_r, sha_r = partes
        if not eh_zero(sha_l):
            locais.append(sha_l)
        if not eh_zero(sha_r) and git_tenta(["cat-file", "-e", sha_r + "^{commit}"])[0] == 0:
            remotos.append(sha_r)
    return locais, remotos


def envio_chave(blobs):
    """Com a chave, todo blob cifrado do intervalo tem que decifrar (adulteracao reprova)."""
    chave = git(["rev-parse", "--git-path", "git-crypt/keys/default"]).decode("utf-8").strip()
    if not os.path.exists(chave):
        print("[envio-chave] encontrados=0 analisados=0 falharam=1")
        print("  FALHOU chave ausente: envio exige o repositorio desbloqueado")
        return False
    atr = atributos([c for _, c in blobs if c])
    cifrados = sorted({(s, c) for s, c in blobs if c and atr.get(c) == "git-crypt"})
    falhas, analisados = [], 0
    if cifrados:
        # Medido (git-crypt 0.8, git 2.56): blob com cabecalho e corpo adulterado sai do filtro com rc 0 e
        # com o cabecalho ainda na frente. Veredito: rc diferente de 0, stderr com "tampered", ou conteudo
        # decifrado que ainda comeca com o cabecalho. Blob legitimo decifra sem cabecalho (TA8a).
        rc, saida, err = cat_file_filtrado_bruto(cifrados)
        msg = "blob cifrado adulterado ou ilegivel com a chave"
        if rc != 0 or b"tampered" in err.lower():
            falhas.append(f"{msg} ({len(cifrados)} candidatos)")
        else:
            for (_s, c), corpo in zip(cifrados, separa_batch(saida, len(cifrados))):
                if corpo.startswith(CABECALHO):
                    falhas.append(f"{msg}: {c}")
                else:
                    analisados += 1
    return imprime("envio-chave", len(cifrados), analisados, falhas, vazia_ok=True)


def envio(texto):
    """Modo pre-push: checagens de ci sobre as pontas enviadas, depois a chave sobre o intervalo."""
    locais, remotos = revs_da_entrada(texto)
    revs = locais + (["--not", *remotos] if remotos else [])
    n, falhas_commit = verifica_commits(revs) if locais else (0, [])
    ok_commits = imprime("envio-commits", n, n, falhas_commit, vazia_ok=True)
    blobs = blobs_do_intervalo(revs) if locais else []
    analisados, falhas_blob = confere_blobs(blobs)
    ok_blobs = imprime("envio-blobs", len(blobs), analisados, falhas_blob, vazia_ok=True)
    ok_chave = envio_chave(blobs)
    return ok_commits and ok_blobs and ok_chave
