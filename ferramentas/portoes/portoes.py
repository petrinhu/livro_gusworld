#!/usr/bin/env python3
"""Portoes de sigilo do livro (SG-02). Codigo publico: sem termo da obra, sem caminho de maquina.

Modos:
  pre-commit          (a) cifra: todo arquivo do indice fora da excecao tem cabecalho cifrado e filtro git-crypt;
                      (b) travessao: proibido em todo arquivo decifrado, salvo abrindo fala nos textos;
                      (c) autor: autor e committer sao o noreply.
  commit-msg ARQUIVO  formato Conventional Commits, ID de item entre parenteses, sem linha de sessao.
  assuntos            mesma regra de commit-msg, em lote, lendo um assunto por linha de stdin.
  ci                  sem chave: todo blob do historico fora da excecao tem cabecalho cifrado;
                      todo commit tem autor e committer noreply e nenhum cita sessao.

Saida: encontrados/analisados/falharam por verificacao, com caminho, hash ou numero de linha.
Nunca imprime conteudo do livro nem o texto de uma mensagem (V11).
Codigo de saida 0 so quando tudo passou. Qualquer falha, varredura vazia ou contagem divergente sai com 1.
"""
import re
import subprocess
import sys

NOREPLY = "238845971+petrinhu@users.noreply.github.com"
CABECALHO = b"\x00GITCRYPT\x00"
TRAVESSOES = ("\u2014", "\u2013")
FALA = re.compile(r"^(livro-[^/]+/texto/|ferramentas/montagem/amostra/texto/)")
TIPOS = "feat|fix|refactor|chore|docs|test|perf|style|revert"
ASSUNTO = re.compile(
    r"^(?:%s)(?:\([^()\n]+\))?!?: \S.* \((?:[A-Z][A-Z0-9]{0,7}-[A-Za-z0-9]{1,8}|F[0-9]+\.[0-9]+)\)$"
    % TIPOS
)
ASSUNTO_MAX = 72
SESSAO = re.compile(r"claude-session", re.IGNORECASE)
FILTRO_EXIGIDO = (
    ("filter.git-crypt.clean", None),
    ("filter.git-crypt.smudge", None),
    ("filter.git-crypt.required", "true"),
)


class ErroGit(Exception):
    """Falha de comando git: o portao fecha (falha segura)."""


def git(args, entrada=b""):
    r = subprocess.run(["git", *args], input=entrada, capture_output=True)
    if r.returncode != 0:
        raise ErroGit(f"git {args[0]} saiu com codigo {r.returncode}")
    return r.stdout


def git_tenta(args):
    r = subprocess.run(["git", *args], capture_output=True)
    return r.returncode, r.stdout


def separa_batch(raw, n):
    """Separa a saida de 'git cat-file --batch' em n conteudos."""
    saida, pos = [], 0
    for _ in range(n):
        fim = raw.index(b"\n", pos)
        cab = raw[pos:fim].split()
        if len(cab) != 3 or cab[1] == b"missing":
            raise ErroGit("cabecalho inesperado do cat-file")
        tam = int(cab[2])
        saida.append(raw[fim + 1: fim + 1 + tam])
        pos = fim + 1 + tam + 1
    return saida


def conteudos(objetos):
    """Conteudo bruto de cada hash de blob, em um unico processo git."""
    if not objetos:
        return []
    raw = git(["cat-file", "--batch"], "".join(o + "\n" for o in objetos).encode())
    return separa_batch(raw, len(objetos))


def conteudos_filtrados(pares):
    """Conteudo decifrado (filtros aplicados) de pares (hash, caminho), em um unico processo git."""
    if not pares:
        return []
    entrada = "".join(f"{sha} {c}\n" for sha, c in pares).encode("utf-8")
    raw = git(["cat-file", "--batch", "--filters"], entrada)
    return separa_batch(raw, len(pares))


