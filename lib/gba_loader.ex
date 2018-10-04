defmodule GbaLoader do
  require Logger

  def pork do
    # upload(priv_file("porker_mb.gba"))  
    run(priv_file("porker_mb.gba"))  
  end

  def run(filename) do
    Nerves.Runtime.Helpers.cmd("killall -9 gba_loader")
    Nerves.Runtime.Helpers.cmd("#{priv_file("gba_loader")} #{filename}")
  end

  def priv_file(file) do
    Path.join(:code.priv_dir(:gba_loader), file)
  end

  use Bitwise
  alias ElixirALE.SPI

  def upload(file) do
    if GenServer.whereis(:gba_spi) do
      SPI.release(:gba_spi)
    end
    
    f = File.open!(file)
    {:ok, pos} = :file.position(f, :eof)
    fsize = (pos + 0x0f) &&& 0xfffffff0
    File.close(f)
    data = File.read!(file)

    # fsize = byte_size(data)
    if fsize > 0x40000 do
      raise "Err: Max file size 256KB"
    end

    IO.inspect(fsize, label: "fsize", base: :hex)

    {:ok, _spi} = SPI.start_link("spidev0.0", [mode: 3, speed_hz: 100000], [name: :gba_spi])
    wait_spi32(0x00006202, 0x72026202, "Looking for GBA")
    r = write_spi32(0x00006202, "Found GBA")
    r = write_spi32(0x00006102, "Recognition OK")
    IO.puts("Send Header(NoDebug)")
    <<header :: binary-size(0x5f), rest :: binary>> = data
    fcnt = write_header(header)
    
    r = write_spi32(0x00006200, "Transfer of header data complete")
    r = write_spi32(0x00006202, "Exchange master/slave info again")
    r = write_spi32(0x000063d1, "Send palette data")
    r = write_spi32(0x000063d1, "Send palette data, receive 0x73hh****")
    
    m = ((r &&& 0x00ff0000) >>>  8) + 0xffff00d1
    h = ((r &&& 0x00ff0000) >>> 16) + 0xf
    
    r = write_spi32((((r >>> 16) + 0xf) &&& 0xff) ||| 0x00006400, "Send handshake data")
    r = write_spi32(round((fsize - 0x190) / 4), "Send length info, receive seed 0x**cc****")

    f = (((r &&& 0x00ff0000) >>> 8) + h) ||| 0xffff0000;
    c = 0x0000c387;
    
    IO.puts("Send encrypted data(NoDebug)")

    write_data(rest, fcnt, fsize, c, m)
    
    {c, _} = crc(c, f)
    
    wait_spi32(0x00000065, 0x00750065, "Wait for GBA to respond with CRC")

    r = write_spi32(0x00000066, "GBA ready with CRC")
    r = write_spi32(c,          "Let's exchange CRC!")
    IO.puts("CRC ...hope they match!")
    IO.puts("MulitBoot done")
  end

  def crc(c, f, bit \\ 0)
  def crc(c, f, bit) when bit < 32 do
    c = if ((c ^^^ f) &&& 0x01) do
      (c >>> 1) ^^^ 0x0000c37b
    else
      c >>> 1
    end
    crc(c, f >>> 1, bit+1)
  end
  def crc(c, f, _), do: {c, f}
  
  defp write_data(rest, fcnt, fsize, c, m)
  defp write_data(<<w, rest :: binary>>, fcnt, fsize, c, m) when fcnt < fsize do
    IO.inspect(c, label: "c")
    IO.inspect(m, label: "m")
    IO.inspect(fcnt, label: "fcnt")
    IO.inspect(fsize, label: "fsize")

    <<x, rest :: binary >> = rest
    w = x <<< 8 ||| w

    <<y, rest :: binary >> = rest
    w = y <<< 16 ||| w

    <<z, rest :: binary >> = rest
    w = z <<< 24 ||| w

    w2 = w

    {c, w} = crc(c, w)
    m = (0x6f646573 * m) + 1
    write_spi32(w2 ^^^ ((~~~(0x02000000 + fcnt)) + 1) ^^^ m ^^^ 0x43202f2f)
    write_data(rest, fcnt + 4, fsize, c, m)
  end

  defp write_data(_, _fcnt, _fsize, c, _), do: c 

  defp write_header(rest, fcnt \\ 0)

  defp write_header(<<>>, fcnt), do: fcnt
  
  defp write_header(<<w, rest :: binary>>, fcnt) do
    case rest do
      <<x, rest :: binary>> ->
        w = x <<< 8 ||| w
        _r = write_spi32(w)
        write_header(rest, fcnt+2)
      <<>> -> fcnt
    end
  end

  defp wait_spi32(w, comp, msg) do
    msg && IO.puts(msg)
    if write_spi32(w) != comp do
      Process.sleep(10)
      wait_spi32(w, comp, nil)
    end
  end

  defp write_spi32(w, msg \\ nil) do
    data = <<
      (w &&& 0xff000000) >>> 24,
      (w &&& 0x00ff0000) >>> 16,
      (w &&& 0x0000ff00) >>>  8,
      (w &&& 0x000000ff) 
    >>

    <<buf0, buf1, buf2, buf3>> = SPI.transfer(:gba_spi, data)
    r = 0
    r = r + (buf0 <<< 24)
    r = r + (buf1 <<< 16)
    r = r + (buf2 <<< 8)
    r = r + buf3

    # IO.inspect(r, label: "r", base: :hex)
    # IO.inspect(w, label: "w", base: :hex)

    msg && IO.puts(msg)

    r
  end
end
