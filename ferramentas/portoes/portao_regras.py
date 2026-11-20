"""Constantes dos portoes de sigilo do livro (SG-02). So constantes, sem logica."""
import re

NOREPLY = "238845971+petrinhu@users.noreply.github.com"
CABECALHO = b"\x00GITCRYPT\x00"
TRAVESSOES = ("\u2014", "\u2013")
FALA = re.compile(r"^(livro-[^/]+/texto/|ferramentas/montagem/amostra/texto/)")
TIPOS = "feat|fix|refactor|chore|docs|test|perf|style|revert"
ASSUNTO = re.compile(
    r"^(?:%s)(?:\([^()\n]+\))?!?: \S.* \((?:[A-Z][A-Z0-9]{0,7}-[A-Za-z0-9]{1,8}|F[0-9]+\.[0-9]+)\)$"
    % TIPOS
)
ASSUNTO_MAX = 72
SESSAO = re.compile(r"claude-session", re.IGNORECASE)
FILTRO_EXIGIDO = (
    ("filter.git-crypt.clean", None),
    ("filter.git-crypt.smudge", None),
    ("filter.git-crypt.required", "true"),
)

# Hashes de blob aprovados de arquivo de confianca (SG-02): mudar o arquivo muda o hash e exige novo aprovado.
APROVADOS = {
    ".github/workflows/sigilo.yml": ("66fccf3e2afd38038fdf2d858496c11e69aed4d9",),
    "ferramentas/portoes/ci-bootstrap.sh": ("801b2522740b7d13e4a65ef669c4174681f88a09",),
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

# Heuristica sem chave (S14). Limiar fixado antes do dado (L-43): cifra real fica entre 0,324 e 0,479.
CORPO_MIN = 24
LIMIAR_LEGIVEL = 0.80
IMPRIMIVEIS = frozenset(range(0x20, 0x7F)) | {0x09, 0x0A, 0x0D}
