"""Portao de historico (SG-02): modo ci (historico inteiro, sem chave) e modo envio (pontas do pre-push)."""
import os

from portao_cifra import e_excecao, falha_caminho, falha_teto, falhas_confianca, heuristica, modo_falha
from portao_git import (ErroGit, arvore, cat_file_filtrado_bruto, conteudos, git, git_tenta, imprime,
                        pares_do_historico, separa_filtrado)
from portao_regras import CABECALHO, NOREPLY, SESSAO, TAMANHO_CABECALHO


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


def refs_e_raso():
    """Refs antes de qualquer outra leitura (SG-02, S17): replace, ref que nao chega a commit, clone raso."""
    saida = git(["for-each-ref", "--format=%(refname)%00%(objecttype)%00%(*objecttype)"]).decode("utf-8")
    refs = [ln for ln in saida.splitlines() if ln]
    falhas = []
    for ln in refs:
        nome, tipo, alvo = ln.split("\x00")
        if nome.startswith("refs/replace/"):
            falhas.append(f"refs/replace presente: {nome}")
            continue
        final = alvo if tipo == "tag" else tipo
        if final != "commit":
            falhas.append(f"ref {nome} aponta para objeto que nao e commit")
    if git(["rev-parse", "--is-shallow-repository"]).decode("ascii").strip() == "true":
        falhas.append("repositorio raso")
    return len(refs), falhas


def confere_pares(pares):
    """Modo, cabecalho, classificacao e teto de cada par (hash, caminho, modo), sem chave.

    Modo proibido vira falha antes da leitura do conteudo (submodulo nao tem blob no clone).
    Devolve (analisados, falhas, cifrados, corpos): cifrados = pares cifrados fora da excecao.
    """
    falhas, regulares = [], []
    for sha, caminho, modo in sorted(pares):
        falha = modo_falha(modo, caminho)
        if falha:
            falhas.append(falha)
        else:
            regulares.append((sha, caminho))
    hashes = sorted({s for s, _ in regulares})
    corpos = dict(zip(hashes, conteudos(hashes)))
    analisados, cifrados = 0, []
    for sha, caminho in regulares:
        cifrado = corpos[sha].startswith(CABECALHO)
        falha = falha_caminho(caminho, cifrado, rotulo=f"blob {sha[:7]} ")
        if falha is None and cifrado:
            falha = falha_teto(caminho, len(corpos[sha]) - TAMANHO_CABECALHO)
        if falha is None:
            analisados += 1
        else:
            falhas.append(falha)
        if cifrado and not e_excecao(caminho):
            cifrados.append((sha, caminho))
    return analisados, falhas, sorted(set(cifrados)), corpos


def ci():
    if not git(["rev-list", "--all"]).strip():
        print("[ci-commits] FALHOU historico vazio")
        return False
    n_ref, falhas_ref = refs_e_raso()
    ok_refs = imprime("ci-refs", n_ref, n_ref, falhas_ref)
    n, falhas_commit = verifica_commits(["--all"])
    ok_commits = imprime("ci-commits", n, n, falhas_commit)
    pares = pares_do_historico(["--all"])
    analisados, falhas_blob, _cifrados, corpos = confere_pares(pares)
    ok_blobs = imprime("ci-blobs", len(pares), analisados, falhas_blob)
    unicos = {}
    for sha, caminho, _modo in sorted(pares):
        if sha in corpos and corpos[sha].startswith(CABECALHO):
            unicos.setdefault(sha, caminho)
    linha, falhas_heu = heuristica([(c, corpos[s]) for s, c in sorted(unicos.items(), key=lambda t: t[1])])
    print(linha)
    for f in falhas_heu:
        print(f"  FALHOU {f}")
    n_conf, falhas_conf = falhas_confianca(arvore("HEAD"))
    ok_conf = imprime("ci-confianca", n_conf, n_conf - len(falhas_conf), falhas_conf)
    return ok_refs and ok_commits and ok_blobs and not falhas_heu and ok_conf


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


def envio_chave(cifrados):
    """Com a chave, todo blob cifrado do intervalo tem que decifrar (adulteracao reprova)."""
    chave = git(["rev-parse", "--git-path", "git-crypt/keys/default"]).decode("utf-8").strip()
    if not os.path.exists(chave):
        print("[envio-chave] encontrados=0 analisados=0 falharam=1")
        print("  FALHOU chave ausente: envio exige o repositorio desbloqueado")
        return False
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
            for (_s, c), corpo in zip(cifrados, separa_filtrado(saida, len(cifrados))):
                if corpo.startswith(CABECALHO):
                    falhas.append(f"{msg}: {c}")
                else:
                    analisados += 1
    return imprime("envio-chave", len(cifrados), analisados, falhas, vazia_ok=True)


def envio(texto):
    """Modo pre-push: refs, checagens de ci sobre as pontas enviadas, confianca na arvore, depois a chave."""
    locais, remotos = revs_da_entrada(texto)
    n_ref, falhas_ref = refs_e_raso()
    ok_refs = imprime("envio-refs", n_ref, n_ref, falhas_ref)
    revs = locais + (["--not", *remotos] if remotos else [])
    n, falhas_commit = verifica_commits(revs) if locais else (0, [])
    ok_commits = imprime("envio-commits", n, n, falhas_commit, vazia_ok=True)
    pares = pares_do_historico(revs) if locais else set()
    analisados, falhas_blob, cifrados, _corpos = confere_pares(pares)
    ok_blobs = imprime("envio-blobs", len(pares), analisados, falhas_blob, vazia_ok=True)
    da_arvore = set()
    for ponta in locais:
        da_arvore.update(arvore(ponta))
    n_conf, falhas_conf = falhas_confianca(sorted(da_arvore))
    ok_conf = imprime("envio-confianca", n_conf, n_conf - len(falhas_conf), falhas_conf, vazia_ok=True)
    ok_chave = envio_chave(cifrados)
    return ok_refs and ok_commits and ok_blobs and ok_conf and ok_chave
