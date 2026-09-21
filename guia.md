# Guia: Arch Linux + Btrfs + Hyprland portável e recuperável

> **Objetivo:** processo limpo e reproduzível de instalação do Arch, usado primeiro numa
> VM QEMU/KVM, validado, e depois aplicado à máquina física. Preserva `Hyprland`, `Zsh` e
> `Kitty`. Migra para Btrfs com subvolumes, compressão, snapshots e rollback — com fallback
> seguro caso os dotfiles (R7rainz) quebrem tudo.

---

## 0. Decisões e premissas assumidas

Tudo o que não foi especificado foi decidido pela opção mais **robusta/reprodutível** e está
explicitado aqui. Ajuste antes de executar se discordar.

| Tema | Decisão (recomendada) | Alternativa |
|---|---|---|
| Bootloader | **GRUB** + `grub-btrfs` (permite *bootar em snapshot*) | `systemd-boot` (mais simples, mas sem boot em snapshot) |
| Snapshots | **snapper** + `snap-pac` + `grub-btrfs` (CLI, hook automático no pacman) | `timeshift` (GUI, menos scriptável) |
| Dotfiles próprios | **chezmoi** (multi-host, templates, secrets) | `stow` (simples; o rice R7rainz usa stow) |
| LUKS (criptografia) | **Sem LUKS** por padrão (mais simples e reproduzível). Seção opcional inclusa | LUKS2 + systemd-cryptenroll |
| Swap | **zram** (padrão) + swapfile Btrfs **opcional** p/ hibernação | partição swap dedicada |
| Rede | **NetworkManager** (desktop, Wi-Fi fácil) | systemd-networkd + iwd |
| Áudio | **PipeWire + WirePlumber** | PulseAudio |
| Display Manager | **SDDM** (funciona bem com Hyprland) | sem DM (login TTY + `Hyprland`) |
| Compressão | `compress=zstd:1` (equilíbrio) | `zstd:3` (mais economia, +CPU) |
| Microcódigo | `intel-ucode` **ou** `amd-ucode` (conforme CPU) | — |
| Particionamento | GPT: ESP + raiz Btrfs (+ LUKS opcional) | — |
| Subvolumes | `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`, `@swap`, `@tmp` | ajuste conforme necessidade |

> **Por que GRUB e não systemd-boot?** Seu requisito nº 4 é "rollback". O `grub-btrfs`
> adiciona cada snapshot como entrada no menu do GRUB, permitindo **bootar direto num snapshot
> anterior** quando o sistema quebra. Isso é recuperação de desastres real. O `systemd-boot`
> não tem esse recurso. O custo é uma configuração um pouco maior.

> **Por que snapper e não timeshift?** O snapper tem hook oficial de pacote (`snap-pac`) que
> tira snapshot **antes de cada `pacman -Syu`** automaticamente, integra com `grub-btrfs` e é
> 100% scriptável (essencial para reprodução). O timeshift é ótimo via GUI, mas menos adequado
> para automação headless.

---

## 1. Visão geral do fluxo

```
Fase 0  Backup do sistema atual (rede de segurança)
   │
Fase 1  VM QEMU/KVM: instalar Arch+Btrfs, testar dotfiles/nvim (sandbox)
   │
Fase 2  Instalação limpa do Arch+Btrfs (na VM e depois no físico)
   │
Fase 3  Snapshots + rollback + backup real
   │
Fase 4  Pós-instalação: GPU, áudio, Hyprland, Zsh, Kitty, Neovim
   │
Fase 5  Dotfiles portáteis + imagem reproduzível
```

**Regra de ouro:** tudo é validado primeiro na VM. A máquina física **só é tocada** depois
que a VM reproduzir o processo de ponta a ponta com sucesso.

> **Fallback:** se o `install.sh` falhar em algum hardware específico, use o `archinstall`
> (instalador oficial) — ver **Apêndice A**.

---

## 2. FASE 0 — Backup do sistema atual (antes de qualquer coisa)

Você vai testar os dotfiles do R7rainz. Se não gostar, quer formatar e **manter a sua
configuração atual**. Portanto, precisamos de um backup que permita restaurar seu ambiente
atual por completo. Estado detectado da sua máquina:

- Arch Linux, UEFI + GRUB, ESP em `/boot` (vfat).
- `/` em ext4 (`nvme1n1p2`, 47G, 90% cheio), `/home` em ext4 (`nvme1n1p3`, 422G).
- zram como swap, sem LUKS/LVM, dual boot Windows em `nvme0n1`.

### 2.1 O que capturar

| O quê | Por quê | Como |
|---|---|---|
| Lista de pacotes explícitos | reinstalar exatamente o que você usa | `pacman -Qqen` e `pacman -Qqem` |
| Serviços habilitados | reproduzir o boot | `systemctl list-unit-files --state=enabled` |
| `/etc` completo | configs do sistema (fstab, mkinitcpio, sudoers, etc.) | `rsync` |
| Dotfiles em `$HOME` | Hyprland, Zsh, Kitty, Neovim e o resto | `rsync` de `~/.config`, `~/.local`, `~/.zsh*`, `~/.bash*` |
| Segredos | não perder chaves | `~/.ssh`, `~/.gnupg`, gerenciador de senhas |
| Tabela de partições | restaurar layout exato | `sgdisk --backup` |
| `pacman.d`/chaves | evitar reimportar chaves | opcional |

