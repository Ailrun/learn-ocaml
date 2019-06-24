(* This file is part of Learn-OCaml.
 *
 * Copyright (C) 2019 OCaml Software Foundation.
 * Copyright (C) 2016-2018 OCamlPro.
 *
 * Learn-OCaml is distributed under the terms of the MIT license. See the
 * included LICENSE file for details. *)

open Js_utils
open Lwt.Infix
open Learnocaml_common
open Learnocaml_data

module H = Tyxml_js.Html

let init_tabs, select_tab =
  mk_tab_handlers "toplevel" ["editor"]

let main () =
  set_string_translations_exercises ();
  Learnocaml_local_storage.init () ;
  (* ---- launch everything --------------------------------------------- *)
  let toplevel_buttons_group = button_group () in
  disable_button_group toplevel_buttons_group (* enabled after init *) ;
  let toplevel_toolbar = find_component "learnocaml-exo-toplevel-toolbar" in
  let editor_toolbar = find_component "learnocaml-exo-editor-toolbar" in
  let nickname_div = find_component "learnocaml-nickname" in
  (match Learnocaml_local_storage.(retrieve nickname) with
   | nickname -> Manip.setInnerText nickname_div nickname
   | exception Not_found -> ());
  let toplevel_button =
    button ~container: toplevel_toolbar ~theme: "dark" ~group:toplevel_buttons_group ?state:None in
  let id = match Url.Current.path with
    | "" :: "playground" :: p | "playground" :: p ->
        String.concat "/" (List.map Url.urldecode (List.filter ((<>) "") p))
    | _ -> arg "id"
  in
  Dom_html.document##.title :=
    Js.string (id ^ " - " ^ "Learn OCaml" ^" v."^ Learnocaml_api.version);
  let exercise_fetch =
    retrieve (Learnocaml_api.Playground id)
  in
  let after_init top =
    exercise_fetch >>= fun playground ->
    Learnocaml_toplevel.load ~print_outcome:true top
      ~message: [%i"loading the prelude..."]
      playground.Playground.prelude
    >>= fun r1 ->
    if not r1 then failwith [%i"error in prelude"] ;
    Learnocaml_toplevel.set_checking_environment top >>= fun () ->
    Lwt.return () in
  let toplevel_launch =
    toplevel_launch ~after_init (find_component "learnocaml-exo-toplevel-pane")
      Learnocaml_local_storage.exercise_toplevel_history
      select_tab toplevel_buttons_group id
  in
  init_tabs () ;
  toplevel_launch >>= fun top ->
  exercise_fetch >>= fun playground ->
  let solution =
    try Some (Learnocaml_local_storage.(retrieve (exercise_state id))).Answer.solution with
    | Not_found -> None in
  (* ---- toplevel pane ------------------------------------------------- *)
  init_toplevel_pane toplevel_launch top toplevel_buttons_group toplevel_button ;
  (* ---- editor pane --------------------------------------------------- *)
  let editor_pane = find_component "learnocaml-exo-editor-pane" in
  let editor = Ocaml_mode.create_ocaml_editor (Tyxml_js.To_dom.of_div editor_pane) in
  let ace = Ocaml_mode.get_editor editor in
  Ace.set_contents ace ~reset_undo:true
    (match solution with
     | Some solution -> solution
     | None -> playground.Playground.template) ;
  Ace.set_font_size ace 18;
  let module EB = Editor_button (struct let ace = ace let buttons_container = editor_toolbar end) in
  EB.cleanup playground.Playground.template;
  EB.download id;
  EB.eval top select_tab;
  (* ---- main toolbar -------------------------------------------------- *)
  let exo_toolbar = find_component "learnocaml-exo-toolbar" in
  let toolbar_button = button ~container: exo_toolbar ~theme: "light" in
  begin toolbar_button
      ~icon: "list" [%i"Playground"] @@ fun () ->
    Dom_html.window##.location##assign
      (Js.string "/index.html#activity=playground") ;
    Lwt.return ()
  end ;
  Window.onunload (fun _ev -> local_save ace id; true);
  (* ---- return -------------------------------------------------------- *)
  toplevel_launch >>= fun _ ->
  hide_loading ~id:"learnocaml-exo-loading" () ;
  Lwt.return ()

let () = run_async_with_log main
