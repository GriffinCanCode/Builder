(* Utility functions for OCaml example *)

(** Greet a person by name *)
let greet name =
  Printf.sprintf "Hello, %s! Welcome to OCaml." name

(** Calculate factorial recursively *)
let rec factorial n =
  if n <= 1 then
    1
  else
    n * factorial (n - 1)

(** Calculate Fibonacci number recursively *)
let rec fibonacci n =
  match n with
  | 0 -> 0
  | 1 -> 1
  | _ -> fibonacci (n - 1) + fibonacci (n - 2)

(** Sum all elements in a list *)
let rec sum_list lst =
  match lst with
  | [] -> 0
  | head :: tail -> head + sum_list tail

(** Double each element in a list *)
let double_list lst =
  List.map (fun x -> x * 2) lst

(** Filter even numbers from a list *)
let filter_even lst =
  List.filter (fun x -> x mod 2 = 0) lst

(** Convert list to string representation *)
let list_to_string lst =
  let items = List.map string_of_int lst in
  "[" ^ String.concat "; " items ^ "]"

(** Check if a number is prime *)
let is_prime n =
  if n < 2 then
    false
  else
    let rec check_divisor d =
      if d * d > n then
        true
      else if n mod d = 0 then
        false
      else
        check_divisor (d + 1)
    in
    check_divisor 2

(** Get all prime numbers up to n *)
let primes_up_to n =
  let rec aux current acc =
    if current > n then
      List.rev acc
    else if is_prime current then
      aux (current + 1) (current :: acc)
    else
      aux (current + 1) acc
  in
  aux 2 []