### 2.2 Comandos (rode como root, destino = disco externo montado em `/mnt/backup`)

```bash
# 0) Monte um disco externo com espaço >= ~400 GB (o /home tem 287 GB usados)
#    Se o disco for ext4:  mount /dev/sdX1 /mnt/backup
#    Se for exFAT/NTFS (Windows): o rsync perde permissões/donos; prefira ext4.

BK=/mnt/backup/arch-$(date +%Y%m%d)
mkdir -p "$BK"

# 1) Lista de pacotes (nativo + AUR)
pacman -Qqen > "$BK/pacman-native.txt"
pacman -Qqem > "$BK/pacman-aur.txt"

# 2) Serviços habilitados
systemctl list-unit-files --state=enabled --no-pager > "$BK/enabled-services.txt"

# 3) Tabela de partições (backup binário do GPT)
sgdisk --backup="$BK/gpt-backup.bin" /dev/nvme1n1

# 4) Configs do sistema (preserva permissões, donos, xattrs, hardlinks)
rsync -aAXH --info=progress2 --numeric-ids \
  --exclude='/etc/pacman.d/gnupg' \
  /etc/ "$BK/etc/"

# 5) Segredos e dotfiles do seu usuário (rode como SEU usuário, não root)
rsync -aAXH --info=progress2 \
  ~/.ssh ~/.gnupg ~/.config ~/.local \
  ~/.zshrc ~/.zprofile ~/.zshenv ~/.zsh_history ~/.bashrc ~/.profile \
  "$BK/home-$USER/"

# 6) (Opcional mas recomendado) espelho do root via rsync — permite restaurar o sistema
rsync -aAXH --info=progress2 --numeric-ids --one-file-system \
  --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/var/cache/pacman/pkg/*"} \
  / "$BK/root/"

# 7) Validação: confira que os arquivos existem e que o espaço confere
du -sh "$BK"/*
```

### 2.3 Verificação do backup (não pule)

```bash
# Compare contagem de arquivos de um diretório crítico
diff <(find ~/.config -type f | sort) <(find "$BK/home-$USER/.config" -type f | sort)

# Teste de restauração em diretório temporário (não em produção)
mkdir -p /tmp/restore-test
rsync -aAXH "$BK/home-$USER/.config/kitty/" /tmp/restore-test/
ls -la /tmp/restore-test/
```

> ⚠️ **Um backup não testado não é backup.** Restaure pelo menos uma amostra antes de formatar
> qualquer coisa. Se possível, valide o restore completo numa VM/segundo disco.

---

## 3. FASE 1 — VM QEMU/KVM

### 3.1 Instalar a stack de virtualização (no host)

```bash
sudo pacman -S --needed qemu-desktop libvirt virt-manager edk2-ovmf \
  dnsmasq iptables virt-viewer

# Habilitar e iniciar o daemon
sudo systemctl enable --now libvirtd

# Colocar seu usuário nos grupos (relogue depois)
sudo usermod -aG libvirt,kvm "$USER"
```

> **Nota:** `edk2-ovmf` fornece o firmware UEFI (OVMF) — obrigatório para boot UEFI na VM.
> Use `qemu-full` se quiser todos os emuladores; `qemu-desktop` é o suficiente para uma VM de
> desktop.

### 3.2 Criar o disco da VM com CoW desabilitado (importante em host Btrfs)

Imagens de disco de VM dentro de um filesystem Btrfs devem ter **CoW desabilitado**, senão
sofrem fragmentação e perda de performance.

```bash
mkdir -p ~/vms
qemu-img create -f qcow2 -o preallocation=metadata ~/vms/arch-test.qcow2 60G

# Desabilita CoW (só funciona em arquivo vazio/recém-criado)
chattr +C ~/vms/arch-test.qcow2
# Verifique que 'C' aparece:
lsattr ~/vms/arch-test.qcow2
```

### 3.3 Criar a VM com UEFI, VirtIO e aceleração KVM

Opção A — via `virt-install` (recomendado, mais reproduzível):

```bash
# Baixe a ISO do Arch antes:
#   curl -LO https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

virt-install \
  --name arch-test \
  --memory 8192 --vcpus 4 \
  --cpu host-passthrough \
  --os-variant archlinux \
  --boot uefi,loader.secure=no \
  --disk path=$HOME/vms/arch-test.qcow2,format=qcow2,bus=virtio,cache=none \
  --cdrom $HOME/archlinux-x86_64.iso \
  --network network=default,model=virtio \
  --graphics spice,listen=none \
  --video virtio \
  --sound ich9 \
  --channel spicevmc \
  --autoconsole none
```

