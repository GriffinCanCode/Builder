(* Main entry point for OCaml example application *)

open Utils

let () =
  Printf.printf "OCaml Example Application\n";
  Printf.printf "=========================\n\n";
  
  (* Greet some people *)
  Printf.printf "%s\n" (greet "Alice");
  Printf.printf "%s\n" (greet "Bob");
  Printf.printf "%s\n" (greet "Charlie");
  
  (* Test factorial function *)
  Printf.printf "\nFactorial Tests:\n";
  for i = 0 to 10 do
    Printf.printf "factorial(%d) = %d\n" i (factorial i)
  done;
  
  (* Test Fibonacci function *)
  Printf.printf "\nFibonacci Sequence:\n";
  for i = 0 to 15 do
    Printf.printf "fib(%d) = %d\n" i (fibonacci i)
  done;
  
  (* Test list operations *)
  let numbers = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] in
  Printf.printf "\nSum of %s = %d\n" 
    (list_to_string numbers) 
    (sum_list numbers);
  
  let doubled = double_list numbers in
  Printf.printf "Doubled: %s\n" (list_to_string doubled);
  
  let evens = filter_even numbers in
  Printf.printf "Even numbers: %s\n" (list_to_string evens);
  
  Printf.printf "\nBuild successful with Builder!\n"


