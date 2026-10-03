{
  description = "KaraS: Japanese stenotype dictionary for Plover, packaged with plover-flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    plover-flake = {
      url = "github:opensteno/plover-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    karas = {
      url = "git+https://gitlab.com/kaede-work/KaraS.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      plover-flake,
      karas,
    }:
    let
      inherit (nixpkgs) lib;
      systems = lib.systems.flakeExposed;
      forEachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forEachSystem (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;

          karas-dictionary = pkgs.runCommand "karas-dictionary" { } ''
            install -Dm444 ${karas}/output/karas_main.json $out/share/karas/karas_main.json
          '';

          plover = plover-flake.packages.${system}.plover;

          # The config location can be overriden with `KARAS_PLOVER_DIR`.
          plover-karas = pkgs.writeShellApplication {
            name = "plover-karas";
            runtimeInputs = [ plover ];
            text = ''
              dir="''${KARAS_PLOVER_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/karas-plover}"
              mkdir -p "$dir"

              install -m644 ${karas-dictionary}/share/karas/karas_main.json "$dir/karas_main.json"

              [ -e "$dir/user.json" ] || printf '{}\n' >"$dir/user.json"
              [ -e "$dir/plover.cfg" ] || install -m644 ${./plover.cfg} "$dir/plover.cfg"

              echo "plover-karas: using config directory $dir" >&2
              cd "$dir"
              exec plover "$@"
            '';
          };
        in
        {
          inherit karas-dictionary plover plover-karas;
          default = plover-karas;
        }
      );

      apps = forEachSystem (pkgs: rec {
        default = plover-karas;
        plover-karas = {
          type = "app";
          program = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.plover-karas;
        };
      });

      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);
    };
}
