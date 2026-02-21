-- hello_t_pipeline — demo pipeline
--
-- Run with: t run src/pipeline.t

p = pipeline {
  -- Load mtcars data (pipe-separated)
  mtcars = read_csv("data/mtcars.csv", separator = "|")

  -- Basic stats on miles per gallon
  avg_mpg = mtcars.mpg |> mean
  sd_mpg  = mtcars.mpg |> sd

  -- Filter to 6-cylinder cars
  six_cyl = mtcars |> filter($cyl == 6)

  -- Average horsepower of 6-cyl cars
  avg_hp_6cyl = six_cyl.hp |> mean
}

build_pipeline(p)
