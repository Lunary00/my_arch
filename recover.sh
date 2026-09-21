#!/usr/bin/env bash
# =============================================================================
# recover.sh — recupera uma instalação que ficou SEM bootloader.
#
# Uso (no LIVE ISO, como root):
#   curl -sL http://192.168.122.1:8000/recover.sh | bash
#
# O que faz:
#   1. Monta os subvolumes Btrfs instalados + a ESP
#   2. Baixa o bootstrap.sh corrigido do host
#   3. Roda o bootstrap dentro do chroot (instala GRUB, mkinitcpio, serviços...)
#   4. Desmonta e manda reiniciar
# =============================================================================
set -euo pipefail

HOST_URL="${HOST_URL:-http://192.168.122.1:8000}"
DISK="${DISK:-/dev/vda}"
ESP="${DISK}1"
RAIZ="${DISK}2"

OPTS="noatime,compress=zstd:1,ssd,discard=async,space_cache=v2"

echo "[recover] disco=$DISK  bootstrap=$HOST_URL/bootstrap.sh"
lsblk "$DISK"

# 0) limpa montagens anteriores (permite rodar de novo com segurança)
umount -R /mnt 2>/dev/null || true

# 1) monta o sistema instalado
mkdir -p /mnt
mount -o "$OPTS,subvol=@" "$RAIZ" /mnt
mkdir -p /mnt/{home,.snapshots,var/log,var/cache,swap,tmp,boot}
mount -o "$OPTS,subvol=@home"      "$RAIZ" /mnt/home
mount -o "$OPTS,subvol=@snapshots" "$RAIZ" /mnt/.snapshots
mount -o "$OPTS,subvol=@var_log"   "$RAIZ" /mnt/var/log
mount -o "$OPTS,subvol=@var_cache" "$RAIZ" /mnt/var/cache
mount -o "$OPTS,subvol=@swap"      "$RAIZ" /mnt/swap
mount -o "$OPTS,subvol=@tmp"       "$RAIZ" /mnt/tmp
mount "$ESP" /mnt/boot

# 2) pega o bootstrap corrigido
echo "[recover] baixando bootstrap.sh corrigido..."
curl -fsSL "$HOST_URL/bootstrap.sh" -o /mnt/root/bootstrap.sh
chmod +x /mnt/root/bootstrap.sh

# 3) completa a instalação (vai pedir as senhas)
echo "[recover] rodando bootstrap no chroot..."
arch-chroot /mnt /root/bootstrap.sh

# 4) desmonta
echo "[recover] desmontando..."
umount -R /mnt

echo
echo "[recover] CONCLUÍDO. Agora rode:   reboot"
