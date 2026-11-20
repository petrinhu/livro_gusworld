"""Portao de cifra (SG-02): todo arquivo do indice fora da excecao tem cabecalho cifrado e filtro git-crypt."""
from portao_git import atributos, conteudos, git_tenta
from portao_regras import CABECALHO, FILTRO_EXIGIDO


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
