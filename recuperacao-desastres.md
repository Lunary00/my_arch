# Checklist de Recuperação de Desastres

> Guarde este arquivo **fora** do disco principal (junto com o backup). Ele assume o layout
> do `guia.md`: subvolumes `@ @home @snapshots @var_log @var_cache @swap @tmp`, ESP em `/boot`,
> GRUB + grub-btrfs, snapper.

---

## Cenário A — Sistema não boota, mas o disco está OK

1. No menu do GRUB, entre em **"Snapshots"** (entradas criadas pelo `grub-btrfs`).
2. Escolha um snapshot anterior ao problema e boote.
3. Se o sistema subir bem, torne-o permanente:
   ```bash
   sudo snapper -c root rollback <NUMERO_DO_SNAPSHOT>
   sudo reboot
   ```
4. Se foi um pacote específico que quebrou, reverta só o que precisa:
   ```bash
   sudo pacman -U /var/cache/pacman/pkg/<pacote-antigo>.pkg.tar.zst
   ```

---

## Cenário B — GRUB/initramfs corrompidos, disco OK

1. Boot no **live ISO** do Arch.
2. Monte a raiz e os subvolumes:
   ```bash
   OPTS="noatime,compress=zstd:1,ssd,discard=async,space_cache=v2"
   # se usar LUKS: cryptsetup open /dev/<raiz> cryptroot && RAIZ=/dev/mapper/cryptroot
   RAIZ=/dev/nvme0n1p2          # AJUSTE
   ESP=/dev/nvme0n1p1           # AJUSTE

   mount -o "$OPTS,subvol=@" "$RAIZ" /mnt
   mount -o "$OPTS,subvol=@home"      "$RAIZ" /mnt/home
   mount -o "$OPTS,subvol=@snapshots" "$RAIZ" /mnt/.snapshots
   mount -o "$OPTS,subvol=@var_log"   "$RAIZ" /mnt/var/log
   mount -o "$OPTS,subvol=@var_cache" "$RAIZ" /mnt/var/cache
   mount -o "$OPTS,subvol=@swap"      "$RAIZ" /mnt/swap
   mount -o "$OPTS,subvol=@tmp"       "$RAIZ" /mnt/tmp
   mount "$ESP" /mnt/boot
   ```
3. Entre no sistema e reinstale o bootloader:
   ```bash
   arch-chroot /mnt
   grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
   grub-mkconfig -o /boot/grub/grub.cfg
   mkinitcpio -P
   exit
   ```
4. `umount -R /mnt` e `reboot`.

---

## Cenário C — Disco morto / troca de disco (restauração completa)

1. Instale um disco novo e rode o `install.sh` (recria a base + subvolumes + bootloader).
2. Monte o backup externo (disco ext4/restic/btrfs).
3. Restaure conforme o método de backup escolhido:

   **Se usou `btrfs send/receive`:**
   ```bash
   mount "$RAIZ" /mnt
   btrfs receive /mnt < /caminho/do/backup/<subvolume>
   # repita para @, @home, etc.
   ```

   **Se usou `rsync`:**
   ```bash
   mount -o subvol=@ "$RAIZ" /mnt
   rsync -aAXH --info=progress2 /mnt/backup/root/ /mnt/
   rsync -aAXH --info=progress2 /mnt/backup/home/ /mnt/home/
   ```

   **Se usou `restic`:**
   ```bash
   restic -r /mnt/backup/restic restore latest --target /mnt
   ```

4. Restaure os dotfiles:
   ```bash
   chezmoi init --apply https://github.com/seu_usuario/dotfiles.git
   # ou: rsync -aAXH /mnt/backup/home-$USER/ ~/
   ```

5. `arch-chroot /mnt /root/bootstrap.sh` (usuário, GPU, bootloader, mkinitcpio).

---

## Checklist pós-restauração

- [ ] Boot UEFI + GRUB com entradas de snapshots visíveis
- [ ] `snapper -c root list` funciona
- [ ] `btrfs filesystem usage /` saudável (sem erro, compressão zstd ativa)
- [ ] Rede (NetworkManager) e áudio (PipeWire) OK
- [ ] Hyprland abre e `echo $XDG_SESSION_TYPE` = `wayland`
- [ ] Dual boot Windows preservado (teste o boot)
- [ ] Backup agendado rodando (`systemctl list-timers` / crontab)

---

## Prevenção (rotina mensal)

- [ ] `snap-pac` ativo (snapshot automático antes de `pacman -Syu`)
- [ ] `snapper-cleanup.timer` ativo (evita disco cheio de snapshots)
- [ ] Backup off-disk semanal (restic / btrfs send)
- [ ] **Testar a restauração 1x/mês** (restore de amostra)
- [ ] Revisar `pacman -Qtdq` (órfãos) e `journalctl --vacuum-size=100M`

---

## Contatos / referências rápidas

- Particionamento: `guia.md` §4.2
- Montagem/subvolumes: `guia.md` §4.4–4.5
- Snapshots/rollback: `guia.md` §5
- Fallback `archinstall`: `guia.md` Apêndice A
