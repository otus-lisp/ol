; http://srfi.schemers.org/srfi-16/srfi-16.html
(define-library (srfi 16)
   (version 'final)
   (keywords (scheme case-lambda srfi-16))
   (description
      "Syntax for procedures of variable arity")

;; Abstract
;
; CASE-LAMBDA, a syntax for procedures with  a variable number of arguments, is introduced.


;; Rationale
;
; CASE-LAMBDA reduces  the clutter of  procedures that execute  different code depending on
; the number of arguments they were passed; it is a pattern-matching mechanism that matches
; on the number of arguments. CASE-LAMBDA is available in some Scheme systems.


; NOTE: srfi-16 fully included into scheme core profile, you should not include it manually.
; -----
(export
   case-lambda)

(begin
   ; makes a list of options to be compiled to a chain of code bodies w/ jumps
   ; note, could also merge to a jump table + sequence of codes
   (define-syntax case-lambda
      (syntax-rules (arity-error)
         ((case-lambda)
            (lambda () arity-error))
         ((case-lambda (formals . body))
            (lambda formals . body))
         ((case-lambda (formals . body) . rest)
            (brae (lambda formals . body)
                  (case-lambda . rest)))))

))