Opção B — via `virt-manager` (GUI):
1. **Create new VM** → *Import existing disk image* → aponte para a ISO.
2. Em *Customize configuration before install*:
   - **Overview → Firmware:** `UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.4m.fd` (**o "sem secure boot"**).
   - **Overview → Firmware → Secure Boot:** deixe **desmarcado** (ver nota abaixo).
   - **CPU:** `host-passthrough` (ou `host-model`).
   - **Disk bus:** `VirtIO`; **NIC:** `VirtIO`.
   - **Video:** `Virtio` (ou `QXL`); **Sound:** `ich9`; **Display:** `Spice`.
   - **Add Hardware → Channel** do tipo `spicevmc` (para clipboard/guest tools).

> **⚠️ Secure Boot: desligue sempre.** O `--boot uefi,loader.secure=no` (e o OVMF **sem**
> secure boot) evita o firmware `OVMF_CODE.secboot`. Com ele ligado, o firmware **recusa o
> GRUB do Arch** (não assinado) e você recebe *"No bootable option or device was found"*.
> Se já criou a VM com Secure Boot, desligue antes de instalar: `virt-manager` →
> Overview → Firmware → OVMF sem secure boot (ou recrie a VM).

> **Próximo passo obrigatório:** depois de criar a VM, você **instala o Arch dentro dela**
> (passo 3.4) antes de testar o Hyprland. É a mesma Fase 2 que depois rodará na máquina física.

### 3.4 Instalar o Arch dentro da VM (Fase 2)

> Este passo executa a **Fase 2 (seção 4)** dentro da VM, para validar o processo que depois
> será aplicado à máquina física. Use o `install.sh` — é ele que você quer testar.

**O disco da VM aparece como `/dev/vda`** (barramento VirtIO), e **não** como
`/dev/nvme0n1`. Confira com `lsblk` antes de rodar qualquer coisa:

```bash
# No live ISO, DENTRO da VM:
lsblk                              # confirme: vda (60G) + sr0 (ISO do Arch)
sudo bash install.sh /dev/vda      # ⚠️ apaga o disco da VM (que é descartável)
arch-chroot /mnt /root/bootstrap.sh
exit && umount -R /mnt && reboot
```

**Como levar os scripts para dentro da VM** (o ISO é read-only):

```bash
# Opção 1 — servidor HTTP no host (mais rápido). Primeiro, no HOST:
cd /home/mateus/arch-btrfs && python -m http.server 8000
# Depois, na VM (rede libvirt 'default'; o host é 192.168.122.1):
curl -O http://192.168.122.1:8000/install.sh
curl -O http://192.168.122.1:8000/bootstrap.sh

# Opção 2 — git (mais portável; vira sua "imagem base"):
#   git clone https://github.com/seu_usuario/arch-btrfs.git && cd arch-btrfs

# Opção 3 — disco de transferência (offline): crie uma imagem FAT no host, anexe como
#   2º disco virtio, monte no live ISO e copie os arquivos.
```

**Avisos específicos da VM (não são erro):**
- O `bootstrap.sh` vai avisar **"Nenhuma GPU reconhecida"** — normal: na VM a GPU é
  `virtio-gpu`, não Intel/AMD/NVIDIA. O `mesa` (instalado por ele) resolve o rendering.
- **Microcódigo** (`intel-ucode`/`amd-ucode`) é irrelevante no guest (o hypervisor aplica);
  instalar não faz mal.
- O `install.sh` valida UEFI; como a VM usa OVMF, essa checagem passa.

> **Só depois de bootar no sistema instalado** siga para o 3.5 (Hyprland) e, de preferência,
> configure a Fase 3 (snapshots) antes de aplicar os dotfiles.

### 3.5 Testar Hyprland dentro da VM (sem GPU real)

Hyprland em VM roda com **rendering por software**, lento mas suficiente para **validar
configuração**. Pontos-chave:

```bash
# Dentro da VM, após instalar Hyprland:
# Força software rendering se a aceleração falhar
export WLR_NO_HARDWARE_CURSORS=1
export LIBGL_ALWAYS_SOFTWARE=1
# opcional: WLR_RENDERER=pixman

# Iniciar Hyprland a partir do TTY (sem display manager)
Hyprland
```

- **Áudio na VM:** use o modelo `ich9` + PipeWire no guest.
- **Clipboard/redimensionamento:** instale `spice-vdagent` no guest e mantenha o channel `spicevmc`.
- **Valide CONFIG, não performance.** Animação pode travar; isso **não** indica problema no
  seu dotfile — indica falta de GPU. Para performance real, só com GPU passthrough (VFIO).

### 3.6 Estratégia de validação "sem quebrar nada"

| Recurso | Como usar |
|---|---|
| Snapshots da VM | `virsh snapshot-create-as arch-test antes-do-rice` → reverta em segundos |
| Usuário de teste | crie `tester` separado; aplique dotfiles só nele primeiro |
| `stow -n` (dry-run) | `stow -nvt ~ nome-do-pacote` mostra o que **faria** sem fazer |
| `chezmoi diff` | `chezmoi diff` mostra mudanças antes de aplicar |
| Git | versionar tudo; `git checkout` reverte |
| Boot em snapshot | teste real do rollback (Fase 3) |

### 3.7 Checklist de validação na VM

