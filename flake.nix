{
  description = "Banana: a Wayland OpenGL terminal written in jihoo";

  inputs = {
    jihoo.url = "github:jihoolang/jihoo";
    nixpkgs.follows = "jihoo/nixpkgs";
  };

  outputs = { self, nixpkgs, jihoo }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      configFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          compiler = jihoo.packages.${system}.default;
          libraries = with pkgs; [ glfw libglvnd freetype fontconfig ];
          fonts = pkgs.makeFontsConf {
            fontDirectories = with pkgs; [
              jetbrains-mono dejavu_fonts noto-fonts-cjk-sans nerd-fonts.symbols-only
            ];
          };
          tools = with pkgs; [ compiler llvmPackages_21.clang pkg-config ncurses ];
        in { inherit pkgs compiler libraries fonts tools; };
    in {
      devShells = eachSystem (system:
        let c = configFor system; in {
          default = c.pkgs.mkShell {
            packages = c.tools ++ [ c.pkgs.bashInteractive c.pkgs.python3 c.pkgs.weston c.pkgs.wayland-utils ];
            buildInputs = c.libraries;
            FONTCONFIG_FILE = c.fonts;
            LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath c.libraries;
            # nix develop sets SHELL to the build-time Bash, which has no
            # Readline support and prints PS1's \[ and \] markers literally.
            shellHook = ''
              export SHELL=${c.pkgs.bashInteractive}/bin/bash
            '';
          };
        });

      packages = eachSystem (system:
        let c = configFor system; in {
          default = c.pkgs.stdenv.mkDerivation {
            pname = "banana";
            version = "0.2.0";
            src = c.pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = c.pkgs.lib.fileset.unions [
                ./src ./native ./include ./plugins ./shaders ./tests ./tools
                ./banana.terminfo ./banana.conf.example ./LICENSE
              ];
            };
            nativeBuildInputs = c.tools ++ [ c.pkgs.makeWrapper ];
            buildInputs = c.libraries;
            dontConfigure = true;
            buildPhase = "bash tools/build.sh";
            doCheck = true;
            checkPhase = "bash tools/test.sh";
            installPhase = ''
              install -Dm755 build/banana $out/bin/banana
              mkdir -p $out/share/banana $out/lib/banana
              cp -r build/terminfo $out/share/terminfo
              cp -r shaders $out/share/banana/shaders
              cp -r build/plugins $out/lib/banana/plugins
              install -Dm644 include/banana_plugin.h $out/include/banana_plugin.h
              install -Dm644 banana.conf.example $out/share/banana/banana.conf.example
              wrapProgram $out/bin/banana \
                --set-default FONTCONFIG_FILE ${c.fonts} \
                --set TERMINFO $out/share/terminfo
              install -Dm644 banana.terminfo $out/share/banana/banana.terminfo
            '';
            meta = {
              description = "A native Wayland OpenGL terminal written in jihoo";
              mainProgram = "banana";
              license = nixpkgs.lib.licenses.asl20;
              platforms = systems;
            };
          };
        });

      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/banana";
          meta.description = "Run the Banana Wayland terminal";
        };
      });

      checks = eachSystem (system: { banana = self.packages.${system}.default; });
    };
}
