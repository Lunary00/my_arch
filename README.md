<<<<<<< HEAD
# Arch + Btrfs + Hyprland — projeto de migração e instalação reproduzível

Processo limpo e reproduzível para instalar o **Arch Linux** com **Btrfs** (subvolumes,
compressão zstd, snapshots e rollback), preservando **Hyprland**, **Zsh** e **Kitty** — e com
**fallback seguro** caso os dotfiles do [R7rainz/dotfiles](https://github.com/R7rainz/dotfiles)
quebrem tudo.

> ⚠️ **Leia o `guia.md` antes de rodar qualquer script.** Os comandos de particionamento são
> destrutivos.

## Estrutura do projeto

| Arquivo | O que é |
|---|---|
| `guia.md` | Guia completo (Fases 0–5) + Apêndice A (fallback `archinstall`) |
| `install.sh` | Roda no **live ISO**: particiona, formata (Btrfs), monta e instala a base |
| `bootstrap.sh` | Roda no **chroot**: locale, usuário, GPU auto-detectada, bootloader, zram |
| `recover.sh` | Roda no **live ISO**: completa uma instalação que ficou sem bootloader |
| `packages.txt` | Lista de pacotes por categoria (base, GPU, Hyprland, Neovim, AUR) |
| `recuperacao-desastres.md` | Checklist de recuperação (3 cenários + prevenção) |

## Como usar em 10 linhas

```bash
# 1) FASE 0 — backup da máquina atual (rede de segurança). Ver guia.md §2.
# 2) FASE 1 — crie a VM QEMU/KVM para validar tudo. Ver guia.md §3.

# 3) No LIVE ISO do Arch (VM ou máquina física):
sudo bash install.sh /dev/nvme0n1     # ⚠️ apaga o disco inteiro

# 4) Configure o sistema (dentro do chroot):
arch-chroot /mnt /root/bootstrap.sh

# 5) Saia, desmonte e reinicie:
exit && umount -R /mnt && reboot

# 6) Pós-instalação (snapshots, Hyprland, Zsh, Kitty, Neovim): guia.md §5 e §6.
# 7) Dotfiles portáteis (chezmoi): guia.md §7.
# 8) Deu problema no boot? -> recuperacao-desastres.md
# 9) install.sh falhou num hardware estranho? -> guia.md Apêndice A (archinstall)
```

## O fluxo (resumo)

```
Fase 0  Backup (rede de segurança)
Fase 1  VM QEMU/KVM (sandbox p/ dotfiles/nvim)
Fase 2  Instalação limpa Arch + Btrfs   <- install.sh + bootstrap.sh
Fase 3  Snapshots + rollback + backup real
Fase 4  Pós: GPU / áudio / Hyprland / Zsh / Kitty / Neovim
Fase 5  Dotfiles portáteis + imagem reproduzível
```

## Decisões assumidas (detalhes no guia)

- **Bootloader:** GRUB + `grub-btrfs` (permite *bootar em snapshot*).
- **Snapshots:** snapper + `snap-pac` (snapshot automático antes de cada `pacman -Syu`).
- **Dotfiles:** `chezmoi` para os seus; `stow` para testar o rice R7rainz.
- **Sem LUKS** por padrão (opção de criptografia disponível no `install.sh`).
- **fstab por `LABEL=`** para portabilidade entre máquinas.
- **Fallback:** `archinstall` (instalador oficial) — Apêndice A.

## Pré-requisitos

- ISO do Arch Linux (UEFI).
- Disco externo (≥ 400 GB, ext4) para o backup da Fase 0.
- Rede ativa durante a instalação.
- No host de virtualização: `qemu-desktop libvirt virt-manager edk2-ovmf`.
=======
# my_arch
My arch linux guide
>>>>>>> 016229d6b8d15c730cc34d24b4cca700ecea95b2
