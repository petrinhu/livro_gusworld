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
