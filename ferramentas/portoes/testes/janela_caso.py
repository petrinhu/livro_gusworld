"""Heuristica sem chave sobre um corpo sintetico (SG-02e). Uso: janela_caso.py DIR FORMA.

DIR: copia dos modulos do portao em scratch. Sai 0 se o corpo passa (motivo vazio), 1 se e suspeito (imprime
o motivo) e 3 se o portao levanta excecao (imprime o nome). So bytes aleatorios e texto generico.
"""
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from portao_cifra import motivo_suspeito  # noqa: E402
from portao_regras import CABECALHO  # noqa: E402

SORTE = random.Random(20261120)


def aleatorio(n):
    return SORTE.randbytes(n)


def legivel(n):
    return (b"texto generico de teste " * (n // 24 + 1))[:n]


FORMAS = {
    "a4097": lambda: aleatorio(4097),
    "a4159": lambda: aleatorio(4159),
    "a4160": lambda: aleatorio(4160),
    "l1de3": lambda: legivel(4096) + aleatorio(4096) + aleatorio(30),
    "l2de4": lambda: aleatorio(4096) + legivel(4096) + aleatorio(4096) + aleatorio(30),
}

try:
    motivo = motivo_suspeito(CABECALHO + bytes(12) + FORMAS[sys.argv[2]]())
except Exception as e:  # noqa: BLE001 - o caso mede a excecao que o portao real nao captura
    print("excecao", type(e).__name__)
    sys.exit(3)
print("motivo", repr(motivo))
sys.exit(1 if motivo else 0)
