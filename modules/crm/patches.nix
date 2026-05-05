{
  config, pkgs, lib, ...
}:

{
  nixpkgs.overlays = [
    (final: prev: {
      odoo19 = prev.odoo19.overrideAttrs (old: {
        # Adiciona rlPyCairo e freetype-py ao ambiente Python do Odoo
        pythonImports = (old.pythonImports or []) ++ [
          final.python312Packages.rlPyCairo
          final.python312Packages.new-freetype-py # Usar o nome do overlay
        ];
      });

      python312Packages = prev.python312Packages.override (pythonPackagesFinal: pythonPackagesPrev: {
        rlPyCairo = pythonPackagesPrev.buildPythonPackage ({
          pname = "rlPyCairo";
          version = "0.3.0";
          pyproject = true;

          src = prev.fetchhg {
            url = "https://hg.reportlab.com/hg-public/rlPyCairo";
            rev = "3c6cc9281052";
            hash = "sha256-KlGG1Qw/TYkq96cE2cwqftZKozprbbufh4xpWoXLOL8=";
          };

          build-system = [
            pythonPackagesPrev.setuptools
          ];

          dependencies = [
            pythonPackagesPrev.pycairo
            pythonPackagesFinal.new-freetype-py
          ];

          meta = {
            description = "Plugin backend renderer for reportlab.graphics.renderPM";
            homepage = "https://www.reportlab.com/";
            license = lib.licenses.bsd3;
          };
        });

        # Novo nome para evitar conflitos e reconstruções desnecessárias
        new-freetype-py = pythonPackagesPrev.freetype-py.overrideAttrs (old: {
          pname = "freetype-py";
          version = "2.3.0";
          pyproject = true;

          src = prev.fetchFromGitHub {
            owner = "rougier";
            repo = "freetype-py";
            rev = "v2.3.0";
            hash = "sha256-dZyULhsogicYniXRDaPFAq+tkGiG14SZsjM/raKtNxU=";
          };

          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pythonPackagesPrev.setuptools ];
        });
      });
    })
  ];
}

