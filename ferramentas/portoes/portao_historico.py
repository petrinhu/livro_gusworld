"""Portao de historico (SG-02): modo ci (historico inteiro, sem chave) e modo envio (pontas do pre-push)."""
import os
import re

from portao_cifra import (e_binario, e_excecao, falha_amostra, falha_caminho, falha_claro, falha_teto, falhas_confianca,
                          falhas_volume, heuristica, modo_falha)
from portao_git import (ErroGit, arvore, cat_file_filtrado_bruto, conteudos, falhou, git, git_tenta, imprime,
                        pares_do_historico, separa_filtrado, tamanhos)
from portao_mensagem import cita_sessao, falha_assunto, falhas_mensagem, tem_travessao
from portao_regras import CABECALHO, MARCO, MENSAGEM_MAX, NOREPLY, OBJETO_MAX, TAMANHO_CABECALHO
from portao_travessao import falha_travessao


def eh_zero(sha):
    return not sha or set(sha) == {"0"}


def marco_existe():
    """O MARCO existe neste repositorio? Sem ele (repositorio de teste), o formato vale para todo commit."""
    return git_tenta(["cat-file", "-e", MARCO + "^{commit}"])[0] == 0


def verifica_mensagens(revs, revs_formato):
    """Autor, committer, sessao, comentario, travessao, teto da mensagem e do objeto de cada commit de revs;
    formato do assunto so nos commits de revs_formato (o historico ate o MARCO fica isento, D5). Tres processos
    git no total.

    Devolve (n, falhas, n_formato, analisados_formato, falhas_formato).
    """
    falhas, falhas_fmt, n, analisados = [], [], 0, 0
    reg = git(["log", *revs, "--format=%H%x00%ae%x00%ce%x00%B%x1e"]).decode("utf-8")
    formato = set(git(["rev-list", *revs_formato]).decode("ascii").split())
    registros = [rec.strip("\n").split("\x00", 3) for rec in reg.split("\x1e") if rec.strip("\n")]
    tam = tamanhos(sorted({r[0] for r in registros}))
    for h, ae, ce, corpo in registros:
        n += 1
        rotulo = f"commit {h[:7]}"
        if ae != NOREPLY or ce != NOREPLY:
            falhas.append(f"{rotulo}: autor ou committer fora do noreply")
        if tam[h] > OBJETO_MAX:
            falhas.append(f"{rotulo}: objeto commit acima do teto de bytes")
        falhas.extend(f"{rotulo}: {f}" for f in falhas_mensagem(corpo, formato=False, gravada=True))
        if h in formato:
            analisados += 1
            falha = falha_assunto(corpo)
            if falha:
                falhas_fmt.append(f"{rotulo}: {falha}")
    if analisados != len(formato):
        falhas_fmt.append("contagem do formato diverge do historico (rev-list e log)")
    return n, falhas, len(formato), analisados, falhas_fmt


TAGGER = re.compile(r"<([^<>]*)>")


def campos_tag(bruto):
    """(tipo do alvo, e-mail do tagger, mensagem em bytes) de um objeto tag cru (SG-02d, A2)."""
    cabecalho, _, mensagem = bruto.partition(b"\n\n")
    tipo, mail = "", ""
    for ln in cabecalho.decode("utf-8", "replace").split("\n"):
        if ln.startswith("type "):
            tipo = ln[5:]
        elif ln.startswith("tagger "):
            m = TAGGER.search(ln)
            mail = m.group(1) if m else ""
    return tipo, mail, mensagem


def objetos_tag(alvos):
    """Objetos tag a julgar (SG-02d, A2). alvos None (ci): toda ref de tag anotada. Envio: os objetos
    enviados cujo tipo e tag, com ou sem ref local. Um processo git."""
    if alvos is None:
        saida = git(["for-each-ref", "refs/tags", "--format=%(objecttype) %(objectname)"])
    elif alvos:
        entrada = "".join(f"{o}\n" for o in sorted(alvos)).encode("ascii")
        saida = git(["cat-file", "--batch-check=%(objecttype) %(objectname)"], entrada)
    else:
        return []
    pares = [ln.split(" ") for ln in saida.decode("ascii").splitlines() if ln]
    return sorted({h for t, h in pares if t == "tag"})


def verifica_tags(alvos):
    """Tags anotadas, pelo objeto (SG-02, S52; SG-02d, A2): alvo direto commit (tag aninhada reprova), tagger
    noreply, mensagem sem sessao, sem travessao e no teto, objeto no teto. Ate tres processos git.

    alvos: None julga todas (ci); conjunto de objetos enviados (envio). Devolve (n, falhas).
    """
    objetos = objetos_tag(alvos)
    tam = tamanhos(objetos)
    falhas = []
    for h, bruto in zip(objetos, conteudos(objetos)):
        tipo, mail, mensagem = campos_tag(bruto)
        texto = mensagem.decode("utf-8", "replace")
        rotulo = f"tag {h[:7]}"
        if tipo != "commit":
            falhas.append(f"{rotulo}: tag aninhada ou de alvo que nao e commit")
        if mail != NOREPLY:
            falhas.append(f"{rotulo}: tagger fora do noreply")
        if cita_sessao(texto):
            falhas.append(f"{rotulo}: cita sessao (Claude-Session)")
        if tem_travessao(texto):
            falhas.append(f"{rotulo}: travessao na mensagem")
        if len(mensagem) > MENSAGEM_MAX:
            falhas.append(f"{rotulo}: mensagem acima do teto de bytes")
        if tam[h] > OBJETO_MAX:
            falhas.append(f"{rotulo}: objeto tag acima do teto de bytes")
    return len(objetos), falhas


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


