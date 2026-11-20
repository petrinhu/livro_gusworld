-- filtro-links.lua (TE-01)
--
-- Converte link relativo entre capitulos (arquivo.md ou arquivo.md#id) em link
-- interno (#id). O Pandoc resolve o #id para o xhtml certo no ePub e mantem o
-- link valido no HTML de arquivo unico. Sem este filtro, o link para arquivo.md
-- quebra nos dois formatos.
--
-- Regras:
--   - So mexe em link relativo terminado em .md ou .md#id. URL com esquema
--     (http:, mailto:) e caminho absoluto ficam intactos; #id puro tambem.
--   - Link para arquivo.md sem fragmento vai para o id do primeiro cabecalho
--     daquele capitulo.
--   - Alvo que nao e capitulo da montagem, ou id que nao existe no capitulo,
--     aborta a montagem com erro (saida diferente de zero).
--
-- O mapa capitulo -> ids sai da ordem dos cabecalhos de topo do documento
-- combinado: cada capitulo, lido em separado pelo pandoc.read, diz quantos
-- cabecalhos de topo tem, e essa contagem fatia a lista de cabecalhos do
-- documento combinado. Os ids sao os do proprio Pandoc (ja com deduplicacao),
-- sem refazer a regra de slug.

local ids_por_capitulo = {}  -- "c01.md" -> { id = true, ... }
local primeiro_id = {}       -- "c01.md" -> id do primeiro cabecalho

local function nome_do_arquivo(caminho)
  return caminho:match("([^/\\]+)$")
end

local function alvo_capitulo(alvo)
  if alvo:match("^#") or alvo:match("^/") or alvo:match("^[%a][%w+.-]*:") then
    return nil
  end
  local base, frag = alvo:match("^([^#]+%.md)#(.*)$")
  if base then
    if frag == "" then return base, nil end
    return base, frag
  end
  base = alvo:match("^([^#]+%.md)$")
  if base then return base, nil end
  return nil
end

local function mapear_capitulos(doc)
  local cabecalhos = {}
  for _, bloco in ipairs(doc.blocks) do
    if bloco.t == "Header" then
      cabecalhos[#cabecalhos + 1] = bloco
    end
  end

  local arquivos = PANDOC_STATE.input_files or {}
  local posicao = 0
  for _, caminho in ipairs(arquivos) do
    local fh = assert(io.open(caminho, "r"))
    local texto = fh:read("a")
    fh:close()
    local lido = pandoc.read(texto, "markdown")
    local nome = nome_do_arquivo(caminho)
    ids_por_capitulo[nome] = {}
    for _, bloco in ipairs(lido.blocks) do
      if bloco.t == "Header" then
        posicao = posicao + 1
        local cab = cabecalhos[posicao]
        if cab == nil then
          error("filtro-links: contagem de cabecalhos divergiu em " .. nome)
        end
        ids_por_capitulo[nome][cab.identifier] = true
        if primeiro_id[nome] == nil then
          primeiro_id[nome] = cab.identifier
        end
      end
    end
  end

  if posicao ~= #cabecalhos then
    error(string.format(
      "filtro-links: %d cabecalhos no documento e %d nos capitulos",
      #cabecalhos, posicao))
  end
end

local function reescrever_link(el)
  local base, frag = alvo_capitulo(el.target)
  if base == nil then
    return nil
  end
  local nome = nome_do_arquivo(base)
  local ids = ids_por_capitulo[nome]
  if ids == nil then
    error("filtro-links: link para capitulo fora da montagem: " .. el.target)
  end
  if frag == nil then
    if primeiro_id[nome] == nil then
      error("filtro-links: capitulo sem cabecalho, link impossivel: " .. el.target)
    end
    el.target = "#" .. primeiro_id[nome]
  else
    if not ids[frag] then
      error("filtro-links: id inexistente em " .. nome .. ": #" .. frag)
    end
    el.target = "#" .. frag
  end
  return el
end

function Pandoc(doc)
  mapear_capitulos(doc)
  return doc:walk({ Link = reescrever_link })
end
