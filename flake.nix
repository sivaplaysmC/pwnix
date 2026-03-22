{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  # Upstream pwndbg flake. We DON'T make it follow our nixpkgs,
  # so it runs with the versions it pins (via the app).
  inputs.pwndbg.url = "github:pwndbg/pwndbg";

  outputs =
    { nixpkgs, pwndbg, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      pythonEnv = pkgs.python3.withPackages (
        ps: with ps; [
          angr
          capstone
          # qiling
          pip
          ruff
          pycryptodome
          gmpy2
          z3-solver
          sympy
          pwntools
          ropper
          ropgadget
          requests
          scapy
          pillow
          numpy
          ipython
          ipdb
          r2pipe
        ]
      );

      rubyEnv = pkgs.ruby.withPackages (
        ps: with ps; [
          one_gadget
          seccomp-tools
        ]
      );

      qemuNogui = pkgs.qemu.override {
        gtkSupport = false;
        sdlSupport = false;
        openGLSupport = false;
        virglSupport = false;
        spiceSupport = false;
        vncSupport = false;

        alsaSupport = false;
        pulseSupport = false;

        pipewireSupport = false;
        jackSupport = false;

        usbredirSupport = true;
        libiscsiSupport = true;
        capstoneSupport = true;

        tpmSupport = false;
        guestAgentSupport = false;
        pluginsSupport = true;


        toolsOnly = false;
        userOnly = false;
        hostCpuOnly = false;
      };

      # Wrapper that runs the *pwndbg app* from the upstream flake in its own closure.
      # This avoids mixing with your shell's Python/capstone.
      system = "x86_64-linux";
      pwndbg-pkg = pwndbg.packages.${system}.pwndbg;

      env = pkgs.buildEnv {
        name = "pwnix-env";
        paths = [
          # Python
          pythonEnv
          pkgs.pyrefly

          # Ruby tools
          rubyEnv

          # Reversing / Binary analysis
          pkgs.binutils
          pkgs.elfutils
          pkgs.coreutils
          pkgs.patchelf
          pkgs.file
          pkgs.xxd
          pkgs.clang-tools
          pkgs.radare2
          pkgs.unblob
          pkgs.binwalk
          pkgs.pahole
          pwndbg-pkg


          # Debugging
          pkgs.strace
          pkgs.ltrace
          pkgs.rr

          # Exploitation
          pkgs.pwninit

          # Network
          pkgs.socat
          pkgs.nmap
          pkgs.netcat-openbsd
          pkgs.wget
          pkgs.curl
          pkgs.openssh


          # Emulation / Virtualization
          pkgs.qemu
          pkgs.vmlinux-to-elf
          # qemuNogui

          # Compression / Archives
          pkgs.xz
          pkgs.unar
          pkgs.zip
          pkgs.unzip
          pkgs.gnutar
          pkgs.gzip
          pkgs.cpio


          # Shell / Utils
          pkgs.cacert
          pkgs.tmux
          pkgs.fd
          pkgs.ripgrep
          pkgs.jq
          pkgs.gcc
          pkgs.yazi
          pkgs.neovim
          pkgs.zsh
          pkgs.git
          pkgs.fzf
          pkgs.ncurses
          pkgs.util-linux
          pkgs.perf
          pkgs.tree-sitter
          pkgs.procps
          pkgs.gawk
          pkgs.which
          pkgs.less
          pkgs.gnused
          pkgs.gnugrep
        ];

      };
      pwnix = pkgs.writeShellScriptBin "pwnix" ''
        cat > "$PWNIX_MANIFEST" <<EOF
        {
          "zsh":            "${pkgs.zsh}/bin/zsh",
          "bash":           "${pkgs.bash}/bin/bash",
          "env-path":       "${env}/bin:/bin:/usr/bin",
          "env-store-path": "${env}"
        }
        EOF
        ${pkgs.bwrap}/bin/bwrap \
            --overlay-src "$PWNIX_ROOTFS/" \
            --overlay "$PWNIX_UPPER_DIR" "$PWNIX_WORK_DIR" / \
            --dev /dev \
            --proc /proc \
            --tmpfs /tmp \
            --bind "$PWD" /root/work \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --unshare-all \
            --share-net \
            --uid 0 --gid 0 \
            --ro-bind /nix /nix \
            --new-session \
            --hostname "$PWNIX_HOSTNAME" \
            --clearenv \
            --setenv LANG "C.UTF-8" \
            --setenv LC_ALL "C.UTF-8" \
            --setenv HOME "/root" \
            --setenv TERM "$TERM" \
            --setenv SHELL ${pkgs.zsh}/bin/zsh \
            --setenv PATH "${env}/bin:/bin:/usr/bin" \
            --ro-bind ${pkgs.bash}/bin/bash /bin/sh \
            --ro-bind ${pkgs.zsh}/bin/zsh /bin/zsh \
            --info-fd 9 \
            -- /bin/sh -c '
        cat > /etc/hosts <<EOF3
        127.0.0.1   localhost
        127.0.0.1   $PWNIX_HOSTNAME
        ::1         localhost
        EOF3
        cat > /etc/zprofile <<EOF2
        export LANG="C.UTF-8"
        export LC_ALL="C.UTF-8"
        export HOME=/root
        export TERMINFO_DIRS="${pkgs.ncurses}/share/terminfo"   # for pwndbg
        export TERM="xterm-256color"                            # for pwndbg too
        export SHELL=${pkgs.zsh}/bin/zsh
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt # for curl
        export PATH=${env}/bin:/bin:/usr/bin                            # for all utils
        EOF2
        exec sleep infinity
        ' 9>"$PWNIX_INFO" &
      '';
    in
    {
      packages.x86_64-linux.default = pwnix;
    };
}


# vim:sw=2
