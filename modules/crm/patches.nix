{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      odoo19 = prev.odoo19.overrideAttrs (oldAttrs: {
        # 1. Corrigimos o build-system: removemos distutils (que não existe no 3.12)
        build-system = with final.python312Packages; [
          setuptools
          wheel
        ];

        # 2. Atualizamos as dependências: trocamos pypdf2 por pypdf e adicionamos as novas
        dependencies = (oldAttrs.dependencies or [ ]) ++ (with final.python312Packages; [
          pypdf        # Odoo 17+ usa pypdf, não pypdf2
          reportlab
          pycairo
          
          # Ponte rlpycairo (inline)
          (buildPythonPackage rec {
            pname = "rlpycairo";
            version = "0.4.0";
            format = "setuptools";
            src = fetchPypi {
              inherit pname version;
              hash = "sha256-B8LDxHgo6D2cCWV6VOy80al6rJ3BmXgCNEVtNHP6rcc=";
            };
            propagatedBuildInputs = [ reportlab pycairo ];
            doCheck = false;
          })
        ]);

        # 3. Patch no setup.py: O Odoo 19 nightly tem scripts que chamam distutils
        # Vamos remover essas chamadas para que o wheel build funcione no Python 3.12
        postPatch = (oldAttrs.postPatch or "") + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py \
              --replace "from distutils.util import byte_compile" "" \
              --replace "byte_compile(files, prefix=prefix, base_dir=base_dir)" "pass" || true
          fi
        '';

        # 4. Desabilitamos a byte-compilação interna do pip que invoca o distutils
        pipInstallFlags = [ "--no-compile" ];
      });
    })
  ];
}

