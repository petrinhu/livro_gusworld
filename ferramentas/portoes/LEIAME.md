# Portões

Verificações que julgam cada commit local, cada envio e o CI público do repositório.

Este diretório é público e não contém conteúdo da obra. As regras são de forma: cifra, travessão, autor, formato da mensagem, tags e arquivos de confiança do CI. Nenhuma regra usa lista de termos.

## Instalar

Depois de clonar o repositório, rode na raiz dele:

    sh ferramentas/portoes/instalar.sh

A saída traz linhas `[instalar]`: a pasta onde os ganchos ficaram e a confirmação de `core.hooksPath` e de `filter.git-crypt.required=true`.

O instalador copia os ganchos do commit atual (HEAD) para uma pasta fora da árvore de trabalho, dentro da pasta comum do Git (`portoes-ganchos`). Depois aponta `core.hooksPath` para essa pasta e exige a cifra. Por isso, editar um gancho na árvore de trabalho não muda o que roda.

Reinstale sempre que um destes arquivos mudar: `pre-commit`, `commit-msg`, `pre-push`, `confiavel.sh` ou `instalar.sh`. O passo é fazer o commit da mudança e rodar `instalar.sh` logo depois. Se você esquecer, o próximo commit reprova com `ganchos instalados divergem do HEAD`. Esse vermelho é o comportamento certo.

## Quem julga cada commit

O portão que julga um commit é o do commit anterior, nunca o do próprio commit. Assim, um commit não aprova a própria mudança de regra. Quando um commit muda o portão, a regra nova vale a partir do commit seguinte.

- **Commit local** (`pre-commit` e `commit-msg`): o portão é extraído do HEAD para uma pasta temporária e roda com `python3 -I`, que não importa módulos da pasta do projeto.
- **Envio** (`pre-push`): o portão vem do commit que o remoto já tem, a base do envio. Se o remoto não tem commit, vem do HEAD.
- **CI público** (`ci-bootstrap.sh`): a base é o pull request ou, na falta dele, o envio anterior. Sem base, o CI usa o HEAD e a saída mostra `[ci-origem] portao de proprio-commit`.

Arquivos de confiança são o workflow `.github/workflows/sigilo.yml`, todo arquivo de `.github/workflows/` e o `ferramentas/portoes/ci-bootstrap.sh`. Cada um precisa estar na lista de hashes aprovados (`APROVADOS`, em `portao_regras.py`).

Para mudar um arquivo de confiança ou o portão, use dois passos:

1. Um commit que só acrescenta o hash novo à lista de aprovados. Se o commit anterior já foi publicado, faça um envio com ele.
2. O commit com a mudança de fato.

## O que fica em claro e o que é cifrado

A lista de caminhos em claro está no código do portão (`portao_regras.py`, constante `EXCECOES`). Essa lista é a única autoridade: o portão não consulta atributos do Git. Um commit não cria exceção sozinho, porque mudar a lista muda o código que julga.

Ficam em claro:

- arquivos de configuração da raiz (atributos, ignorados, README e licença);
- workflows do CI, em `.github/workflows/`;
- `LEIAME.md`, scripts e módulos de `ferramentas/`, e o documento de diagramação;
- o livro de amostra de `ferramentas/montagem/amostra/`, que não tem obra.

Fica cifrado todo o resto do repositório, em especial os textos e as notas de trabalho da obra. Um caminho cifrado não pode ter conteúdo em claro. Um caminho em claro não pode ter cabeçalho cifrado.

Também são recusados:

- arquivo novo de forma não aprovada dentro de `ferramentas/` (por exemplo, um `.md` de documentação que não está na lista);
- arquivo de atributos fora da raiz;
- submódulo e link simbólico;
- nome de caminho com quebra de linha ou caractere de controle;
- arquivo que não é UTF-8, salvo binário de tipo conhecido;
- binário (imagem, fonte ou PDF) fora de caminho cifrado, ou acima de 50 MiB.

## Regras de travessão

