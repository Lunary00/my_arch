#!/usr/bin/env bash
# =============================================================================
# install.sh — particiona, formata (Btrfs), monta e instala o Arch base.
#
# Uso:   sudo bash install.sh /dev/nvme0n1
#
# ⚠️  DESTRUTIVO — apaga TODO o disco informado. Leia e confirme.
#
# Executar a partir do LIVE ISO do Arch, como root, com rede ativa.
# Ao final, copia o bootstrap.sh para /mnt/root/ e orienta o próximo passo.
# =============================================================================
set -euo pipefail

DISCO="${1:-}"
if [ -z "$DISCO" ]; then
  echo "Uso: $0 <DISCO>   (ex: /dev/nvme0n1)"
  exit 1
fi
[ "$(id -u)" -eq 0 ] || { echo "Rode como root."; exit 1; }
[ -f /sys/firmware/efi/fw_platform_size ] || { echo "Boot não é UEFI."; exit 1; }

# ============================ Variáveis (AJUSTE) ============================
CRYPT=0            # 1 = criptografa a raiz com LUKS2
ESP_SIZE="1G"      # tamanho da partição EFI (>= 512M; 1G dá folga)
MICROCODE="intel-ucode"   # "intel-ucode" | "amd-ucode"
# =============================================================================

echo "== Disco alvo =="
lsblk "$DISCO"
echo
read -r -p "⚠️  Isto APAGA todo o conteúdo de $DISCO. Digite o nome do disco para confirmar: " CONF
if [ "$CONF" != "${DISCO##*/}" ]; then
  echo "Abortado."
  exit 1
fi

ESP="${DISCO}1"
RAIZ="${DISCO}2"

# --- 1. Particionamento GPT -------------------------------------------------
echo "== Particionando (GPT) =="
sgdisk --zap-all "$DISCO"
sgdisk -o "$DISCO"
sgdisk -n "1:0:+${ESP_SIZE}" -t 1:ef00 -c 1:"ESP" "$DISCO"
sgdisk -n 2:0:0              -t 2:8300 -c 2:"root" "$DISCO"
partprobe "$DISCO"
sleep 2

# --- 2. LUKS opcional -------------------------------------------------------
if [ "$CRYPT" = "1" ]; then
  echo "== Criando container LUKS2 (defina a senha) =="
  cryptsetup luksFormat --type luks2 "$RAIZ"
  cryptsetup open "$RAIZ" cryptroot
  RAIZ=/dev/mapper/cryptroot
  echo "⚠️  Anote o UUID do cryptroot para a cmdline do kernel:"
  blkid "$RAIZ"
fi

# --- 3. Formatação ----------------------------------------------------------
echo "== Formatando =="
mkfs.fat -F32 -n ESP "$ESP"
mkfs.btrfs -L ARCHROOT "$RAIZ"

# --- 4. Subvolumes ----------------------------------------------------------
echo "== Criando subvolumes =="
mount "$RAIZ" /mnt
for s in @ @home @snapshots @var_log @var_cache @swap @tmp; do
  btrfs subvolume create "/mnt/$s"
done
umount /mnt

# --- 5. Montagem ------------------------------------------------------------
echo "== Montando =="
OPTS="noatime,compress=zstd:1,ssd,discard=async,space_cache=v2"
mount -o "$OPTS,subvol=@" "$RAIZ" /mnt
mkdir -p /mnt/{home,boot,.snapshots,var/log,var/cache,var/tmp,swap,tmp}
mount -o "$OPTS,subvol=@home"      "$RAIZ" /mnt/home
mount -o "$OPTS,subvol=@snapshots" "$RAIZ" /mnt/.snapshots
mount -o "$OPTS,subvol=@var_log"   "$RAIZ" /mnt/var/log
mount -o "$OPTS,subvol=@var_cache" "$RAIZ" /mnt/var/cache
mount -o "$OPTS,subvol=@swap"      "$RAIZ" /mnt/swap
mount -o "$OPTS,subvol=@tmp"       "$RAIZ" /mnt/tmp
mount "$ESP" /mnt/boot

# --- 6. pacstrap ------------------------------------------------------------
echo "== Instalando sistema base =="
pacstrap -K /mnt base linux linux-firmware btrfs-progs \
  networkmanager sudo vim base-devel git pciutils
pacstrap /mnt "$MICROCODE"

# --- 7. fstab ---------------------------------------------------------------
echo "== Gerando fstab =="
genfstab -U /mnt >> /mnt/etc/fstab
echo ">> DICA: para portabilidade, troque os UUID= do Btrfs por LABEL=ARCHROOT"
echo ">> (veja guia.md §4.8) ANTES do primeiro boot."

# --- 8. Copia o bootstrap para dentro do chroot -----------------------------
BOOTSTRAP_SRC="$(dirname "$0")/bootstrap.sh"
if [ ! -f "$BOOTSTRAP_SRC" ]; then
  echo "=============================================================="
  echo "ERRO: '$BOOTSTRAP_SRC' não encontrado."
  echo "O install.sh NÃO instala o bootloader sozinho — quem faz isso é o"
  echo "bootstrap.sh. Copie 'install.sh' E 'bootstrap.sh' para a MESMA pasta"
  echo "antes de rodar (ex.: git clone, ou baixe os dois)."
  echo "=============================================================="
  exit 1
fi
cp "$BOOTSTRAP_SRC" /mnt/root/bootstrap.sh
chmod +x /mnt/root/bootstrap.sh
echo ">> bootstrap.sh copiado para /mnt/root/bootstrap.sh"

echo
echo "=============================================="
echo "Próximo passo:"
echo "  arch-chroot /mnt /root/bootstrap.sh"
echo "=============================================="
