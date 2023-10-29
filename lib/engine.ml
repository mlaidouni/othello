type player = X | O
type hpos = H of int
type vpos = V of int
type pos = hpos * vpos
type board = player option list list

module Pos = struct
  let h i = H i
  let v i = V i
end

(* Pretty printers *)
let pp_player fmt (pl : player option) =
  match pl with
  | None -> Format.fprintf fmt "•"
  | Some X -> Format.fprintf fmt "X"
  | _ -> Format.fprintf fmt "O"

let pp_hpos fmt n = match n with H i -> Format.fprintf fmt "Pos.(h %d)" i
let pp_vpos fmt n = match n with V i -> Format.fprintf fmt "Pos.(v %d)" i
let pp_pos fmt po = match po with H i, V j -> Format.fprintf fmt "(%d,%d)" i j

let pp_poslist fmt polist =
  List.iter (fun y -> Format.fprintf fmt "%a " pp_pos y) polist

let pp_board fmt board =
  List.iter
    (fun x ->
      List.iter (fun y -> Format.fprintf fmt "%a" pp_player y) x;
      Format.fprintf fmt "@\n")
    board

let equal_hpos (H h1) (H h2) = h1 = h2
let equal_vpos (V v1) (V v2) = v1 = v2

let equal_pos ((h1, v1) : pos) ((h2, v2) : pos) =
  equal_hpos h1 h2 && equal_vpos v1 v2

let equal_player pl1 pl2 =
  match (pl1, pl2) with
  | None, None -> true
  | Some X, Some X -> true
  | Some O, Some O -> true
  | _, _ -> false

let equal_board (b1 : board) (b2 : board) =
  ignore (b1, b2);
  true

exception Invalid_hpos
exception Invalid_vpos
exception Invalid_move

let init () = []
let get (b : board) ((H h, V v) : pos) = List.nth (List.nth b h) v

let set (b : board) ((H h, V v) : pos) pl =
  List.mapi
    (fun i line ->
      if i = h then List.mapi (fun j el -> if j = v then Some pl else el) line
      else line)
    b

let free_pos b : pos list =
  let copy_b = List.append [] b in
  let listofpos =
    List.concat
      (List.mapi
         (fun i line -> List.mapi (fun j _ -> (Pos.h i, Pos.v j)) line)
         copy_b)
  in
  List.filter
    (fun pos -> match get b pos with None -> true | _ -> false)
    listofpos

module Verif = struct
  let win b p =
    ignore (b, p);
    true

  let swap_player = function None -> None | Some X -> Some O | _ -> Some X

  let not_border_dir ((H h, V v) : pos) dir =
    match dir with
    | 0 ->
        if equal_hpos (H h) (H 0) then raise Invalid_move (*west*)
        else (H h, V (v - 1))
    | 1 ->
        if equal_hpos (H h) (H 0) || equal_vpos (V v) (V 0) then
          raise Invalid_move (*north west*)
        else (H (h - 1), V (v - 1))
    | 2 ->
        if equal_vpos (V v) (V 0) then raise Invalid_move (*north*)
        else (H (h - 1), V v)
    | 3 ->
        if equal_hpos (H h) (H 7) || equal_vpos (V v) (V 0) then
          raise Invalid_move (*north east*)
        else (H (h - 1), V (v + 1))
    | 4 ->
        if equal_hpos (H h) (H 7) then raise Invalid_move (*east*)
        else (H h, V (v + 1))
    | 5 ->
        if equal_hpos (H h) (H 7) || equal_vpos (V v) (V 7) then
          raise Invalid_move (*south east*)
        else (H (h + 1), V (v + 1))
    | 6 ->
        if equal_vpos (V v) (V 7) then raise Invalid_move (*south*)
        else (H (h + 1), V v)
    | _ ->
        if equal_hpos (H h) (H 0) || equal_vpos (V v) (V 7) then
          raise Invalid_move (*south west*)
        else (H (h + 1), V (v - 1))

  (*returns the next board case in dir direction if it contains player*)
  let next_pos_player board player pos dir =
    try
      let next_pos = not_border_dir pos dir in
      if get board next_pos = player then next_pos else (H (-2), V (-2))
    with _ -> (H (-1), V (-1))

  let rec same_player_line board player pos dir res =
    let next_pos = next_pos_player board player pos dir in
    if equal_pos next_pos (H (-1), V (-1)) then []
      (*reached end of board before reaching an opponent*)
    else if equal_pos next_pos (H (-2), V (-2)) then
      (*reached an empty square or an opponent*)
      if get board (not_border_dir pos dir) = swap_player player then res
      else []
    else same_player_line board player next_pos dir (res @ [ next_pos ])

  (*returns all the positions we need to set after a move by player, from pos in dir*)
  let move_dir board player pos dir =
    let next_pos = next_pos_player board (swap_player player) pos dir in
    if equal_pos next_pos (H (-1), V (-1)) then []
      (*first next pos is out of board*)
    else if equal_pos next_pos (H (-2), V (-2)) then []
      (*first next pos contains same player as pos, or no player*)
    else same_player_line board (swap_player player) next_pos dir [ next_pos ]

  let move (b : board) pl pos =
    let rec move_in b pl pos dir l_pos =
      if dir > 7 then l_pos
      else
        let new_l = move_dir b pl pos dir in
        move_in b pl pos (dir + 1) (l_pos @ new_l)
    in
    move_in b pl pos 0 [ pos ]

  let can_play b pl =
    let rec havePiece board =
      match board with
      | [] -> false
      | line :: otherlines ->
          if List.mem (Some pl) line then true else havePiece otherlines
    in
    if not (havePiece b) then false
    else List.exists (fun po -> move b (Some pl) po != [ po ]) (free_pos b)
end
