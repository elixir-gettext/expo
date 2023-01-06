defmodule Mix.Tasks.Expo.MsgfmtTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expo.Messages
  alias Expo.MO
  alias Mix.Tasks.Expo.Msgfmt

  setup do
    temp_file = Path.join(System.tmp_dir!(), make_ref() |> :erlang.phash2() |> to_string())

    on_exit(fn -> File.rm(temp_file) end)

    {:ok, temp_file: temp_file}
  end

  test "exports mo to console" do
    po_path = "test/fixtures/po/valid.po"

    # Latin1 Encoding is needed so that the binary is untouched
    # and does not actually mean latin1.
    out =
      capture_io([encoding: :latin1], fn ->
        Msgfmt.run([po_path])
      end)

    assert {:ok, _parsed} = MO.parse_binary(out)
  end

  test "exports mo to file", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/valid.po"

    Msgfmt.run([po_path, "--output-file=#{temp_file}"])

    assert {:ok, _parsed} = MO.parse_file(temp_file)
  end

  test "shows statistics", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/valid.po"

    stderr =
      capture_io(:standard_error, fn ->
        Msgfmt.run([po_path, "--output-file=#{temp_file}", "--statistics"])
      end)

    assert stderr =~ "1 translated messages."
  end

  test "exports fuzzy when asked", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/valid.po"

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--use-fuzzy"])

    assert {:ok, %Messages{messages: [_one, _two]}} = MO.parse_file(temp_file)
  end

  test "errors with missing file" do
    assert_raise Mix.Error, "mix expo.msgfmt failed due to missing po file path argument\n", fn ->
      Msgfmt.run(["--statistics"])
    end
  end

  test "errors with multiple files" do
    assert_raise Mix.Error,
                 "mix expo.msgfmt failed due to multiple po file path arguments\nOnly one is currently supported\n",
                 fn ->
                   Msgfmt.run(["file_one", "file_two", "--statistics"])
                 end
  end

  test "checks valid endianness", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/valid.po"

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--endianness=little"])
    assert {:ok, _parsed} = MO.parse_file(temp_file)

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--endianness=big"])
    assert {:ok, _parsed} = MO.parse_file(temp_file)

    assert_raise Mix.Error,
                 "mix expo.msgfmt failed due to invalid endianness option\nExpected: \"little\" or \"big\"\nReceived: \"invalid\"\n",
                 fn ->
                   Msgfmt.run([
                     po_path,
                     "--output-file=#{temp_file}",
                     "--endianness=invalid"
                   ])
                 end
  end
end
