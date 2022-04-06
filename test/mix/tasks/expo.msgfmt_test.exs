defmodule Mix.Tasks.Expo.MsgfmtTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expo.Mo
  alias Expo.Translations
  alias Mix.Tasks.Expo.Msgfmt

  setup do
    temp_file = Path.join(System.tmp_dir!(), make_ref() |> :erlang.phash2() |> to_string())

    on_exit(fn -> File.rm(temp_file) end)

    {:ok, temp_file: temp_file}
  end

  # TODO: Fix
  # ** (ArgumentError) argument error
  # code: capture_io(:standard_io, fn ->
  # stacktrace:
  #   (stdlib 3.17.1) io.erl:99: :io.put_chars(:standard_io, <<222, 18, 4, ...>>)
  #   (expo 0.1.0-beta.2) lib/mix/tasks/expo.msgmft.ex:63: Msgfmt.run/1
  # test "exports mo to console" do
  #   po_path = Application.app_dir(:expo, "priv/test/po/valid.po")

  #   out =
  #     capture_io(:standard_io, fn ->
  #       Msgfmt.run([po_path])
  #     end)

  #   assert {:ok, _parsed} = Mo.parse_binary(out)
  # end

  test "exports mo to file", %{temp_file: temp_file} do
    po_path = Application.app_dir(:expo, "priv/test/po/valid.po")

    Msgfmt.run([po_path, "--output-file=#{temp_file}"])

    assert {:ok, _parsed} = Mo.parse_file(temp_file)
  end

  test "shows statistics", %{temp_file: temp_file} do
    po_path = Application.app_dir(:expo, "priv/test/po/valid.po")

    stderr =
      capture_io(:standard_error, fn ->
        Msgfmt.run([po_path, "--output-file=#{temp_file}", "--statistics"])
      end)

    assert stderr =~ "1 translated messages."
  end

  test "exports fuzzy when asked", %{temp_file: temp_file} do
    po_path = Application.app_dir(:expo, "priv/test/po/valid.po")

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--use-fuzzy"])

    assert {:ok, %Translations{translations: [_one, _two]}} = Mo.parse_file(temp_file)
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
    po_path = Application.app_dir(:expo, "priv/test/po/valid.po")

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--endianness=little"])
    assert {:ok, _parsed} = Mo.parse_file(temp_file)

    Msgfmt.run([po_path, "--output-file=#{temp_file}", "--endianness=big"])
    assert {:ok, _parsed} = Mo.parse_file(temp_file)

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
