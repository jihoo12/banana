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
            fontDirectories = [ pkgs.dejavu_fonts pkgs.noto-fonts-cjk-sans ];
          };
          tools = with pkgs; [ compiler llvmPackages_21.clang pkg-config ncurses ];
        in { inherit pkgs compiler libraries fonts tools; };
    in {
      devShells = eachSystem (system:
        let c = configFor system; in {
          default = c.pkgs.mkShell {
            packages = c.tools ++ [ c.pkgs.python3 c.pkgs.weston c.pkgs.wayland-utils ];
            buildInputs = c.libraries;
            FONTCONFIG_FILE = c.fonts;
            LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath c.libraries;
          };
        });

      packages = eachSystem (system:
        let c = configFor system; in {
          default = c.pkgs.stdenv.mkDerivation {
            pname = "banana";
            version = "0.1.0";
            src = c.pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = c.pkgs.lib.fileset.unions [
                ./src ./native ./tests ./tools ./banana.terminfo ./LICENSE
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
              mkdir -p $out/share
              cp -r build/terminfo $out/share/terminfo
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
