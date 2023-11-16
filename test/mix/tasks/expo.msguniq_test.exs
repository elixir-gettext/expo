defmodule Mix.Tasks.Expo.MsguniqTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expo.Message
  alias Expo.Messages
  alias Expo.PO
  alias Expo.PO.SyntaxError
  alias Mix.Tasks.Expo.Msguniq

  setup do
    temp_file = Path.join(System.tmp_dir!(), make_ref() |> :erlang.phash2() |> to_string())

    on_exit(fn -> File.rm(temp_file) end)

    {:ok, temp_file: temp_file}
  end

  test "leaves file without duplicates as is", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/valid.po"

    File.cp!(po_path, temp_file)

    assert capture_io(fn ->
             Msguniq.run([temp_file])
           end) == ""
  end

  test "merges duplicates into output file", %{temp_file: temp_file} do
    po_path = "test/fixtures/po/duplicate_messages.po"

    assert capture_io(:stderr, fn ->
             Msguniq.run([po_path, "--output-file", temp_file])
           end) =~ "Merged 2 translations"

    assert {:ok, %Messages{messages: [%Message.Singular{msgid: ["test"]} | _rest]}} =
             PO.parse_file(temp_file)
  end

  test "merges duplicates into stdout" do
    po_path = "test/fixtures/po/duplicate_messages.po"

    output =
      capture_io(fn ->
        assert capture_io(:stderr, fn ->
                 Msguniq.run([po_path])
               end) =~ "Merged 2 translations"
      end)

    assert {:ok, %Messages{messages: [%Message.Singular{msgid: ["test"]} | _rest]}} =
             PO.parse_string(output)
  end

  test "crashes with syntax error", %{temp_file: temp_file} do
    File.write!(temp_file, "invalid")

    assert_raise SyntaxError, fn ->
      Msguniq.run([temp_file])
    end
  end

  test "errors with missing file" do
    assert_raise Mix.Error,
                 "mix expo.msguniq failed due to missing po file path argument\n",
                 fn -> Msguniq.run([]) end
  end

  test "errors with multiple files" do
    assert_raise Mix.Error,
                 "mix expo.msguniq failed due to multiple po file path arguments\nOnly one is currently supported\n",
                 fn -> Msguniq.run(["file_one", "file_two"]) end
  end
end