def atributos(caminhos):
    """Atributo filter de cada caminho, lido do indice, em um unico processo git."""
    unicos = sorted(set(caminhos))
    if not unicos:
        return {}
    entrada = b"".join(c.encode("utf-8") + b"\0" for c in unicos)
    partes = git(["check-attr", "--cached", "-z", "--stdin", "filter"], entrada).split(b"\0")
    if len(partes) != 3 * len(unicos) + 1:
        raise ErroGit("saida inesperada do check-attr")
    res = {}
    for i in range(0, 3 * len(unicos), 3):
        res[partes[i].decode("utf-8")] = partes[i + 2].decode("utf-8")
    return res


def indice():
    """(modo, hash, caminho) de todo o indice, em um unico processo git."""
    itens = []
    for reg in git(["ls-files", "-s", "-z"]).split(b"\0"):
        if not reg:
            continue
        meta, _, caminho = reg.partition(b"\t")
        _modo, sha, _estagio = meta.split(b" ")
        itens.append((sha.decode("ascii"), caminho.decode("utf-8")))
    return itens


def imprime(nome, encontrados, analisados, falhas):
    print(f"[{nome}] encontrados={encontrados} analisados={analisados} falharam={len(falhas)}")
    if encontrados == 0:
        print("  FALHOU varredura vazia: piso de verificacao zero (L-36)")
    for f in falhas:
        print(f"  FALHOU {f}")
    return encontrados > 0 and analisados == encontrados and not falhas


def portao_cifra(itens):
    falhas, analisados, cifrados = [], 0, 0
    for chave, valor_exigido in FILTRO_EXIGIDO:
        rc, val = git_tenta(["config", "--get", chave])
        valor = val.decode("utf-8").strip() if rc == 0 else ""
        if not valor or (valor_exigido is not None and valor != valor_exigido):
            falhas.append(f"filtro sem configuracao local: {chave}")
    atr = atributos([c for _, c in itens])
    corpos = conteudos([sha for sha, _ in itens])
    for (_sha, caminho), corpo in zip(itens, corpos):
        valor = atr.get(caminho, "")
        if valor == "git-crypt":
            cifrados += 1
            if corpo.startswith(CABECALHO):
                analisados += 1
            else:
                falhas.append(f"sem cabecalho cifrado no indice: {caminho}")
        elif valor == "unspecified":
            analisados += 1  # excecao declarada com !filter no .gitattributes
        else:
            falhas.append(f"atributo filter={valor!r}, esperado git-crypt ou excecao: {caminho}")
    if cifrados == 0:
        falhas.append("nenhum arquivo cifrado no indice")
    return analisados, falhas


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
            falhas.append(f"ainda cifrado apos o filtro (chave ausente ou filtro inativo): {caminho}")
            continue
        try:
            texto = corpo.decode("utf-8")
        except UnicodeDecodeError:
            falhas.append(f"nao e UTF-8, nao analisado: {caminho}")
            continue
        analisados += 1
        n = travessao_fora_de_lugar(texto, bool(FALA.match(caminho)))
        if n:
            falhas.append(f"travessao fora de inicio de fala, linha {n}: {caminho}")
    return analisados, falhas


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


def pre_commit():
    itens = indice()
    res = [
        imprime("cifra", len(itens), *portao_cifra(itens)),
        imprime("travessao", len(itens), *portao_travessao(itens)),
        imprime("autor", 2, *portao_autor()),
    ]
    return all(res)


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


def main(argv):
    modo = argv[1] if len(argv) > 1 else ""
    try:
        if modo == "pre-commit" and len(argv) == 2:
            ok = pre_commit()
        elif modo == "commit-msg" and len(argv) == 3:
            ok = commit_msg(argv[2])
        elif modo == "assuntos" and len(argv) == 2:
            ok = assuntos(sys.stdin)
        elif modo == "ci" and len(argv) == 2:
            ok = ci()
        else:
            print("uso: portoes.py pre-commit | commit-msg ARQUIVO | assuntos | ci", file=sys.stderr)
            return 2
    except (ErroGit, OSError, ValueError, UnicodeDecodeError) as e:
        print(f"ERRO (portao fecha por seguranca): {e}")
        return 1
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
