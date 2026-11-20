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