def falha_texto_claro(caminho, corpo):
    """Blob em claro de excecao: UTF-8 e travessao, a mesma regra do pre-commit (SG-02, S40)."""
    try:
        texto = corpo.decode("utf-8")
    except UnicodeDecodeError:
        return f"nao e UTF-8, nao analisado: {caminho}"
    return falha_travessao(caminho, texto)


def falha_decifrado(caminho, corpo):
    """Conteudo decifrado com cabecalho ausente: binario pelo teto; texto por UTF-8 e travessao (SG-02, OS 5.3)."""
    if e_binario(caminho):
        return falha_teto(caminho, len(corpo))
    return falha_texto_claro(caminho, corpo)


def confere_pares(pares):
    """Modo, cabecalho, classificacao, teto e (em claro, na excecao) travessao de cada par (hash, caminho, modo).

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
        if falha is None:
            falha = falha_amostra(caminho, len(corpos[sha]))
        if falha is None and not cifrado:
            falha = falha_claro(caminho, len(corpos[sha]))
        if falha is None and cifrado:
            falha = falha_teto(caminho, len(corpos[sha]) - TAMANHO_CABECALHO)
        if falha is None and not cifrado and e_excecao(caminho):
            falha = falha_texto_claro(caminho, corpos[sha])
        if falha is None:
            analisados += 1
        else:
            falhas.append(falha)
        if cifrado and not e_excecao(caminho):
            cifrados.append((sha, caminho))
    return analisados, falhas, sorted(set(cifrados)), corpos


def ci():
    if not git(["rev-list", "--all"]).strip():
        print("[ci-commits] encontrados=0 analisados=0 falharam=1")
        falhou("historico vazio")
        return False
    n_ref, falhas_ref = refs_e_raso()
    ok_refs = imprime("ci-refs", n_ref, n_ref, falhas_ref)
    formato = ["--all", "--not", MARCO] if marco_existe() else ["--all"]
    n, falhas_commit, n_fmt, vistos, falhas_fmt = verifica_mensagens(["--all"], formato)
    ok_commits = imprime("ci-commits", n, n, falhas_commit)
    ok_assuntos = imprime("ci-assuntos", n_fmt, vistos, falhas_fmt, vazia_ok=True)
    pares = pares_do_historico(["--all"])
    analisados, falhas_blob, _cifrados, corpos = confere_pares(pares)
    da_head = arvore("HEAD")
    falhas_blob += falhas_volume(da_head, tamanhos(sorted({s for s, _ in da_head})))
    ok_blobs = imprime("ci-blobs", len(pares), analisados, falhas_blob)
    unicos = {}
    for sha, caminho, _modo in sorted(pares):
        if sha in corpos and corpos[sha].startswith(CABECALHO):
            unicos.setdefault(sha, caminho)
    linha, falhas_heu = heuristica([(c, corpos[s]) for s, c in sorted(unicos.items(), key=lambda t: t[1])])
    print(linha)
    for f in falhas_heu:
        falhou(f)
    n_conf, falhas_conf = falhas_confianca(da_head)
    ok_conf = imprime("ci-confianca", n_conf, n_conf - len(falhas_conf), falhas_conf)
    n_tag, falhas_tag = verifica_tags(None)
    ok_tags = imprime("ci-tags", n_tag, n_tag, falhas_tag, vazia_ok=True)
    return all([ok_refs, ok_commits, ok_assuntos, ok_blobs, not falhas_heu, ok_conf, ok_tags])


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
        falhou("chave ausente: envio exige o repositorio desbloqueado")
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
                    continue
                falha = falha_decifrado(c, corpo)
                if falha:
                    falhas.append(falha)
                else:
                    analisados += 1
    return imprime("envio-chave", len(cifrados), analisados, falhas, vazia_ok=True)


def envio(texto):
    """Modo pre-push: refs, checagens de ci sobre as pontas enviadas, confianca na arvore, depois a chave."""
    locais, remotos = revs_da_entrada(texto)
    n_ref, falhas_ref = refs_e_raso()
    ok_refs = imprime("envio-refs", n_ref, n_ref, falhas_ref)
    revs = locais + (["--not", *remotos] if remotos else [])
    n, falhas_commit, n_fmt, vistos, falhas_fmt = 0, [], 0, 0, []
    if locais:
        formato = (locais + ["--not", *remotos, MARCO]) if marco_existe() else revs
        n, falhas_commit, n_fmt, vistos, falhas_fmt = verifica_mensagens(revs, formato)
    ok_commits = imprime("envio-commits", n, n, falhas_commit, vazia_ok=True)
    ok_assuntos = imprime("envio-assuntos", n_fmt, vistos, falhas_fmt, vazia_ok=True)
    pares = pares_do_historico(revs) if locais else set()
    analisados, falhas_blob, cifrados, _corpos = confere_pares(pares)
    arvores = [arvore(ponta) for ponta in locais]
    tam = tamanhos(sorted({s for pares_ponta in arvores for s, _ in pares_ponta}))
    for pares_ponta in arvores:
        falhas_blob += falhas_volume(pares_ponta, tam)
    ok_blobs = imprime("envio-blobs", len(pares), analisados, falhas_blob, vazia_ok=True)
    da_arvore = set()
    for pares_ponta in arvores:
        da_arvore.update(pares_ponta)
    n_conf, falhas_conf = falhas_confianca(sorted(da_arvore))
    ok_conf = imprime("envio-confianca", n_conf, n_conf - len(falhas_conf), falhas_conf, vazia_ok=True)
    n_tag, falhas_tag = verifica_tags(set(locais))
    ok_tags = imprime("envio-tags", n_tag, n_tag, falhas_tag, vazia_ok=True)
    ok_chave = envio_chave(cifrados)
    return all([ok_refs, ok_commits, ok_assuntos, ok_blobs, ok_conf, ok_tags, ok_chave])
