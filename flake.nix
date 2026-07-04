{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    nixosConfigurations.hot = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        ./configuration.nix
      ];
    };
  };
}