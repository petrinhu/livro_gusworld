# Diagramação do PDF de gráfica

**Estado: não testado.** O Typst não está instalado. Este documento é especificação e o trecho de código abaixo ainda não foi compilado. O Typst só será instalado quando o líder pedir o primeiro PDF (decisão de 19/11/2026, rodada 4; regra L-51 de instalação com autorização).

**Para que serve:** registrar a diagramação do PDF de gráfica, para que a montagem da versão impressa siga a mesma decisão do texto do HTML e do ePub.

## Formato da página

- Tamanho: 14 x 21 cm.
- Margens espelhadas, que mudam de lado conforme a página é ímpar ou par:
  - interna (lado da encadernação): 2,2 cm
  - externa: 1,6 cm
  - topo: 2,0 cm
  - pé: 2,2 cm
- Página ímpar (à direita na encadernação): a margem interna fica à esquerda.
- Página par (à esquerda na encadernação): a margem interna fica à direita.
- As margens espelhadas valem só para o PDF de gráfica. O ePub é refluível e o leitor ajusta as margens dele.

## Texto

- Texto justificado.
- Recuo de primeira linha de 1,5em em todo parágrafo.
- Exceção: sem recuo no primeiro parágrafo depois de título de capítulo e no primeiro parágrafo depois de quebra de cena.
- Sem espaço vertical entre parágrafos. O recuo é que marca o início de cada parágrafo.
- Quebra de cena: linha `* * *` no Markdown. No HTML e no ePub ela vira `<hr />`, com `hr + p` sem recuo na folha `estilo.css`. No PDF, vira um bloco centralizado, o que também tira o recuo do parágrafo seguinte.
- Hifenização ativa, em português do Brasil.

## Trecho Typst equivalente

Não testado. Conferir cada linha ao instalar o Typst; a versão de referência ainda não foi fixada.

```typst
// não testado: Typst não instalado
#set page(
  width: 14cm,
  height: 21cm,
  binding: left,  // lombada à esquerda: nas páginas ímpares, inside é a esquerda
  margin: (inside: 2.2cm, outside: 1.6cm, top: 2cm, bottom: 2.2cm),
)
#set text(lang: "pt", region: "BR")
#set par(
  justify: true,
  hyphenate: true,  // confirmar se o parâmetro fica em par ou em text na versão instalada
  first-line-indent: 1.5em,  // sem all: true, o primeiro parágrafo depois de bloco não recua
)
#show par: set block(spacing: 0pt)  // sem espaço entre parágrafos
// quebra de cena: bloco centralizado; o parágrafo depois dele não recua
#let quebra-de-cena() = {
  v(0.8em)
  align(center)[#"* * *"]
  v(0.8em)
}
```

Pontos a confirmar ao instalar:

- Se `first-line-indent` sem `all: true` deixa de recuar o parágrafo depois de título e de bloco (é o comportamento que a documentação descreve).
- Se o parâmetro `hyphenate` fica em `par` ou em `text`.
- Se `binding: left` faz as margens `inside` e `outside` valerem, e em que lado fica a `inside` nas páginas pares e ímpares.
- Se `block(spacing: 0pt)` zera o espaço entre parágrafos sem afetar títulos.

Referência consultada na documentação do Typst: https://typst.app/docs/reference/model/par (lida por busca, sem instalação).
