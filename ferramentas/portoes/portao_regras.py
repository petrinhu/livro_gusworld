"""Constantes dos portoes de sigilo do livro (SG-02). So constantes, sem logica."""
import re

NOREPLY = "238845971+petrinhu@users.noreply.github.com"
CABECALHO = b"\x00GITCRYPT\x00"
# Traco que conta como travessao (L-01 do projeto, ampliada em 20/11/2026, D6 opcao a). O sinal de menos
# (U+2212) fica fora. Na fala, so o U+2014 e aceito, e so abrindo a fala (portao_travessao).
TRAVESSOES = ("\u2014", "\u2013", "\u2015", "\u2012", "\u2e3a", "\u2e3b", "\ufe58", "\ufe31", "\ufe32")
TRAVESSAO_FALA = "\u2014"
FALA = re.compile(r"^(livro-[^/]+/texto/|ferramentas/montagem/amostra/texto/)")
TIPOS = "feat|fix|refactor|chore|docs|test|perf|style|revert"
# Lista fechada de prefixos de ID (SG-02, D5): de 1 a 6 IDs separados por ", ".
ID = (r"(?:(?:FU|AUD|PQ|CO|CA|AR|SG|TE|TST|SI|LO|LA|RG|TR|TL|WK|L[1-3]|E[1-3])-"
      r"(?:[0-9]{2}|TEC[0-9]|W[0-9]{1,2}a?|FX|EX|RV|XX)|F[0-9]+\.[0-9]+)")
ASSUNTO = re.compile(r"(?:%s)(?:\([^()\n]+\))?!?: \S.* \(%s(?:, %s){0,5}\)" % (TIPOS, ID, ID))
ASSUNTO_MAX = 72
# Sessao: a mensagem e normalizada antes (NFKC, sem caractere de formato Cf, casefold), ver portao_mensagem.
SESSAO = (re.compile(r"claude[\W_]*session"), re.compile(r"claude\.ai"), re.compile(r"session_[0-9a-z]{6,}"))
# Linha-tesoura que o git coloca com --cleanup=scissors / commit -v: o gancho local julga so o que vem antes.
TESOURA = re.compile(r"^# -+ >8 -+$", re.MULTILINE)
# Ultimo commit antes desta OS (SG-02): o formato do assunto nao vale para o historico ate ele (D5, sem reescrita).
MARCO = "6b98df7fd4eb2be6493bbf214c8a995748b34272"
FILTRO_EXIGIDO = (
    ("filter.git-crypt.clean", None),
    ("filter.git-crypt.smudge", None),
    ("filter.git-crypt.required", "true"),
)

# Hashes de blob aprovados de arquivo de confianca (SG-02): mudar o arquivo muda o hash e exige novo aprovado.
APROVADOS = {
    ".github/workflows/sigilo.yml": ("0fc73b5f413865d904f4a4e16e85db2552994c9f",),
    "ferramentas/portoes/ci-bootstrap.sh": ("1283099e74cbe46d55116e5951ed5eb4fa305cf9",),
}

# Caminhos que ficam em claro (SG-02, OS 5.3). Esta lista e a unica autoridade: o portao nao consulta
# .gitattributes (check-attr). Caminho de excecao com cabecalho cifrado reprova; caminho de zona sem
# excecao reprova; o resto tem que estar cifrado.
DOCS_FERRAMENTAS = ("ferramentas/montagem/diagramacao.md",)
EXCECOES = tuple(re.compile(p) for p in (
    r"\.gitattributes", r"\.gitignore", r"README\.md", r"LICENSE\.md",
    r"\.github/workflows/[a-z0-9_-]+\.yml",
    r"ferramentas/(?:[a-z0-9_-]+/)*LEIAME\.md",
    r"ferramentas/(?:[a-z0-9_-]+/)*[a-z0-9_-]+\.(?:py|sh|lua|css)",
    r"ferramentas/montagem/amostra/metadados\.yaml",
    r"ferramentas/montagem/amostra/texto/c[0-9]{2}\.md",
    r"ferramentas/portoes/(?:pre-commit|commit-msg|pre-push|post-commit|post-checkout|post-merge|prepare-commit-msg)",
) + tuple(re.escape(d) for d in DOCS_FERRAMENTAS))
ZONAS_DE_EXCECAO = (re.compile(r"ferramentas/.*"), re.compile(r"\.github/workflows/.*"))
CONTROLE = re.compile(r"[\x00-\x1f\x7f]")
MODOS_PROIBIDOS = ("160000", "120000")  # submodulo e link simbolico

# Binario: so em caminho cifrado, com teto no conteudo decifrado (SG-02, D7).
BINARIOS = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".pdf", ".ttf", ".otf", ".woff", ".woff2")
TETO_BINARIO = 50 * 1024 * 1024
TAMANHO_CABECALHO = 22  # 10 de cabecalho + 12 de nonce
# Amostra em claro (SG-02, M1): teto por arquivo, pega a copia acidental de um capitulo inteiro.
TETO_AMOSTRA = 8192
AMOSTRA = re.compile(r"ferramentas/montagem/amostra/texto/c[0-9]{2}\.md")
# Volume em claro (SG-02d, C1): a arvore e o indice (pre-commit), o HEAD (ci) ou cada ponta enviada (envio).
TETO_CLARO = 16384  # cada arquivo em claro fora da amostra
TETO_CLARO_ARVORE = 262144  # soma dos arquivos em claro de uma arvore
TETO_AMOSTRA_ARVORE = 16384  # soma dos arquivos da amostra de uma arvore

# Heuristica sem chave (S14, SG-02). Limiares fixados pela teoria de bytes aleatorios, antes do dado (L-43).
# Cifra real medida: 72 blobs, corpo de 79 a 35175 bytes, nenhum suspeito por estas regras.
ASSINATURAS = (b"\x1f\x8b\x08", b"PK\x03\x04", b"BZh", b"\xfd7zXZ\x00", b"\x28\xb5\x2f\xfd",
               b"7z\xbc\xaf\x27\x1c", b"\xef\xbb\xbf")
CORPO_MIN = 12          # abaixo disso o corpo e pequeno e passa sem chave (classe K3)
CORPO_CURTO = 24        # de 12 a 23 bytes: suspeito se todo byte for imprimivel
CORPO_ESTATISTICO = 64  # a partir daqui: fracao de bytes altos e numero de valores distintos
JANELA = 4096  # a estatistica vale em cada janela do corpo, nao num prefixo (SG-02d, C3)
K_SIGMA = 7  # banda em desvios-padrao em torno do esperado de bytes aleatorios, em cada janela (SG-02d, A1)
FAIXA_ALTOS = (0.20, 0.80)
LIMIAR_LEGIVEL = 0.80
IMPRIMIVEIS = frozenset(range(0x20, 0x7F)) | {0x09, 0x0A, 0x0D}