- [ ] Boot UEFI OK (verificar `efibootmgr` / firmware).
- [ ] Login gráfico (SDDM) e sessão Hyprland abrem.
- [ ] `echo $XDG_SESSION_TYPE` = `wayland`.
- [ ] Rede com/sem fio (NetworkManager) OK.
- [ ] Áudio (PipeWire) — `pw-cli info`, teste com `speaker-test`.
- [ ] Fontes Nerd carregadas (`fc-list | grep -i nerd`).
- [ ] Clipboard funciona (host↔guest via spice-vdagent).
- [ ] Portal XDG: `xdg-desktop-portal-hyprland` ativo (`systemctl --user status`).
- [ ] Screen sharing (portal) — testar OBS/Chromium.
- [ ] Temas/ícones/cursor aplicados.
- [ ] Atalhos do Hyprland respondem.
- [ ] LSP do Neovim inicia (`:LspInfo`, `:checkhealth`).

### 3.8 Troubleshooting da VM

**Sintoma: reboot volta para o instalador / "No bootable option or device was found".**
Duas causas, nesta ordem:

1. **Ordem de boot** — o CD/ISO vem antes do disco. Corrija (no host, VM desligada):
   ```bash
   virt-xml -c qemu:///system arch-test --edit --boot hd,cdrom
   ```
   (Se `virsh`/`virt-xml` reclamarem *"domain not found"*, use `-c qemu:///system` — é a
   conexão onde o `virt-install`/`virt-manager` registra as VMs do sistema.)

2. **Bootloader ausente** — o `bootstrap.sh` não completou o passo do GRUB. Confira na ESP:
   ```bash
   # do live ISO:
   mount -o subvol=@ /dev/vda2 /mnt && mount /dev/vda1 /mnt/boot
   ls /mnt/boot/EFI/GRUB/     # deve existir grubx64.efi
   ```
   Se não existir, o `bootstrap.sh` abortou antes. **Causa mais comum:** `pacman -S` falhando
   por nome de pacote inexistente (ex.: `libva-mesa-driver`/`mesa-vdpau`, hoje fundidos no
   `mesa`). Corrija os nomes e rode de novo — nesse caso faltam GRUB **e** partes do sistema:
   ```bash
   # do live ISO, com raiz e ESP montadas:
   arch-chroot /mnt /root/bootstrap.sh
   ```
   > Atalho: o script `recover.sh` faz isso sozinho — monta os subvolumes, baixa o
   > `bootstrap.sh` mais recente e roda no chroot (ver `README.md`).
   > O `bootstrap.sh` deste projeto instala o **bootloader antes** dos pacotes opcionais,
   > justamente para que uma falha de pacote não deixe o sistema sem boot.

3. **Secure Boot** ligado — bloqueia o GRUB (não assinado). Desligue (ver 3.3).

---

## 4. FASE 2 — Instalação limpa do Arch + Btrfs

> Use o script `install.sh` (entregue junto) para automatizar a parte do live ISO. A seguir o
> passo a passo manual equivalente, comentado.

### 4.1 Boot no live ISO e preparação

```bash
# Verificar modo de boot (deve imprimir '64' para UEFI)
cat /sys/firmware/efi/fw_platform_size

# Verificar rede
ping -c 3 archlinux.org

# Definir variáveis (AJUSTE!)
export DISCO=/dev/vda            # ou /dev/nvme0n1 no físico
export ESP="${DISCO}1"           # partição EFI
export RAIZ="${DISCO}2"          # partição raiz Btrfs
```

### 4.2 Particionamento GPT

> ⚠️ **PERIGO — apaga todo o disco.** Confirme o disco correto. `sgdisk --zap-all` destrói
> a tabela de partições e os dados.

```bash
# Destruir tabela antiga e criar GPT
sgdisk --zap-all "$DISCO"
sgdisk -o "$DISCO"

# EFI System Partition (>= 512 MiB; use 1 GiB p/ folga)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"ESP" "$DISCO"

# Raiz Btrfs (resto do disco)
sgdisk -n 2:0:0   -t 2:8300 -c 2:"root" "$DISCO"

# Recarregar
partprobe "$DISCO"
```

### 4.3 (Opcional) LUKS — criptografia da raiz

```bash
# Criar container LUKS2
cryptsetup luksFormat --type luks2 "$RAIZ"
cryptsetup open "$RAIZ" cryptroot

# A partir daqui, use /dev/mapper/cryptroot como "raiz"
RAIZ=/dev/mapper/cryptroot
```

> Se usar LUKS, adicione o hook `encrypt` no mkinitcpio e `cryptdevice=` na cmdline do kernel.
> (Detalhado no `bootstrap.sh`.)

### 4.4 Formatar e criar subvolumes

```bash
# ESP
mkfs.fat -F32 -n ESP "$ESP"

# Raiz Btrfs com label fixo (portabilidade)
mkfs.btrfs -L ARCHROOT "$RAIZ"

# Montar a raiz para criar os subvolumes
mount "$RAIZ" /mnt
cd /mnt

# Layout de subvolumes (padrão de mercado, estilo openSUSE/Fedora)
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @snapshots
btrfs subvolume create @var_log
btrfs subvolume create @var_cache
btrfs subvolume create @swap
btrfs subvolume create @tmp

cd /
umount /mnt
```

