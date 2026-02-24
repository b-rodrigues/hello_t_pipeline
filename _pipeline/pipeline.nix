
{ system ? builtins.currentSystem }:
let
  # Pull exact pinned inputs from the project flake.
  # The flake.lock guarantees reproducibility.
  # Note: toString is required to convert the path to a string
  # that builtins.getFlake accepts.
  flake  = builtins.getFlake (toString ../.);
  pkgs   = flake.inputs.nixpkgs.legacyPackages.${system};
  tBin   = (flake.inputs.t-lang or flake).packages.${system}.default;
  stdenv = pkgs.stdenv;

  # Filter out _pipeline/, .git/, and other non-source directories
  sources = builtins.filterSource
    (path: type:
      let baseName = builtins.baseNameOf path;
      in !(baseName == "_pipeline" || baseName == ".git" || baseName == ".direnv"))
    ./..;

  toml = if builtins.pathExists ../tproject.toml then builtins.fromTOML (builtins.readFile ../tproject.toml) else {};
  
  rPackagesList = toml.r-dependencies.packages or [];
  r-env = pkgs.rWrapper.override {
    packages = builtins.map (p: pkgs.rPackages.${p}) rPackagesList;
  };

  pyVersion = toml.py-dependencies.version or "python314";
  pyPackagesList = toml.py-dependencies.packages or [];
  py-env = pkgs.${pyVersion}.withPackages (ps: builtins.map (p: ps.${p}) pyPackagesList);
in
rec {

  raw_data = stdenv.mkDerivation {
    name = "raw_data";
    buildInputs = [ tBin  ];
    src = sources;
    buildCommand = ''
      cp -r $src/* . || true
      chmod -R u+w .
      cat << EOF > node_script.t
EOF

      echo 'import "src/iolib.t"' >> node_script.t

      cat <<'EOF' >> node_script.t
      raw_data = read_csv("data/mtcars.csv", separator = "|")
EOF
      echo "      t_write_csv(raw_data, \"$out/artifact\")" >> node_script.t
      echo "      write_text(\"$out/class\", type(raw_data))" >> node_script.t
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };


  summary_r = stdenv.mkDerivation {
    name = "summary_r";
    buildInputs = [ tBin r-env raw_data ];
    src = sources;
    buildCommand = ''
      cp -r $src/* . || true
      chmod -R u+w .
      export T_NODE_raw_data=${raw_data}
      cat << EOF > node_script.R
EOF

      echo "source('src/iolib.R')" >> node_script.R
      echo "raw_data <- r_read_csv(\"$T_NODE_raw_data/artifact\")" >> node_script.R
      cat <<'EOF' >> node_script.R
summary_r <- raw_data |> dplyr::group_by(cyl) |> dplyr::summarize(avg_mpg = mean(mpg))
EOF
      echo "r_write_csv(summary_r, \"$out/artifact\")" >> node_script.R
      echo "writeLines(as.character(class(summary_r)[1]), \"$out/class\")" >> node_script.R
      mkdir -p $out
      Rscript node_script.R
    '';
  };


  summary_py = stdenv.mkDerivation {
    name = "summary_py";
    buildInputs = [ tBin py-env raw_data ];
    src = sources;
    buildCommand = ''
      cp -r $src/* . || true
      chmod -R u+w .
      export T_NODE_raw_data=${raw_data}
      cat << EOF > node_script.py
EOF

      echo "exec(open('src/iolib.py').read())" >> node_script.py
      echo "raw_data = py_read_csv(\"$T_NODE_raw_data/artifact\")" >> node_script.py
      cat <<'EOF' >> node_script.py
summary_py = raw_data.groupby("cyl").mean()
EOF
      echo "py_write_csv(summary_py, \"$out/artifact\")" >> node_script.py
      echo "with open(\"$out/class\", \"w\") as f: f.write(type(summary_py).__name__)" >> node_script.py
      mkdir -p $out
      python node_script.py
    '';
  };


  final_results = stdenv.mkDerivation {
    name = "final_results";
    buildInputs = [ tBin summary_py summary_r ];
    src = sources;
    buildCommand = ''
      cp -r $src/* . || true
      chmod -R u+w .
      export T_NODE_summary_py=${summary_py}
      export T_NODE_summary_r=${summary_r}
      cat << EOF > node_script.t
EOF

      echo 'import "src/iolib.t"' >> node_script.t
      echo "summary_py = t_read_csv(\"$T_NODE_summary_py/artifact\")" >> node_script.t
      echo "summary_r = t_read_csv(\"$T_NODE_summary_r/artifact\")" >> node_script.t
      cat <<'EOF' >> node_script.t
      final_results = [r_part: summary_r, py_part: summary_py]
EOF
      echo "      serialize(final_results, \"$out/artifact\")" >> node_script.t
      echo "      write_text(\"$out/class\", type(final_results))" >> node_script.t
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };

  pipeline_output = stdenv.mkDerivation {
    name = "pipeline_output";
    buildInputs = [ tBin raw_data summary_r summary_py final_results ];
    buildCommand = ''
      mkdir -p $out
      cp -r ${raw_data} $out/raw_data
      cp -r ${summary_r} $out/summary_r
      cp -r ${summary_py} $out/summary_py
      cp -r ${final_results} $out/final_results
    '';
  };
}
