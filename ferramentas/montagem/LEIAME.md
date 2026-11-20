# Montagem

Geração dos formatos de leitura a partir dos textos, com metadados, folha de estilo e conferência de links, contagem e travessão.

Este diretório é público e não contém conteúdo da obra.

## Montar um livro

    ferramentas/montagem/montar.sh <pasta-do-livro>

A pasta do livro tem `texto/c*.md` (capítulos, em ordem de nome) e `metadados.yaml` (título, autor, `lang` e `identifier` fixo). O comando gera `saida/<nome-da-pasta>.html` (HTML5 de arquivo único, com sumário) e `saida/<nome-da-pasta>.epub` (ePub 3), na pasta `saida/` da raiz do repositório. Essa pasta é ignorada pelo git: o que sai dela não se commita.

Exemplo com o livro de amostra deste diretório:

    ferramentas/montagem/montar.sh ferramentas/montagem/amostra
    epubcheck saida/amostra.epub

Arquivos:

- `montar.sh`: monta os dois formatos. Qualquer erro aborta com status diferente de zero.
- `varrer_saida.py`: varredura da saída, descrita abaixo.
- `filtro-links.lua`: troca link entre capítulos (`arquivo.md` ou `arquivo.md#id`) por link interno. Link para capítulo fora da montagem, ou para id que não existe, aborta a montagem.
- `estilo.css`: folha de estilo do HTML e do ePub. Texto justificado, recuo de 1,5em em cada parágrafo, sem espaço entre parágrafos, sem recuo no primeiro parágrafo depois de título e depois de quebra de cena. Hifenização ativa no texto em português (`:lang(pt)`).
- `diagramacao.md`: especificação do PDF de gráfica (14x21 cm, margens espelhadas, trecho Typst). Não testado: o Typst ainda não está instalado.
- `amostra/`: livro de amostra, sem obra real, usado para testar a montagem.
- `testes/rodar.sh`: autoteste da montagem, sem argumentos.

## Varredura da saída

Antes de mover os arquivos para `saida/`, `montar.sh` roda `varrer_saida.py` sobre o HTML e o ePub gerados. O ePub é aberto como zip, e a varredura olha as entradas `.xhtml`, `.html`, `.htm`, `.ncx` e `.opf`.

- Cada traço da lista de travessões (U+2014, U+2013, U+2015, U+2012, U+2E3A, U+2E3B, U+FE58, U+FE31 e U+FE32) aparece na saída como entidade ou como caractere. A varredura troca as entidades antes de olhar.
- U+2014 só é aceito se abrir fala: o texto anterior, até 300 caracteres para trás, termina numa abertura de parágrafo `<p>` seguida só de espaços. Os outros traços da lista são sempre recusados.
- A saída mostra `[saida] encontrados=D analisados=D falharam=F`, onde `D` é o número de documentos varridos. Zero documento reprova. Para cada falha, mostra o arquivo e a posição, nunca o texto.
- Se a varredura reprova, `montar.sh` apaga os temporários e sai com status diferente de zero.

A varredura é a segunda barreira. A primeira é o portão de commit, que já barra esses traços no fonte.

## Travessão no texto

- O travessão é o U+2014 e só abre fala, no início do parágrafo.
- Os traços parecidos com travessão são barrados, em qualquer posição.
- O sinal de menos (U+2212) é permitido.
- Hífen duplo e triplo no fonte viram travessão na saída, pela extensão `smart` do Pandoc. Por isso contam nos capítulos.
- Para quebra de cena, use uma linha só com `* * *`. O Pandoc grava como `<hr />`, e o CSS tira o recuo do parágrafo que vem logo depois. Não use traços para isso.

## Pré-requisitos

`pandoc` 3.x no PATH, `python3` e `epubcheck` 5.4.0 (oficial do W3C) para conferir o ePub.

Diretório pai: [ferramentas](../LEIAME.md).
