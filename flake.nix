{
  description = "InputLeap";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { nixpkgs, ... } @ inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      makePackage = pkgs: import ./input-leap.nix {
        inherit pkgs;
        inherit (pkgs) stdenv fetchFromGitHub;
      };
    in
    {
      overlays = {
        default = final: prev: {
          input-leap = makePackage prev;
        };
      };
      packages = forAllSystems (system:
        let
          pkgs = (import nixpkgs { inherit system; });
        in
        rec {
          input-leap = makePackage pkgs;
          default = input-leap;
        });
    };

}
