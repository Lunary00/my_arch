#!/usr/bin/env bash
# Aplica o layout de monitores + workspaces + teclado conforme os
# monitores conectados.
#   TRABALHO: notebook embaixo + 2 Dell em cima; teclado br
#   CASA:     notebook a esquerda + ultrawide LG a direita; teclado us
#   SOZINHO:  apenas o notebook (teclado inalterado)
# Reaplicar a regra de workspace move o workspace e restaura a persistencia,
# por isso usamos hl.workspace_rule (com desc:) em vez de mover manualmente.
# Chamado no inicio do Hyprland e em eventos de hotplug (ver monitor-watch.py).

set -u

mon="$(hyprctl monitors 2>/dev/null)" || exit 0

# aplicar <descricao> <modo> <posicao> <escala>
aplicar() {
    hyprctl eval "hl.monitor({output=\"$1\", mode=\"$2\", position=\"$3\", scale=\"$4\"})" >/dev/null 2>&1
}

# regra <workspace> <descricao do monitor>  (move + deixa persistente)
regra() {
    hyprctl eval "hl.workspace_rule({workspace=\"$1\", monitor=\"$2\", persistent=true})" >/dev/null 2>&1
}

# teclado <indice>  (0 = br / trabalho, 1 = us / casa)
teclado() {
    hyprctl switchxkblayout all "$1" >/dev/null 2>&1
}

if grep -q '25UM58G' <<<"$mon"; then
    # ---- CASA ----
    aplicar 'desc:BOE NV153WUM-N41' 'preferred' '0x0' '1.5'
    aplicar 'desc:LG Electronics 25UM58G 0x000445DD' 'preferred' '1280x0' '1.0'

    regra 1 'desc:BOE NV153WUM-N41'
    regra 2 'desc:BOE NV153WUM-N41'
    regra 3 'desc:LG Electronics 25UM58G 0x000445DD'
    regra 4 'desc:LG Electronics 25UM58G 0x000445DD'
    regra 5 'desc:LG Electronics 25UM58G 0x000445DD'

    teclado 1 # us
elif grep -q '5MJ7XT3' <<<"$mon" && grep -q '5K97XT3' <<<"$mon"; then
    # ---- TRABALHO ----
    aplicar 'desc:BOE NV153WUM-N41' 'preferred' '1280x1080' '1.5'
    aplicar 'desc:Dell Inc. DELL E2222HS 5MJ7XT3' '1920x1080@60' '0x0' '1.0'
    aplicar 'desc:Dell Inc. DELL E2222HS 5K97XT3' '1920x1080@60' '1920x0' '1.0'

    regra 1 'desc:BOE NV153WUM-N41'
    regra 2 'desc:BOE NV153WUM-N41'
    regra 3 'desc:Dell Inc. DELL E2222HS 5MJ7XT3'
    regra 4 'desc:Dell Inc. DELL E2222HS 5MJ7XT3'
    regra 5 'desc:Dell Inc. DELL E2222HS 5K97XT3'
    regra 6 'desc:Dell Inc. DELL E2222HS 5K97XT3'

    teclado 0 # br
else
    # ---- SOMENTE NOTEBOOK ----
    aplicar 'desc:BOE NV153WUM-N41' 'preferred' '0x0' '1.5'
    for ws in 1 2 3 4 5 6; do
        regra "$ws" 'desc:BOE NV153WUM-N41'
    done
    # teclado inalterado (local indefinido)
fi
