"""Execucao de git em lote e formato da saida das contagens (SG-02).

Um processo git por chamada, nunca um por arquivo ou por commit (L-11).
"""
import subprocess


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
    """(hash, caminho) de todo o indice, em um unico processo git."""
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
