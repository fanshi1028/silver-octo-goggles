{
  inputs = {
    nixpkgs.url = "nixpkgs-unstable";
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nix-github-actions }:
    let ghcVersions = [ "98" "910" ];
    in {

      packages = builtins.mapAttrs (system: pkgs:
        let
          attrs = pkgs.lib.genAttrs ghcVersions (ghcVersion:
            pkgs.haskell.packages."ghc${ghcVersion}".developPackage {
              root = ./.;
              modifier = drv: pkgs.haskell.lib.appendConfigureFlag drv "-O2";
            });
        in attrs // { default = attrs."${builtins.head ghcVersions}"; })
        nixpkgs.legacyPackages;

      devShells = builtins.mapAttrs (system: pkgs:
        let
          attrs = pkgs.lib.genAttrs ghcVersions (ghcVersion:
            pkgs.haskell.packages."ghc${ghcVersion}".shellFor {
              packages = _: [ self.packages.${system}.default ];
              nativeBuildInputs = with pkgs; [
                (haskell-language-server.override {
                  supportedGhcVersions = [ ghcVersion ];
                  supportedFormatters = [ "ormolu" ];
                })
                cabal-install
                cabal2nix
                haskellPackages.cabal-fmt
                ghcid
              ];
              withHoogle = true;
            });
        in attrs // { default = attrs."${builtins.head ghcVersions}"; })
        nixpkgs.legacyPackages;

      checks = builtins.mapAttrs (system: pkgs:
        let
          devShellChecks = pkgs.lib.mapAttrs' (ghcVersion: value: {
            name = "${ghcVersion}-shell";
            inherit value;
          }) self.devShells.${system};
          packageChecks = pkgs.lib.mapAttrs' (ghcVersion: value: {
            name = "${ghcVersion}-package";
            inherit value;
          }) self.packages.${system};
        in packageChecks // devShellChecks) nixpkgs.legacyPackages;

      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = { inherit (self.checks) x86_64-linux x86_64-darwin; };
        platforms = {
          x86_64-linux = "ubuntu-22.04";
          x86_64-darwin = "macos-13";
        };
      };
    };

  nixConfig = {
    extra-substituters = [ "https://fanshi1028-personal.cachix.org" ];
    extra-trusted-public-keys = [
      "fanshi1028-personal.cachix.org-1:XoynOisskxlhrHM+m5ytvodedJdAo8gKpam/L6/AmBI="
    ];
  };
}
