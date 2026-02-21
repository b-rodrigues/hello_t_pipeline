
{ pkgs ? import <nixpkgs> {} }:
let
  stdenv = pkgs.stdenv;
  t_lang_env = pkgs.stdenv;
in
rec {

  mtcars = stdenv.mkDerivation {
    name = "mtcars";
    buildInputs = [ t_lang_env  ];
    buildCommand = ''
      cat << EOF > node_script.t
EOF


      cat <<'EOF' >> node_script.t
      mtcars = read_csv("data/mtcars.csv", separator = "|")
      serialize(mtcars, "$out/artifact.tobj")
EOF
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };


  avg_mpg = stdenv.mkDerivation {
    name = "avg_mpg";
    buildInputs = [ t_lang_env mtcars ];
    buildCommand = ''
      export T_NODE_mtcars=${mtcars}
      cat << EOF > node_script.t
EOF

      echo 'mtcars = deserialize("$T_NODE_mtcars/artifact.tobj")' >> node_script.t
      cat <<'EOF' >> node_script.t
      avg_mpg = (mtcars.mpg |> mean)
      serialize(avg_mpg, "$out/artifact.tobj")
EOF
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };


  sd_mpg = stdenv.mkDerivation {
    name = "sd_mpg";
    buildInputs = [ t_lang_env mtcars ];
    buildCommand = ''
      export T_NODE_mtcars=${mtcars}
      cat << EOF > node_script.t
EOF

      echo 'mtcars = deserialize("$T_NODE_mtcars/artifact.tobj")' >> node_script.t
      cat <<'EOF' >> node_script.t
      sd_mpg = (mtcars.mpg |> sd)
      serialize(sd_mpg, "$out/artifact.tobj")
EOF
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };


  six_cyl = stdenv.mkDerivation {
    name = "six_cyl";
    buildInputs = [ t_lang_env mtcars ];
    buildCommand = ''
      export T_NODE_mtcars=${mtcars}
      cat << EOF > node_script.t
EOF

      echo 'mtcars = deserialize("$T_NODE_mtcars/artifact.tobj")' >> node_script.t
      cat <<'EOF' >> node_script.t
      six_cyl = (mtcars |> filter(($cyl == 6)))
      serialize(six_cyl, "$out/artifact.tobj")
EOF
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };


  avg_hp_6cyl = stdenv.mkDerivation {
    name = "avg_hp_6cyl";
    buildInputs = [ t_lang_env six_cyl ];
    buildCommand = ''
      export T_NODE_six_cyl=${six_cyl}
      cat << EOF > node_script.t
EOF

      echo 'six_cyl = deserialize("$T_NODE_six_cyl/artifact.tobj")' >> node_script.t
      cat <<'EOF' >> node_script.t
      avg_hp_6cyl = (six_cyl.hp |> mean)
      serialize(avg_hp_6cyl, "$out/artifact.tobj")
EOF
      mkdir -p $out
      t run --unsafe node_script.t
    '';
  };

  pipeline_output = stdenv.mkDerivation {
    name = "pipeline_output";
    buildInputs = [ mtcars avg_mpg sd_mpg six_cyl avg_hp_6cyl ];
    buildCommand = ''
      mkdir -p $out
      cp -r ${mtcars} $out/mtcars
      cp -r ${avg_mpg} $out/avg_mpg
      cp -r ${sd_mpg} $out/sd_mpg
      cp -r ${six_cyl} $out/six_cyl
      cp -r ${avg_hp_6cyl} $out/avg_hp_6cyl
    '';
  };
}
