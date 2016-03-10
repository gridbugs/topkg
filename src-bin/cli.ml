(*---------------------------------------------------------------------------
   Copyright (c) 2016 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

open Astring
open Rresult
open Bos
open Cmdliner

(* Manual *)

let common_opts = "COMMON OPTIONS"

let common_opts_man =
  [ `S common_opts; `P "These options are common to all commands." ]

let see_also ~cmds =
  let cmds = (String.concat ~sep:"(1), " ("topkg" :: cmds)) ^ "(1)" in
  [ `S "SEE ALSO";
    `P cmds ]

(* Converters and arguments *)

let path_arg =
  let parse s = match Fpath.of_string s with
  | Error _ -> `Error (strf "%a: not a path" String.dump s)
  | Ok s -> `Ok s
  in
  parse, Fpath.pp

let pkg_file =
  let doc = "Use $(docv) as the package description file." in
  let docv = "FILE" in
  Arg.(value & opt path_arg (Fpath.v "pkg/pkg.ml") &
       info ["pkg-file"] ~docs:common_opts ~doc ~docv)

let ignore_pkg =
  let doc = "Ignore package description file." in
  Arg.(value & flag & info ["i"; "ignore-pkg" ] ~doc)

let dist_pkg_file =
  let doc = "Use $(docv) as the package description file in the
             distribution. Expressed relative to the distribution
             directory."
  in
  let docv = "FILE" in
  Arg.(value & opt path_arg (Fpath.v "pkg/pkg.ml") & info ["dist-pkg-file"]
         ~doc ~docv)

let opam_file =
  let doc = "OPAM file to use. If absent uses the first OPAM file mentioned
             in the package description file or ./opam, if there is no
             such file."
  in
  let docv = "FILE" in
  Arg.(value & opt (some path_arg) None & info ["opam-file"] ~doc ~docv)

let dist_file =
  let doc = "The package distribution archive. If absent the file
             $(NAME)-$(VERSION).tbz of the build directory (see option
             $(b,--build-dir)) is used with $NAME and $VERSION respectively
             determined as mentioned in $(b,--pkg-name) and $(b,pkg-version)."
  in
  let docv = "FILE" in
  Arg.(value & opt (some path_arg) None & info ["dist-file"] ~doc ~docv)

let change_log =
  let doc = "The change log to use. If absent determined from the
             package description."
  in
  let docv = "FILE" in
  Arg.(value & opt (some path_arg) None & info ["change-log"] ~doc ~docv)

let delegate =
  let doc = "The delegate tool to use. If absent, see topkg-delegate(7)
             for the lookup procedure."
  in
  let docv = "TOOL" in
  Arg.(value & opt (some string) None & info ["delegate"] ~doc ~docv)

(* Lookups *)

let find_dist_file det dist_file =
  let dist = match dist_file with
  | Some d -> d
  | None -> Topkg_care.Distrib.archive_path det
  in
  OS.File.exists dist >>= function
  | true -> Ok dist
  | false ->
      R.error_msgf "%a: No such file. Did you forget to invoke \
                    $(topkg distrib) ?" Fpath.pp dist

(* Terms *)

let logs_to_topkg_log_level = function
| None -> None
| Some Logs.App -> Some (Topkg.Log.App)
| Some Logs.Error -> Some (Topkg.Log.Error)
| Some Logs.Warning -> Some (Topkg.Log.Warning)
| Some Logs.Info -> Some (Topkg.Log.Info)
| Some Logs.Debug -> Some (Topkg.Log.Debug)

let setup style_renderer log_level cwd =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Topkg.Log.set_level (logs_to_topkg_log_level log_level);
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~app:Fmt.stdout ());
  Logs.info (fun m -> m "topkg %%VERSION%% running");
  match cwd with
  | None -> `Ok ()
  | Some dir ->
      match OS.Dir.set_current dir with
      | Ok () -> `Ok ()
      | Error (`Msg m) -> `Error (false, m) (* use cmdliner evaluation error *)

let setup =
  let style_renderer =
    let env = Arg.env_var "TOPKG_COLOR" in
    Fmt_cli.style_renderer ~docs:common_opts ~env ()
  in
  let log_level =
    let env = Arg.env_var "TOPKG_VERBOSITY" in
    Logs_cli.level ~docs:common_opts ~env ()
  in
  let cwd =
    let doc = "Change to directory $(docv) before doing anything." in
    let docv = "DIR" in
    Arg.(value & opt (some path_arg) None & info ["C"; "pkg-dir"]
           ~docs:common_opts ~doc ~docv)
  in
  Term.(ret (const setup $ style_renderer $ log_level $ cwd))

let distrib_determine =
  let build_dir =
    let doc = "Specifies the build directory. If absent, provided by
               the package description."
    in
    let docv = "DIR" in
    Arg.(value & opt (some string) None & info ["build-dir"] ~doc ~docv)
  in
  let pname =
    let doc = "The name of the package to use for the package distribution.
               If absent, provided by the package description."
    in
    let docv = "NAME" in
    Arg.(value & opt (some string) None & info ["name"] ~doc ~docv)
  in
  let commit_ish =
    let doc = "The VCS commit-ish to base the package distribution on.
               If absent, provided by the package description."
    in
    let docv = "COMMIT-ISH" in
    Arg.(value & opt (some string) None & info ["commit"] ~doc ~docv)
  in
  let pkg_version =
    let doc = "The version string to use for the package distribution.
               If absent, provided by the package description."
    in
    let docv = "VERSION" in
    Arg.(value & opt (some string) None & info ["pkg-version"] ~doc ~docv)
  in
  let det build_dir name commit_ish version ~pkg_file =
    Topkg_care.Distrib.determine
      ~pkg_file ~build_dir ~name ~commit_ish ~version
  in
  Term.(const det $ build_dir $ pname $ commit_ish $ pkg_version)

(* Error handling *)

let handle_error r = Logs.on_error_msg ~use:(fun _ -> 3) r

(*---------------------------------------------------------------------------
   Copyright (c) 2016 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