### 4.5 Montar com as opções recomendadas

```bash
# Opções base: noatime (menos escrita), compress=zstd:1, ssd, discard=async, space_cache=v2
OPTS="noatime,compress=zstd:1,ssd,discard=async,space_cache=v2"

mount -o "$OPTS,subvol=@"           "$RAIZ" /mnt

mkdir -p /mnt/{home,boot,.snapshots,var/log,var/cache,var/tmp,swap,tmp}

mount -o "$OPTS,subvol=@home"       "$RAIZ" /mnt/home
mount -o "$OPTS,subvol=@snapshots"  "$RAIZ" /mnt/.snapshots
mount -o "$OPTS,subvol=@var_log"    "$RAIZ" /mnt/var/log
mount -o "$OPTS,subvol=@var_cache"  "$RAIZ" /mnt/var/cache
mount -o "$OPTS,subvol=@swap"       "$RAIZ" /mnt/swap
mount -o "$OPTS,subvol=@tmp"        "$RAIZ" /mnt/tmp

# ESP
mkdir -p /mnt/boot
mount "$ESP" /mnt/boot
```

### 4.6 Instalar o sistema base

```bash
# -K inicializa a keyring do pacman (evita erro de assinatura)
pacstrap -K /mnt base linux linux-firmware btrfs-progs \
  networkmanager sudo vim base-devel git pciutils

# (adicione o microcódigo da SUA CPU:)
pacstrap /mnt intel-ucode   # OU amd-ucode

# Gerar fstab com UUIDs/labels
genfstab -U /mnt >> /mnt/etc/fstab

# Entrar no sistema
arch-chroot /mnt
```

> **Portabilidade:** o `genfstab -U` gera UUIDs. Para uma imagem que será clonada em outro
> disco, troque o UUID do filesystem Btrfs por `LABEL=ARCHROOT` (veja 4.8). O `bootstrap.sh`
> faz essa normalização.

### 4.7 Configuração base dentro do chroot

```bash
# Fuso horário e relógio
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "archvm" > /etc/hostname

# Usuário
useradd -m -G wheel -s /bin/zsh seu_usuario
passwd seu_usuario
EDITOR=vim visudo   # descomente: %wheel ALL=(ALL:ALL) ALL
```

### 4.8 Ajustar o fstab para portabilidade (labels)

```bash
# Edite /etc/fstab: troque o UUID= do filesystem Btrfs por LABEL=ARCHROOT
# Exemplo final (ajuste subvolumes e a ESP conforme seu caso):

# LABEL=ARCHROOT  /            btrfs  noatime,compress=zstd:1,ssd,discard=async,space_cache=v2,subvol=@           0 0
# LABEL=ARCHROOT  /home        btrfs  ...mesmas opções...,subvol=@home       0 0
# LABEL=ARCHROOT  /.snapshots  btrfs  ...mesmas opções...,subvol=@snapshots  0 0
# LABEL=ARCHROOT  /var/log     btrfs  ...mesmas opções...,subvol=@var_log    0 0
# LABEL=ARCHROOT  /var/cache   btrfs  ...mesmas opções...,subvol=@var_cache  0 0
# LABEL=ARCHROOT  /swap        btrfs  ...mesmas opções...,subvol=@swap       0 0
# LABEL=ARCHROOT  /tmp         btrfs  ...mesmas opções...,subvol=@tmp        0 0
# LABEL=ESP       /boot        vfat   umask=0077                            0 2
```

> **Trade-off:** `LABEL=` é amigável para clonar em outro disco (basta dar o mesmo label).
> `UUID=` é imune a colisão de labels. Para a "imagem base" portátil, `LABEL=` + `PARTUUID=`
> para a ESP é o equilíbrio recomendado. Em máquina de produção com um único disco, `UUID=` é
> mais conservador.

### 4.9 Initramfs e bootloader

O hook `filesystems` do mkinitcpio detecta Btrfs automaticamente (mantenha `btrfs-progs`
instalado). **Não** remova o hook `filesystems`.

```bash
# /etc/mkinitcpio.conf — exemplo de HOOKS (ordem importa)
# HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
#   -> remova 'autodetect' se quiser initramfs PORTÁTIL entre hardwares
#   -> adicione 'encrypt' antes de 'filesystems' SE usar LUKS

mkinitcpio -P
```

> **Portabilidade (importante):** o hook `autodetect` restringe os módulos do initramfs ao
> hardware atual — ótimo para boot rápido, **ruim para portabilidade**. Se o initramfs precisa
> rodar em outra máquina (seu objetivo nº 2), **remova `autodetect`**.

#### GRUB (recomendado) + grub-btrfs

