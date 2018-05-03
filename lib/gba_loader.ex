defmodule GbaLoader do
  def run(filename) do
    Nerves.Runtime.Helpers.cmd("killall -9 gba_loader")
    Nerves.Runtime.Helpers.cmd("#{priv_file("gba_loader")} #{filename}")
  end

  def priv_file(file) do
    Path.join(:code.priv_dir(:gba_loader), file)
  end
end
