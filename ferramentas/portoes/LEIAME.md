# Portões

Verificações executadas antes de cada envio de alterações. Os arquivos chegam nas ondas de segurança do processo.

Este diretório é público e não contém conteúdo da obra: as regras são de forma (cifra, travessão, autor, formato da mensagem), sem lista de termos.

- `portoes.py`: lógica única dos portões. Modos `pre-commit`, `commit-msg ARQUIVO`, `assuntos` (lote) e `ci` (sem chave).
- `pre-commit` e `commit-msg`: ganchos do repositório (`core.hooksPath`). Rodam o portão e depois o gancho global de mesmo nome.
- `post-commit`, `post-checkout`, `post-merge`, `prepare-commit-msg`, `pre-push`: só repassam ao gancho global de mesmo nome.
- `testes/rodar.sh DIRETORIO`: autoteste com repositórios descartáveis. Controles positivos, negativos e varredura vazia.

Ativação em um clone: `git config --local core.hooksPath ferramentas/portoes`.

Diretório pai: [ferramentas](../LEIAME.md).