```bash
pacman -S grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

> A integração com snapshots (`grub-btrfs`) é configurada na Fase 3.

#### systemd-boot (alternativa)

```bash
pacman -S efibootmgr
bootctl install
# Crie /boot/loader/loader.conf e /boot/loader/entries/arch.conf manualmente
# Lembrete: sem suporte a boot em snapshot.
```

### 4.10 Rede e serviços essenciais

```bash
systemctl enable NetworkManager
systemctl enable fstrim.timer   # TRIM para SSD/NVMe
```

---

## 5. FASE 3 — Snapshots, rollback e recuperação

### 5.1 Instalar e configurar snapper

```bash
pacman -S snapper snap-pac grub-btrfs

# Criar a config para o root (o subvolume @snapshots já está montado em /.snapshots)
snapper -c root create-config /

# (Opcional) config para /home
snapper -c home create-config /home
```

### 5.2 Política de retenção

Edite `/etc/snapper/configs/root`:

```ini
TIMELINE_CREATE="yes"            # snapshots periódicos (timeline)
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="2"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="10"               # no mínimo 10 snapshots
NUMBER_MIN_AGE="1800"
EMPTY_PRE_POST_CLEANUP="yes"
```

Habilite os timers:

```bash
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
```

### 5.3 Snapshot automático antes de atualizar

O pacote `snap-pac` já adiciona os hooks do pacman. Verifique:

```bash
ls /etc/pacman.d/hooks/          # deve listar 50-snapshot-*.hook
```

A partir de agora, **todo `pacman -Syu` cria um snapshot pré e pós** automaticamente.

### 5.4 Rollback

```bash
# Listar snapshots
snapper -c root list

# Rollback do root (cria um novo snapshot a partir do anterior)
snapper -c root rollback <NUMERO_DO_SNAPSHOT>

# Reverter um arquivo específico (sem rollback total)
snapper -c root undochange <ANTES>..<DEPOIS> /caminho/arquivo
```

**Bootar em snapshot (recuperação quando não boota):** com `grub-btrfs`, os snapshots aparecem
como entradas "Snapshots" no menu do GRUB. Escolha um, boote, e depois rode
`snapper rollback <n>` para tornar permanente.

> **ATENÇÃO:** após `snapper rollback`, **reinicie**. O rollback cria um novo subvolume
> `@` (read-write) e faz o sistema bootar dele; sem reboot você continua no antigo.

### 5.5 Backup real (fora do disco — não confie só em snapshot)

Snapshots protegem contra **erros lógicos** (update quebrado), mas **não** contra falha de
disco. Backup off-site/off-disk é obrigatório:

```bash
# btrfs send/receive (incremental, nativo, preserva subvolumes/snapshots)
btrfs send -p @snapshots_antigo @snapshots_novo | btrfs receive /mnt/backup/

# OU rsync (simples, universal)
rsync -aAXH --info=progress2 --exclude={"/.snapshots/*","/swap/*"} / /mnt/backup/root/

# OU restic (deduplicado + criptografado + repositório remoto)
restic -r /mnt/backup/restic init
restic -r /mnt/backup/restic backup / --exclude /.snapshots --exclude /swap
```

### 5.6 Recuperação de desastres (resumo)

Veja o arquivo `recuperacao-desastres.md` (entregue junto) para o checklist completo. Resumo:

1. Boot no live ISO.
2. Monte os subvolumes (mesma sequência da Fase 2).
3. Restaure com `btrfs send/receive` ou `rsync`.
4. Reinstale o bootloader (`grub-install` + `grub-mkconfig`).
5. Regenere o initramfs (`mkinitcpio -P`).
6. Reboot e valide.

---

## 6. FASE 4 — Pós-instalação e configurações essenciais

### 6.1 Drivers de GPU

```bash
# Base (todos)
sudo pacman -S mesa vulkan-icd-loader

# Intel
sudo pacman -S vulkan-intel intel-media-driver

# AMD
sudo pacman -S vulkan-radeon

# NVIDIA (proprietário) — para Hyprland prefira nvidia-open se suportado
sudo pacman -S nvidia-open nvidia-utils nvidia-settings
# NVIDIA (cards antigos): pacman -S nvidia
```

> **NVIDIA + Wayland:** habilite `nvidia_drm.modeset=1` e `nvidia_drm.fbdev=1` via
> `/etc/modprobe.d/nvidia.conf` + kernel cmdline. Veja a wiki "NVIDIA/Wayland".

### 6.2 Áudio (PipeWire + WirePlumber)

```bash
sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack
systemctl --user enable --now pipewire pipewire-pulse wireplumber
# Teste:  speaker-test -c2 -l1
```

### 6.3 Bluetooth, fontes, temas, ícones, cursor

```bash
sudo pacman -S bluez bluez-utils blueman
sudo systemctl enable --now bluetooth

# Fontes (inclui JetBrains Mono Nerd Font, usada no rice R7rainz)
sudo pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd noto-fonts noto-fonts-emoji

# Tema/ícones/cursor
sudo pacman -S papirus-icon-theme breeze-icons
# cursor: pacman -S xcursor-breeze  (ou bibata-cursor-theme do AUR)
```

### 6.4 Hyprland

```bash
sudo pacman -S hyprland hyprpaper hypridle hyprlock \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  polkit-kde-agent \
  waybar rofi dunst mako \
  grim slurp wl-clipboard \
  qt5-wayland qt6-wayland

