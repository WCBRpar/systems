{
  config, pkgs, lib, ...
}:

{
  nixpkgs.overlays = [
    (final: prev: {
      # 1. Modificamos o conjunto de pacotes Python 3.12
      python312 = prev.python312.override {
        packageOverrides = pythonFinal: pythonPrev: {
          rlPyCairo = pythonPrev.buildPythonPackage ({
            pname = "rlPyCairo";
            version = "0.3.0";
            pyproject = true;

            src = prev.fetchhg {
              url = "https://hg.reportlab.com/hg-public/rlPyCairo";
              rev = "3c6cc9281052";
              hash = "sha256-KlGG1Qw/TYkq96cE2cwqftZKozprbbufh4xpWoXLOL8=";
            };

            build-system = [
              pythonPrev.setuptools
            ];

            dependencies = [
              pythonPrev.pycairo
              pythonFinal.new-freetype-py
            ];

            meta = {
              description = "Plugin backend renderer for reportlab.graphics.renderPM";
              homepage = "https://www.reportlab.com/";
              license = lib.licenses.bsd3;
            };
          });

          new-freetype-py = pythonPrev.freetype-py.overrideAttrs (old: {
            pname = "freetype-py";
            version = "2.3.0";
            pyproject = true;

            src = prev.fetchFromGitHub {
              owner = "rougier";
              repo = "freetype-py";
              rev = "v2.3.0";
              hash = "sha256-dZyULhsogicYniXRDaPFAq+tkGiG14SZsjM/raKtNxU=";
            };

            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pythonPrev.setuptools ];
          });
        };
      };

      # 2. Modificamos o odoo19 usando apenas overrideAttrs para evitar erros de argumentos inesperados
      odoo19 = prev.odoo19.overrideAttrs (old: {
        # Adicionamos as bibliotecas diretamente às dependências propagadas.
        # O Nix irá injetar estas bibliotecas no PYTHONPATH do wrapper do Odoo.
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          final.python312Packages.rlPyCairo
          final.python312Packages.new-freetype-py
        ];
      });
    })
  ];
}