- O travessão é o U+2014, e só abre fala. Nos textos, ele aparece no início do parágrafo, depois de linha em branco ou de título.
- Em todo texto decifrado são barrados: U+2013, U+2015, U+2012, U+2E3A, U+2E3B, U+FE58, U+FE31 e U+FE32, com as entidades HTML de cada um deles. O U+2014 fora de abertura de fala também é barrado.
- O sinal de menos (U+2212) é permitido.
- Fora dos textos (código, documentação, canon, mensagem de commit e de tag), travessão é proibido em qualquer posição.
- No fonte dos textos, hífen duplo e triplo viram travessão na saída, porque o Pandoc usa a extensão `smart`. Por isso eles contam. Uma régua de tabela (linha só com traços e barras verticais) não conta.
- Na mensagem de commit, o gancho local olha só o texto acima da linha-tesoura do `git commit -v`. O envio e o CI conferem a mensagem inteira.

## Regras de mensagem e autor

- Autor e committer são o endereço de NOREPLY do GitHub configurado neste repositório, com `git config --local`.
- O assunto segue `tipo(escopo): descrição (ID)`. Os tipos são `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `style` e `revert`. O ID vem de uma lista fechada de prefixos: de 1 a 6 IDs, separados por vírgula e espaço. O assunto tem até 72 caracteres.
- A mensagem não começa com linha de comentário e não tem rodapé de sessão em nenhuma linha. Tags anotadas também têm tagger de NOREPLY.
- Commits anteriores ao marco de adoção do formato ficam isentos só do formato do assunto. Autor e rodapé de sessão valem para todo o histórico.

## Autotestes

Os portões têm um autoteste com repositórios descartáveis:

    bash ferramentas/portoes/testes/rodar.sh <pasta-temporária>

- A pasta temporária fica fora do repositório, por exemplo dentro de `$TMPDIR`. Cada caso cria os próprios repositórios dentro dela.
- Cada caso imprime uma linha com `esperado`, `obtido`, `rc`, `trecho` e `ok` ou `FALHOU`. Um caso só é `ok` quando o resultado bate e o trecho esperado aparece na saída.
- A última linha é `RESUMO casos=N falharam=K`. O comando sai com 0 só quando `K` é zero.
- Requisitos: `git`, `git-crypt`, `sh` e `python3` (com a opção `-I`, a partir do Python 3.4).
- O autoteste não toca no repositório real nem na chave dele.

A montagem tem o próprio autoteste, sem argumentos: `bash ferramentas/montagem/testes/rodar.sh`.

## CI sem chave

O workflow `.github/workflows/sigilo.yml` roda em `push` e em `pull_request`, com permissão só de leitura. Ele faz dois passos:

1. `sh ferramentas/portoes/ci-bootstrap.sh`: julga o histórico pelo portão da base. Confere cada blob fora da lista de caminhos em claro usando só o cabeçalho cifrado e uma heurística de texto legível. Reprova se a saída não trouxer as linhas de contagem exigidas.
2. gitleaks, com a ação e a versão fixadas em SHA e sem artefato público.

O CI não tem chave. A conferência completa do conteúdo cifrado acontece no envio (`pre-push`), na máquina de quem tem a chave.

## Resíduos aceitos

O líder aceitou os resíduos abaixo em 20/11/2026. Cada um tem controle e forma de verificação. O detalhe técnico fica fora deste arquivo.

- **R1: arquivos de CI alterados no próprio envio.** Controle: os hashes aprovados são conferidos antes de qualquer envio, e `--no-verify` é proibido pela política do projeto. Verificação: casos de confiança do autoteste e revisão de todo envio que toca `.github/`.
- **R2: mudança do portão em dois envios separados.** Controle: a sequência de dois passos descrita acima. Verificação: revisão do líder a cada mudança de portão.
- **R3: limite da conferência sem chave.** Conteúdo muito pequeno, comprimido ou codificado pode passar sem a conferência do CI. Controle: a conferência completa com chave no envio. Verificação: o envio com chave decifra todo blob do intervalo enviado.
- **R4: primeiro envio sem base de comparação.** Controle: o SG-04 confere o portão extraído do commit auditado, fora do repositório, em clone novo, antes do primeiro envio público. Verificação: critério de aceite do SG-04.
- **R5: texto em claro em caminho permitido.** Por exemplo, texto dentro de código ou do livro de amostra. Controle: a lista de caminhos em claro é fechada e só muda por commit revisado. Verificação: revisão de todo commit que altera `EXCECOES`.
- **R6: nomes e tamanhos de caminho visíveis.** O Git expõe nomes e tamanhos de arquivo mesmo quando o conteúdo é cifrado. Controle: nomes neutros e a decisão de aceitar tamanho tomada no SG-01. Verificação: revisão de nomes de caminho antes de cada commit.

Diretório pai: [ferramentas](../LEIAME.md).
