; http://paulbourke.net/dataformats/mtl/
(define-library (file wavefront mtl)

(export
   wavefront-mtl-parser)

(import
   (otus lisp)
   (file parser)
   (lang sexp))
(begin

(define get-rest-of-line
   (let-parses
      ((chars (get-greedy* (get-byte-if (lambda (x) (not (eq? x 10))))))
         (skip (get-imm 10))) ;; <- note that this won't match if line ends to eof
      chars))

(define get-inexact
   (let-parse* (
         (number get-number))
      (inexact number)))

(define get-comment
   (let-parses(
         (sign (get-imm #\#))
         (comment get-rest-of-line))
      #true))

(define get-newmtl
   (let-parses(
         (skip (get-word "newmtl " #t))
         (name get-rest-of-line))
      name))

(define (get-1-number name)
   (let-parses(
         (skip (get-word name #t))
         (value get-number)
         (skip (get-imm #\newline)))
      value))
(define (get-3-numbers name)
   (let-parses(
         (skip (get-word name #t))
         (r get-inexact)
         (skip (get-imm #\space))
         (g get-inexact)
         (skip (get-imm #\space))
         (b get-inexact)
         (skip (get-imm #\newline)))
      [r g b 1.0]))

(define (map-parser name)
   (either
      (let-parse* (
            (skip (get-word name #true))
            (value get-rest-of-line))
         (bytes->string value))
      (epsilon #false)))

(define material-parser
   (let-parse* (
         (skip (get-imm #\newline))
         (newmtl get-newmtl)
         (ns (get-1-number "Ns "))
         (ka (get-3-numbers "Ka "))
         (kd (get-3-numbers "Kd "))
         (ks (get-3-numbers "Ks "))
         (ke (get-3-numbers "Ke "))
         (ni (get-1-number "Ni "))
         (d (get-1-number "d "))
         (illum (get-1-number "illum "))
         (map_kd (map-parser "map_Kd ")))
      {
         'name   (bytes->string newmtl)
         'ns     (inexact ns)
         'ka     ka
         'kd     kd
         'map_kd map_kd
         'ks     ks
         'ke     ke
         'ni     ni
         'd      d
         'illum  illum
      }))

; main
(define wavefront-mtl-parser
   (let-parses(
         (comments (get-greedy* get-comment))
         (materials (get-greedy+ material-parser)))
      materials))

))