# Autostart (sua porta de entrada no hyprland.conf)
#   exec-once = waybar
#   exec-once = hyprpaper
#   exec-once = /usr/lib/polkit-kde-authentication-agent-1
#   exec-once = xdg-desktop-portal -r (para recarregar portals em Wayland)
```

> **Portals:** confirme que `xdg-desktop-portal-hyprland` é o backend ativo
> (`systemctl --user status xdg-desktop-portal-hyprland`). Screen sharing/OBS dependem disso.

### 6.5 Zsh

```bash
sudo pacman -S zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting
chsh -s /bin/zsh "$USER"

# Prompt: escolha UM
#  - powerlevel10k (AUR): yay -S zsh-theme-powerlevel10k-git
#  - starship (oficial, leve): sudo pacman -S starship

# Exemplo de ~/.zshrc mínimo:
#   source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
#   source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#   eval "$(starship init zsh)"   # se usar starship
```

### 6.6 Kitty

```bash
sudo pacman -S kitty

# Exemplo ~/.config/kitty/kitty.conf
#   font_family      JetBrainsMono Nerd Font
#   font_size        12.0
#   background_opacity 0.92
#   # Tema Noctalia (do rice) via: include colors/Noctalia.toml
```

### 6.7 Neovim

```bash
sudo pacman -S neovim ripgrep fd git lazygit tree-sitter luarocks lua51 unzip

# Dependências de LSP (instale via Mason dentro do nvim, ou via pacman)
sudo pacman -S gopls rust-analyzer pyright clang typescript-language-server

# NvChad (base do config do R7rainz) OU clone direto do repo dele:
git clone https://github.com/R7rainz/neovim-conf ~/.config/nvim
nvim --headless "+Lazy! sync" +qa
```

> **Atenção:** o config do R7rainz exige **Neovim ≥ 0.12**. Se o pacote oficial estiver
> atrás, use `neovim-git` (AUR). Rode `:checkhealth` e `:LspInfo` para validar LSP/Treesitter.

---

## 7. FASE 5 — Dotfiles e portabilidade

### 7.1 Estratégia idempotente e reversível

- **chezmoi** (recomendado) — gerencia por arquivo-fonte, aplica em "camadas" e permite
  `chezmoi diff`, `chezmoi apply --dry-run` e rollback via git.
- **stow** (o rice R7rainz usa) — simples symlinks. Use `stow -n` para dry-run.

```bash
# chezmoi
sudo pacman -S chezmoi
chezmoi init https://github.com/seu_usuario/dotfiles.git
chezmoi diff      # ver antes de aplicar
chezmoi apply     # aplicar
```

### 7.2 Separação por host/perfil

```
dotfiles/
├── .chezmoi.toml.tmpl        # variáveis por máquina
├── hosts/
│   ├── notebook/
│   └── desktop/
├── common/                   # Hyprland, Zsh, Kitty (portáteis)
└── home/
    └── dot_config/
```

No `chezmoi`, use templates: `{{ if eq .chezmoi.hostname "notebook" }}...{{ end }}` para
variar monitor/GPU/teclado. Isso responde ao seu requisito de **não copiar config de hardware
específico**.

### 7.3 Secrets

| Opção | Quando usar |
|---|---|
| `pass` (gpg) | simples, git-friendly |
| `age` + `sops` | infra mais complexa, criptografia declarativa |
| 1Password/op CLI | se já usa o serviço |
| chezmoi + `age` | integrado: `chezmoi add --encrypt` |

```bash
# Exemplo com age no chezmoi
chezmoi age add-recipient ~/.ssh/id_ed25519.pub
chezmoi add --encrypt ~/.ssh/config   # vira .ssh/config.age
```

### 7.4 Script de bootstrap que detecta hardware

O `bootstrap.sh` (entregue) detecta GPU (Intel/AMD/NVIDIA) e instala o driver certo:

```bash
# dentro do bootstrap.sh
if lspci | grep -qi nvidia; then  pacman -S --needed nvidia-open nvidia-utils; fi
if lspci | grep -qi amd;    then  pacman -S --needed vulkan-radeon; fi
if lspci | grep -qi intel;  then  pacman -S --needed vulkan-intel intel-media-driver; fi
```

### 7.5 Transformar em imagem/instalador reproduzível

Ordem de complexidade (escolha conforme necessidade):

1. **Scripts** (`install.sh` + `bootstrap.sh` + `packages.txt`) — simples, transparente. ✅
2. **archiso customizado** — ISO do Arch que já inclui seus scripts/pacotes. (médio)
3. **Ansible** — provisionamento declarativo e idempotente. (médio-alto)

```bash
# archiso (opcional)
git clone https://gitlab.archlinux.org/archlinux/archiso
# adicione seus scripts em airootfs/root e pacotes em packages.x86_64
sudo mkarchiso -v .
```

---

## 8. Checklist final de validação (máquina física)

- [ ] Backup da Fase 0 completo **e testado** (restore de amostra OK).
- [ ] VM reproduziu o processo de ponta a ponta.
- [ ] Boot UEFI + GRUB com entradas de snapshots (`grub-btrfs`).
- [ ] `snapper list` mostra timeline; `pacman -Syu` criou snapshot pré/pós.
- [ ] Rollback testado (boot em snapshot → `snapper rollback` → reboot).
- [ ] Compressão ativa: `btrfs filesystem usage /` mostra `zstd`.
- [ ] `fstrim.timer` ativo; `systemctl list-timers` OK.
- [ ] Dual boot Windows preservado (se aplicável) — teste o boot do Windows.
- [ ] Hyprland/Zsh/Kitty/Neovim funcionais; LSP validado.
- [ ] Backup off-site/off-disk configurado (restic ou btrfs send).

---

## 9. Apêndice A — `archinstall` como fallback

### 9.1 O que é

O `archinstall` é o instalador oficial guiado (TUI) que já vem na ISO do Arch. Suporta
Btrfs, compressão zstd, LUKS, perfis de desktop (inclui **Hyprland**) e bootloader
GRUB/systemd-boot. No final do processo, **oferece salvar a configuração em JSON**, que pode
ser reutilizada para replicar a instalação.

### 9.2 Quando usar

- **Iteração rápida na VM (Fase 1)** — montar um ambiente em minutos para testar dotfiles.
- **Fallback** — quando o `install.sh` falha em hardware específico (firmware de BIOS
  problemático, NVMe exótico, controladora de disco estranha).
- **Validação cruzada** — comparar o layout Btrfs do `archinstall` com o do guia.

### 9.3 Uso guiado + salvar config

```bash
# No live ISO
archinstall

