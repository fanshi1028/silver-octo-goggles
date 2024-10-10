{
  inputs = {
    nixpkgs.url = "nixpkgs-unstable";
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nix-github-actions }:
    let
      ghcVersion = "98";
      mkHsPackage = pkgs: pkgs.haskell.packages."ghc${ghcVersion}";
    in {

      packages = builtins.mapAttrs (system: pkgs: {
        default = ((mkHsPackage pkgs).developPackage {
          root = ./.;
          modifier = drv: pkgs.haskell.lib.appendConfigureFlag drv "-O2";
        });
      }) nixpkgs.legacyPackages;

      devShells = builtins.mapAttrs (system: pkgs:
        with pkgs;
        let hsPackage = mkHsPackage pkgs;
        in {
          default = hsPackage.shellFor {
            packages = _: [ self.packages.${system}.default ];
            nativeBuildInputs = with pkgs;
              [
                (haskell-language-server.override {
                  supportedGhcVersions = [ ghcVersion ];
                  supportedFormatters = [ "ormolu" ];
                })
                # cabal-install
                # cabal2nix
                # haskellPackages.cabal-fmt
                # ghcid
              ];
            withHoogle = false;
          };
        }) nixpkgs.legacyPackages;

      checks = builtins.mapAttrs (system: pkgs:
        with pkgs; {
          default = self.packages.${system}.default;
          shell = self.devShells.${system}.default;
        }) nixpkgs.legacyPackages;

      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks =
          builtins.mapAttrs (_: checks: { inherit (checks) default shell; }) {
            inherit (self.checks) x86_64-linux x86_64-darwin;
          };
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
