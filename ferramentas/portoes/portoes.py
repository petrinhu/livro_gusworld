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

Modulos: portao_regras (constantes), portao_git (git em lote e saida), portao_cifra, portao_travessao,
portao_mensagem (mensagem e autor), portao_historico (modo ci).
"""
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ na arvore (os modulos sao importados)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))  # append: a biblioteca padrao vem antes

from portao_cifra import portao_cifra  # noqa: E402
from portao_git import ErroGit, imprime, indice  # noqa: E402
from portao_historico import ci  # noqa: E402
from portao_mensagem import assuntos, commit_msg, portao_autor  # noqa: E402
from portao_travessao import portao_travessao  # noqa: E402


def pre_commit():
    itens = indice()
    res = [
        imprime("cifra", len(itens), *portao_cifra(itens)),
        imprime("travessao", len(itens), *portao_travessao(itens)),
        imprime("autor", 2, *portao_autor()),
    ]
    return all(res)


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