# Escolhas sugeridas na TUI:
#   - Discos: o disco alvo
#   - Filesystem: btrfs (com compressão zstd)
#   - Layout: 'Subvolumes' (aceite o padrão)
#   - Profile: 'Hyprland' (ou 'minimal' + pós-instalação manual)
#   - Bootloader: GRUB
#   - Network: NetworkManager
#   - Root password / usuário

# No final ele pergunta: "Save configuration?" → Yes
# Arquivos gerados:
#   /var/log/archinstall/user_configuration.json
#   /var/log/archinstall/user_credentials.json
```

### 9.4 Replayar a configuração

```bash
# Na mesma ou em outra máquina:
archinstall --config /var/log/archinstall/user_configuration.json \
            --creds  /var/log/archinstall/user_credentials.json

# Para outra máquina, edite antes os campos de disco no JSON
# (archinstall identifica o disco por modelo/tamanho, não por caminho fixo).
```

### 9.5 Segurança

- ⚠️ `user_credentials.json` **pode conter senha em texto plano**. Não o commite no git
  (adicione ao `.gitignore`) e rotacione senhas após usar.
- Se versionar o diretório de configs, mantenha `user_credentials.json` fora.

### 9.6 Mapeamento de layout (archinstall vs guia)

| archinstall (padrão) | Guia (este projeto) |
|---|---|
| `@` | `@` |
| `@home` | `@home` |
| `@.snapshots` (montado em `/.snapshots`) | `@snapshots` (montado em `/.snapshots`) |
| `@log` | `@var_log` |
| `@pkg` | `@var_cache` |
| — | `@swap` |
| — | `@tmp` |

Ambos funcionam com `snapper`/`grub-btrfs`; a diferença é só nomenclatura e granularidade.
Se instalar via `archinstall`, adapte o `bootstrap.sh` para o layout que ele criar (os
subvolumes já existirão; o snapper espera `/.snapshots`, que o `@.snapshots` atende).

### 9.7 Limitações para o seu objetivo

- **Acoplamento à versão da ISO:** o schema do JSON muda entre releases mensais; uma config de
  6 meses atrás pode não "replayar" limpo numa ISO nova.
- **Menos controle fino** das mount options (o script dá controle total de `noatime`,
  `discard=async`, nível de compressão, etc.).
- **Não faz a parte de dotfiles/Hyprland/Zsh/Kitty** — isso continua sendo `bootstrap.sh` +
  Fase 4/5, independente do instalador.

> **Veredito:** use o `archinstall` como *atalho de validação* e *plano B*. O script custom
> (`install.sh` + `bootstrap.sh`) é a fonte de verdade para o seu objetivo de processo
> reproduzível e portável.

---

## 10. Referências

- Arch Wiki: [Btrfs](https://wiki.archlinux.org/title/Btrfs),
  [Snapper](https://wiki.archlinux.org/title/Snapper),
  [Hyprland](https://wiki.archlinux.org/title/Hyprland),
  [Installation guide](https://wiki.archlinux.org/title/Installation_guide),
  [QEMU](https://wiki.archlinux.org/title/QEMU),
  [Mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio),
  [archinstall](https://wiki.archlinux.org/title/Archinstall),
  [grub-btrfs](https://github.com/Antynea/grub-btrfs)
- [chezmoi](https://www.chezmoi.io/), [R7rainz/dotfiles](https://github.com/R7rainz/dotfiles),
  [R7rainz/neovim-conf](https://github.com/R7rainz/neovim-conf)
