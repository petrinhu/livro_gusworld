"""Historico de teste por fast-import, num processo so (SG-02e). Uso: gera_historico.py TIPO ARG PAI [REF].

TIPO e ARG: claro N,T (N commits; cada um cria um arquivo em claro de T bytes e apaga o anterior); amostra N,T
(reescreve c01.md); mensagem N,T (commit vazio com corpo de T letras); tag N,T (tag anotada sobre PAI);
onda T1,T2,... (um commit por tamanho, reescrevendo ate dez arquivos de no maximo 12000 bytes); claros T1,T2,...
e amostras T1,T2,... (um commit por tamanho); renova REGRAS (troca a LINHA_DE_BASE de REGRAS pelo PAI).
REF padrao: refs/heads/main. So texto generico, sem travessao. Saida: fluxo de fast-import.
"""
import re
import sys

AUTOR = b"Teste <238845971+petrinhu@users.noreply.github.com> 1700000000 -0300"


def bloco(dado):
    return b"data %d\n" % len(dado) + dado + b"\n"


def texto(rotulo, n):
    cab = ("# %s\n" % rotulo).encode("ascii")
    return (cab + b"x = 1\n" * (n // 6 + 1))[:n]


def arquivo(caminho, dado):
    return b"M 100644 inline " + caminho.encode("ascii") + b"\n" + bloco(dado)


def commits(pai, ref, itens):
    """itens: (mensagem, mudancas). O primeiro commit parte de PAI; os outros seguem no mesmo ramo."""
    saida = []
    for i, (msg, mud) in enumerate(itens):
        origem = b"from " + pai + b"\n" if i == 0 else b""
        saida.append(b"commit " + ref + b"\ncommitter " + AUTOR + b"\n" + bloco(msg.encode("ascii")) + origem + mud)
    return saida


def girando(pasta, tamanhos, sal):
    itens = []
    for i, t in enumerate(tamanhos):
        apaga = b"D %s/p%d.py\n" % (pasta.encode("ascii"), i - 1) if i else b""
        itens.append(("feat: parte %d (SG-02)" % i, apaga + arquivo("%s/p%d.py" % (pasta, i), texto("p %d %s" % (i, sal), t))))
    return itens


def amostras(tamanhos, sal):
    c01 = "ferramentas/montagem/amostra/texto/c01.md"
    return [("feat: amostra %d (SG-02)" % i, arquivo(c01, texto("a %d %s" % (i, sal), t))) for i, t in enumerate(tamanhos)]


def onda(tamanhos, sal):
    itens, rot = [], 0
    for i, t in enumerate(tamanhos):
        mud = b""
        while t > 0:
            p = min(t, 12000)
            mud += arquivo("ferramentas/onda/f%d.py" % (rot % 10), texto("o %d %d %s" % (i, rot, sal), p))
            t, rot = t - p, rot + 1
        itens.append(("feat: avanca a onda %d (SG-02)\n\n%s\n" % (i, "corpo de teste " * 20), mud))
    return itens


def renova(regras, pai):
    novo, k = re.subn(r'^LINHA_DE_BASE = "[0-9a-f]{40}"', 'LINHA_DE_BASE = "%s"' % pai, regras, flags=re.M)
    mud = arquivo("ferramentas/portoes/portao_regras.py", novo.encode("utf-8")) if k == 1 else b""
    return [("chore: renova a linha de base do orcamento (SG-02)", mud)]


def main(tipo, arg, pai, ref):
    sal = pai[:7].decode("ascii")
    lista = [int(x) for x in arg.split(",")] if tipo != "renova" else []
    n_t = lista[:2] if tipo in ("claro", "amostra", "mensagem", "tag") else None
    if tipo == "tag":
        return [b"tag v0-t%d\nfrom %s\ntagger %s\n" % (i, pai, AUTOR) + bloco(b"v0 t%d\n\n%s\n" % (i, b"a" * n_t[1]))
                for i in range(n_t[0])]
    if tipo == "claro":
        itens = girando("ferramentas/acum", [n_t[1]] * n_t[0], sal)
    elif tipo == "claros":
        itens = girando("ferramentas/acum", lista, sal)
    elif tipo == "amostra":
        itens = amostras([n_t[1]] * n_t[0], sal)
    elif tipo == "amostras":
        itens = amostras(lista, sal)
    elif tipo == "mensagem":
        itens = [("feat: nota %d (SG-02)\n\n%s\n" % (i, "a" * n_t[1]), b"") for i in range(n_t[0])]
    elif tipo == "onda":
        itens = onda(lista, sal)
    elif tipo == "renova":
        itens = renova(open(arg, encoding="utf-8").read(), pai.decode("ascii"))
    else:
        raise SystemExit("tipo desconhecido: " + tipo)
    return commits(pai, ref, itens)


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        raise SystemExit("uso: gera_historico.py TIPO ARG PAI [REF]")
    ref = (sys.argv[4] if len(sys.argv) == 5 else "refs/heads/main").encode("ascii")
    sys.stdout.buffer.write(b"".join(main(sys.argv[1], sys.argv[2], sys.argv[3].encode("ascii"), ref)) + b"done\n")
