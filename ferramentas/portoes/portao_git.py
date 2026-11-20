"""Execucao de git em lote e formato da saida das contagens (SG-02).

Um processo git por chamada, nunca um por arquivo ou por commit (L-11).
"""
import os
import re
import subprocess

# Ambiente limpo: sem objetos de substituicao e sem fonte de atributos alternativa (SG-02).
AMBIENTE = {k: v for k, v in os.environ.items() if k != "GIT_ATTR_SOURCE"}
AMBIENTE["GIT_NO_REPLACE_OBJECTS"] = "1"


class ErroGit(Exception):
    """Falha de comando git: o portao fecha (falha segura)."""


def git(args, entrada=b""):
    r = subprocess.run(["git", *args], input=entrada, capture_output=True, env=AMBIENTE)
    if r.returncode != 0:
        raise ErroGit(f"git {args[0]} saiu com codigo {r.returncode}")
    return r.stdout


def git_tenta(args):
    r = subprocess.run(["git", *args], capture_output=True, env=AMBIENTE)
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


# Medido (git 2.56, cat-file --batch --filters): o tamanho do cabecalho e o do blob ANTES do filtro
# (52428822 para conteudo de 52428800). Cabecalho git-crypt = 10 bytes + 12 de nonce = 22.
DIF_CIFRA = 22
INICIO_REGISTRO = re.compile(rb"[0-9a-f]{40,64} (?:[a-z]+ [0-9]+|missing)\n")


def separa_filtrado(raw, n):
    """Separa a saida de 'cat-file --batch --filters' em n conteudos, sem fatiar pelo tamanho do cabecalho.

    Para cada registro testa dois candidatos de fim: tamanho - 22 (blob cifrado decifrado) e tamanho
    (passthrough). Um candidato so vale se houver '\\n' ali e, depois dele, o cabecalho do proximo
    registro (ou o fim do fluxo). Nenhum candidato valendo = falha fechada.
    """
    saida, pos = [], 0
    for i in range(n):
        fim = raw.index(b"\n", pos)
        cab = raw[pos:fim].split()
        if len(cab) != 3 or cab[1] == b"missing":
            raise ErroGit("cabecalho inesperado do cat-file")
        tam = int(cab[2])
        ultimo = i == n - 1
        for cand in (tam - DIF_CIFRA, tam):
            if cand < 0:
                continue
            p = fim + 1 + cand
            if raw[p:p + 1] != b"\n":
                continue
            if (p + 1 == len(raw)) if ultimo else INICIO_REGISTRO.match(raw, p + 1):
                break
        else:
            raise ErroGit("saida do cat-file com filtro nao confere com o cabecalho")
        saida.append(raw[fim + 1:p])
        pos = p + 1
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
    return separa_filtrado(raw, len(pares))


def cat_file_filtrado_bruto(pares):
    """Como conteudos_filtrados, mas devolve (rc, saida, stderr) sem falhar: o chamador decide o veredito."""
    entrada = "".join(f"{sha} {c}\n" for sha, c in pares).encode("utf-8")
    r = subprocess.run(["git", "cat-file", "--batch", "--filters"], input=entrada,
                       capture_output=True, env=AMBIENTE)
    return r.returncode, r.stdout, r.stderr


def indice():
    """(modo, hash, caminho) de todo o indice, em um unico processo git."""
    itens = []
    for reg in git(["ls-files", "-s", "-z"]).split(b"\0"):
        if not reg:
            continue
        meta, _, caminho = reg.partition(b"\t")
        modo, sha, _estagio = meta.split(b" ")
        itens.append((modo.decode("ascii"), sha.decode("ascii"), caminho.decode("utf-8")))
    return itens


def arvore(rev):
    """(hash, caminho) de cada blob da arvore de rev, em um unico processo git."""
    pares = []
    for reg in git(["ls-tree", "-r", "-z", "--full-tree", rev]).split(b"\0"):
        if not reg:
            continue
        meta, _, caminho = reg.partition(b"\t")
        _modo, tipo, sha = meta.split(b" ")
        if tipo == b"blob":
            pares.append((sha.decode("ascii"), caminho.decode("utf-8")))
    return pares


def pares_do_historico(revs):
    """(hash, caminho, modo) de todo blob introduzido em revs, em um unico processo git (SG-02, 5.4).

    Diferente de 'rev-list --objects', que lista cada blob so uma vez: o mesmo blob em dois caminhos
    gera dois pares, e cada caminho e julgado.
    """
    raw = git(["log", *revs, "--root", "-m", "--no-renames", "--raw", "-z", "--no-abbrev",
               "--format=%x01%H"])
    toks = raw.split(b"\0")
    pares, i = set(), 0
    while i < len(toks):
        t = toks[i].lstrip(b"\n")
        if t.startswith(b"\x01"):
            i += 1
            continue
        if t.startswith(b":"):
            meta = t[1:].split(b" ")
            if len(meta) != 5 or i + 1 >= len(toks):
                raise ErroGit("registro raw inesperado")
            modo, sha, estado = meta[1].decode("ascii"), meta[3].decode("ascii"), meta[4].decode("ascii")
            caminho = toks[i + 1].decode("utf-8")
            i += 2
            if not estado.startswith("D"):
                pares.add((sha, caminho, modo))
            continue
        if t == b"":
            i += 1
            continue
        raise ErroGit("token inesperado no log raw")
    return pares


def imprime(nome, encontrados, analisados, falhas, vazia_ok=False):
    """Linha de contagem e falhas. Zero so vale quando vazia_ok (envio sem commit novo, sem blob)."""
    print(f"[{nome}] encontrados={encontrados} analisados={analisados} falharam={len(falhas)}")
    if encontrados == 0 and not vazia_ok:
        print("  FALHOU varredura vazia: piso de verificacao zero (L-36)")
    for f in falhas:
        print(f"  FALHOU {f}")
    return (encontrados > 0 or vazia_ok) and analisados == encontrados and not falhas
