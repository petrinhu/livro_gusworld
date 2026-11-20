"""Corpo de teste com cabecalho GITCRYPT falso (SG-02): uso gera_corpo.py TIPO N > arquivo, ou
gera_corpo.py aleatorio-lote PASTA (escreve r12, r23, r24, r63, r64, r188 e r4096). So texto generico."""
import gzip
import hashlib
import os
import sys
import zlib

CABECALHO = b"\x00GITCRYPT\x00" + bytes(range(1, 13))
TEXTO = ("Abertura do capitulo. Oi, disse ele. " * 40).encode("ascii")
LOTE = (12, 23, 24, 63, 64, 188, 4096)


def aleatorio(n):
    saida, i = b"", 0
    while len(saida) < n:
        saida += hashlib.sha256(b"sg02c" + i.to_bytes(4, "big")).digest()
        i += 1
    return saida[:n]


def cauda(tipo, n):
    if tipo == "letras":
        return b"a" * n
    if tipo == "utf16":
        return TEXTO.decode("ascii").encode("utf-16-le")[:n]
    if tipo == "gzip":
        return gzip.compress(TEXTO[:n], mtime=0)
    if tipo == "deflate":
        return zlib.compress(TEXTO[:n], 9)[2:-4]
    if tipo == "intercalado":
        return b"".join(TEXTO[i:i + 3] + b"\x01" for i in range(0, n, 3))[:n]
    if tipo == "razao079":
        return b"a" * 79 + b"\x01" * 21
    if tipo == "xor80":
        return bytes(b ^ 0x80 for b in TEXTO[:n])
    if tipo == "aleatorio":
        return aleatorio(n)
    raise SystemExit(f"tipo desconhecido: {tipo}")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "aleatorio-lote":
        for n in LOTE:
            with open(os.path.join(sys.argv[2], f"r{n}.bin"), "wb") as f:
                f.write(CABECALHO + aleatorio(n))
    elif len(sys.argv) == 3:
        sys.stdout.buffer.write(CABECALHO + cauda(sys.argv[1], int(sys.argv[2])))
    else:
        raise SystemExit("uso: gera_corpo.py TIPO N | aleatorio-lote PASTA")
