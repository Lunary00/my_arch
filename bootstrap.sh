#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — provisiona o sistema DENTRO do chroot (ou pós-instalação).
#
# Uso:   arch-chroot /mnt /root/bootstrap.sh
#
# Ordem INTENCIONAL (resiliente):
#   1) locale/hostname   2) usuário   3) initramfs portátil
#   4) BOOTLOADER   <- crítico: vem ANTES de qualquer pacote opcional
#   5) mkinitcpio + grub-mkconfig
#   6) serviços
#   7) GPU (opcional)   8) zram (opcional)
# Assim, se um pacote opcional falhar, o sistema AINDA boota.
# =============================================================================
set -euo pipefail

# ============================ Variáveis (AJUSTE) ============================
HOSTNAME="archvm"
TIMEZONE="America/Sao_Paulo"
LOCALES=("en_US.UTF-8" "pt_BR.UTF-8")
LANG_DEFAULT="en_US.UTF-8"
USERNAME="mateus"                 # <- SEU usuário
SHELL_USER="/bin/zsh"
USE_LUKS=0                        # 1 se você usou LUKS no install.sh (CRYPT=1)
BOOTLOADER="grub"                 # "grub" (recomendado) | "systemd-boot"
# =============================================================================

log(){ printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m[x] %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Rode como root (dentro do chroot)."

# --- 1. Relógio / locale / hostname -----------------------------------------
log "Timezone, locale e hostname"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

for l in "${LOCALES[@]}"; do
  sed -i "s/^#$l/$l/" /etc/locale.gen
done
locale-gen
echo "LANG=$LANG_DEFAULT" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# --- 2. Usuário e sudo --------------------------------------------------------
log "Criando usuário '$USERNAME'"
if ! id "$USERNAME" &>/dev/null; then
  useradd -m -G wheel -s "$SHELL_USER" "$USERNAME"
fi
echo ">>> Defina a senha de ROOT:"
passwd
echo ">>> Defina a senha de $USERNAME:"
passwd "$USERNAME"
grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers || \
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- 3. Initramfs portátil ----------------------------------------------------
# 'autodetect' restringe o initramfs ao hardware ATUAL; removê-lo permite bootar
# em OUTRA máquina (requisito de portabilidade do projeto).
log "Removendo 'autodetect' do mkinitcpio (initramfs portátil)"
sed -i 's/\bautodetect\b//g' /etc/mkinitcpio.conf
if [ "$USE_LUKS" = "1" ] && ! grep -q 'encrypt' /etc/mkinitcpio.conf; then
  sed -i 's/^HOOKS=(\(.*\) filesystems/HOOKS=(\1 encrypt filesystems/' /etc/mkinitcpio.conf
fi

# --- 4. BOOTLOADER (crítico — antes de qualquer opcional) --------------------
log "Instalando bootloader: $BOOTLOADER"
if [ "$BOOTLOADER" = "grub" ]; then
  pacman -S --needed --noconfirm grub efibootmgr os-prober pciutils
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB \
    || die "grub-install FALHOU — a ESP está montada em /boot? O sistema NÃO vai bootar."
else
  pacman -S --needed --noconfirm efibootmgr pciutils
  bootctl install || die "bootctl install FALHOU."
  warn "systemd-boot: crie manualmente /boot/loader/loader.conf e entries/arch.conf"
fi

# --- 5. Initramfs + menu do GRUB ---------------------------------------------
log "Gerando initramfs"
mkinitcpio -P
if [ "$BOOTLOADER" = "grub" ]; then
  log "Gerando grub.cfg"
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# --- 6. Serviços essenciais ---------------------------------------------------
log "Habilitando serviços"
systemctl enable NetworkManager fstrim.timer
# O bluetooth.service só existe após instalar o pacote 'bluez' (Fase 4).
# Habilitar aqui falharia em uma instalação base.
if systemctl list-unit-files bluetooth.service &>/dev/null; then
  systemctl enable bluetooth
else
  warn "bluetooth.service ainda não existe (bluez vem na Fase 4) — ok, siga em frente."
fi

# --- 7. GPU (opcional — uma falha aqui NÃO aborta o bootstrap) ---------------
# NOTA: libva-mesa-driver/mesa-vdpau NÃO existem mais como pacotes separados;
# hoje o pacote 'mesa' já provê 'libva-mesa-driver'. NÃO os liste.
log "Detectando GPU e instalando drivers (opcional)"
pacman -S --needed --noconfirm mesa vulkan-icd-loader \
  || warn "Falha ao instalar mesa/vulkan — instale manualmente depois."

if lspci | grep -qiE 'vga.*nvidia|3d.*nvidia'; then
  log "GPU NVIDIA detectada"
  pacman -S --needed --noconfirm nvidia-open nvidia-utils nvidia-settings \
    || warn "Falha nos pacotes NVIDIA."
  echo 'options nvidia_drm modeset=1 fbdev=1' > /etc/modprobe.d/nvidia.conf
elif lspci | grep -qiE 'vga.*amd|vga.*ati'; then
  log "GPU AMD detectada"
  pacman -S --needed --noconfirm vulkan-radeon || warn "Falha nos pacotes AMD."
elif lspci | grep -qiE 'vga.*intel'; then
  log "GPU Intel detectada"
  pacman -S --needed --noconfirm vulkan-intel intel-media-driver || warn "Falha nos pacotes Intel."
else
  warn "Nenhuma GPU reconhecida por lspci (normal em VM) — siga em frente."
fi

# --- 8. zram (opcional) -------------------------------------------------------
log "Configurando zram (opcional)"
if pacman -S --needed --noconfirm zram-generator; then
  cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
else
  warn "zram-generator falhou — sistema fica sem swap em RAM."
fi

log "=============================================="
log "Bootstrap concluído."
log "Próximos passos:"
log "  1. exit"
log "  2. umount -R /mnt"
log "  3. reboot"
log "  4. 1º boot: configurar snapper/grub-btrfs (Fase 3 do guia)."
log "=============================================="
