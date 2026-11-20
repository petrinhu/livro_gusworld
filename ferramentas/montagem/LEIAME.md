# Montagem

Geração dos formatos de leitura a partir dos textos, com metadados, folha de estilo e conferência de links e contagem.

Este diretório é público e não contém conteúdo da obra.

## Montar um livro

    ferramentas/montagem/montar.sh <pasta-do-livro>

A pasta do livro tem `texto/c*.md` (capítulos, em ordem de nome) e `metadados.yaml` (título, autor, `lang` e `identifier` fixo). O comando gera `saida/<nome-da-pasta>.html` (HTML5 de arquivo único, com sumário) e `saida/<nome-da-pasta>.epub` (ePub 3), na pasta `saida/` da raiz do repositório. Essa pasta é ignorada pelo git: o que sai dela não se commita.

Exemplo com o livro de amostra deste diretório:

    ferramentas/montagem/montar.sh ferramentas/montagem/amostra
    epubcheck saida/amostra.epub

Arquivos:

- `montar.sh`: monta os dois formatos. Qualquer erro aborta com status diferente de zero.
- `filtro-links.lua`: troca link entre capítulos (`arquivo.md` ou `arquivo.md#id`) por link interno. Link para capítulo fora da montagem, ou para id que não existe, aborta a montagem.
- `estilo.css`: folha de estilo, com hifenização ativa no texto em português (`:lang(pt)`).
- `amostra/`: livro de amostra, sem obra real, usado para testar a montagem.

Pré-requisitos: `pandoc` 3.x no PATH e `epubcheck` 5.4.0 (oficial do W3C) para conferir o ePub.

Diretório pai: [ferramentas](../LEIAME.md).
