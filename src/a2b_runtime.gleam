import gleam/int
import gleam/io
import gleam/iterator.{type Iterator, Next}
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  let code_sort =
    "
  # - - - - - - - - - - - 
  # sort string
  # 
  # in:  A string of 'a', 'b' and 'c'.
  # out: Sort the input in alphabetical order.
  # constraint: 1 <= in
  # - - - - - - - - - - - 

  ba=ab
  ca=ac
  cb=bc
  "

  let code_compare =
    "
  # - - - - - - - - - - - 
  # compare string
  # 
  # in:  A string of 'a' and 'b'.
  # out: The most common letter.
  # constraint: 1 <= in
  # - - - - - - - - - - - 

  ab=
  ba=
  aa=a
  bb=b
  "

  case generate_runtime(code_sort) {
    Ok(runtime) -> runtime("aabacabbaccbabca")
    Error(message) -> message
  }
  |> io.println

  case generate_runtime(code_compare) {
    Ok(runtime) -> runtime("abaababababa")
    Error(message) -> message
  }
  |> io.println
}

fn generate_runtime(code: String) -> Result(fn(String) -> String, String) {
  let #(lines_ok, lines_err) =
    code
    |> string.split("\n")
    |> iterator.from_list
    |> iterator.map(string.trim)
    // remove empty lines && comments
    |> iterator.filter(fn(v) {
      !string.is_empty(v) && !string.starts_with(v, "#")
    })
    |> iterator.transform(1, fn(i, e) { Next(#(i, e), i + 1) })
    // check grammers
    |> iterator.map(fn(v) {
      let #(i, e) = v
      inspect_line(e, i, case string.split(e, "=") {
        [_, _, _, ..] -> CommandEqualAppearsMoreThanTwiceError
        [_, _] -> NoError
        _ -> InvalidCommandError
      })
    })
    |> iterator.to_list
    |> list.partition(result.is_ok)

  case lines_err {
    [_, ..] -> Error(generate_error_message(lines_err))
    _ ->
      Ok({
        let lines =
          lines_ok
          |> result.values
          |> iterator.from_list
          |> iterator.map(fn(v) {
            case string.split_once(v, "=") {
              Ok(v) -> v
              Error(_) -> panic as "Unreachable"
            }
          })
          |> iterator.map(fn(v) {
            let #(left, right) = v
            fn(in: String) -> Result(String, Nil) {
              case string.split_once(in, left) {
                Ok(#(l, r)) -> Ok(l <> right <> r)
                _ -> Error(Nil)
              }
            }
          })

        fn(in: String) -> String { runtime(in, lines) }
      })
  }
}

fn runtime(
  in: String,
  lines: Iterator(fn(String) -> Result(String, Nil)),
) -> String {
  let r =
    lines
    |> iterator.find_map(fn(func) { func(in) })

  case r {
    Ok(v) -> runtime(v, lines)
    _ -> in
  }
}

fn generate_error_message(lines_err: List(Result(String, String))) -> String {
  "Compile Error: \n\n"
  <> lines_err
  |> list.map(fn(v) { result.unwrap_error(v, "") })
  |> string.join("\n")
  <> "\n"
}

type CodeAnalysisResult {
  InvalidCommandError
  CommandEqualAppearsMoreThanTwiceError
  NoError
}

fn inspect_line(
  code: String,
  at: Int,
  err: CodeAnalysisResult,
) -> Result(String, String) {
  case err {
    CommandEqualAppearsMoreThanTwiceError ->
      Error(
        "Command '=' appears more than twice: "
        <> code
        <> ", at line "
        <> int.to_string(at),
      )
    InvalidCommandError ->
      Error("Invalid command: " <> code <> ", at line " <> int.to_string(at))
    NoError -> Ok(code)
  }
}
