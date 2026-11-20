# Portões

Verificações executadas antes de cada envio de alterações. Os arquivos chegam nas ondas de segurança do processo.

Este diretório é público e não contém conteúdo da obra: as regras são de forma (cifra, travessão, autor, formato da mensagem), sem lista de termos.

- `portoes.py`: linha de comando dos portões. Modos `pre-commit`, `commit-msg ARQUIVO`, `assuntos` (lote), `ci` (sem chave) e `envio` (pre-push).
- `portao_*.py`: módulos do portão (regras, git em lote, cifra, travessão, mensagem e autor, histórico).
- `confiavel.sh`: funções comuns dos ganchos. Julga cada commit pelo portão do commit anterior, extraído para pasta temporária.
- `pre-commit`, `commit-msg`, `pre-push`: ganchos que julgam. `post-commit`, `post-checkout`, `post-merge`, `prepare-commit-msg`: só repassam ao gancho global de mesmo nome.
- `instalar.sh`: copia os ganchos do HEAD para fora da árvore de trabalho e liga `core.hooksPath` e `filter.git-crypt.required`. Rode após clonar e após cada mudança de gancho.
- `ci-bootstrap.sh` e `ci-base.sh`: portão do CI sem chave. Julgam o HEAD pelo portão da base (`BASE_PR`, senão `BASE_PUSH`).
- `testes/rodar.sh DIRETORIO`: autoteste com repositórios descartáveis. Controles positivos, negativos e varredura vazia.

Ativação em um clone: `sh ferramentas/portoes/instalar.sh`.

Diretório pai: [ferramentas](../LEIAME.md).
