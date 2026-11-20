# Grupo TF: traços parecidos com travessão (SG-02, D6 da L-01 do projeto). Carregado por rodar.sh, depois de
# casos-travessao.sh (reusa td_capitulo). Todo traço nasce por printf octal; entidade por AMP, nunca literal.
H15=$(printf '\342\200\225')    # U+2015 barra horizontal
H12=$(printf '\342\200\222')    # U+2012 traco de figura
H2E3A=$(printf '\342\270\272')  # U+2E3A travessao duplo
H2E3B=$(printf '\342\270\273')  # U+2E3B travessao triplo
HFE58=$(printf '\357\271\230')  # U+FE58 travessao pequeno
HFE31=$(printf '\357\270\261')  # U+FE31 travessao vertical
HFE32=$(printf '\357\270\262')  # U+FE32 travessao vertical inferior
MENOS=$(printf '\342\210\222')  # U+2212 sinal de menos (fica fora)

for par in "TF1 $H15" "TF2 $H12" "TF3 $H2E3A" "TF4 $H2E3B" "TF5 $HFE58" "TF6 $HFE31" "TF7 $HFE32"; do
    id=${par%% *}; cod=${par#* }
    printf 'Ele disse %s oi.\n' "$cod" > "$SCR/$(echo "$id" | tr 'A-Z' 'a-z').md"
    td_capitulo "$(echo "$id" | tr 'A-Z' 'a-z')" "$SCR/$(echo "$id" | tr 'A-Z' 'a-z').md"
    caso "$id" REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "traco parecido no meio da frase"
done

printf 'Ele disse %s oi.\n' "$MENOS" > "$SCR/tf8.md"
td_capitulo tf8 "$SCR/tf8.md"
caso TF8 OK $? - - "controle: sinal de menos nao e travessao"

printf 'Abertura.\n\n%s Oi, disse ele.\n' "$MEIO" > "$SCR/tf9.md"
td_capitulo tf9 "$SCR/tf9.md"
caso TF9 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "meio-travessao abrindo fala nao e aceito"

printf 'Abertura.\n\n%s Oi, disse ele.\n' "$TRAV" > "$SCR/tf10.md"
td_capitulo tf10 "$SCR/tf10.md"
caso TF10 OK $? - - "controle: travessao em fala aceito"

printf 'Ele disse %s#x2E3A; oi.\n' "$AMP" > "$SCR/tf11.md"
td_capitulo tf11 "$SCR/tf11.md"
caso TF11 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade hexadecimal de travessao duplo"

printf 'Ele disse %shorbar; oi.\n' "$AMP" > "$SCR/tf12.md"
td_capitulo tf12 "$SCR/tf12.md"
caso TF12 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "entidade nomeada de barra horizontal"

printf 'Abertura.\n\n%s Oi, disse ele.\n' "$H15" > "$SCR/tf13.md"
td_capitulo tf13 "$SCR/tf13.md"
caso TF13 REPROVA $? "travessao fora de inicio de fala" "$SCR/saida.txt" "barra horizontal abrindo fala nao e aceita"
