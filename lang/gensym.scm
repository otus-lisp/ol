
(define-library (lang gensym)

   (export gensym)

   (import
      (scheme base)
      (owl string)
      (owl list)
      (owl format)
      (owl math))

   (begin
      ; return the gensym id of exp (number) or #false

      (define (count-gensym-id str pos end n)
         (if (= pos end)
            n
            (let ((this (ref str pos)))
               (cond
                  ((and (< 47 this) (< this 58))
                     (count-gensym-id str (+ pos 1) end (+ (* n 10) (- this 48))))
                  (else #false)))))

      (define (gensym-id exp)
         (if (symbol? exp)
            (let ((str (symbol->string exp)))
               (let ((len (string-length str)))
                  (if (and (> len 1) (eq? (ref str 0) #\g))
                     (count-gensym-id str 1 len 0)
                     #false)))
            #false))

      (define (max-gensym-id exp max)
         (cond
            ((pair? exp)
               (if (eq? (car exp) 'quote)
                  max
                  (max-gensym-id (cdr exp)
                     (max-gensym-id (car exp) max))))
            ((gensym-id exp) =>
               (lambda (id)
                  (if (> id max) id max)))
            (else max)))

      (define (max-ast-id exp max)
         (case exp
            (['var sym]
               (max-gensym-id sym max))
            (['lambda-var fixed? formals body]
               (max-ast-id body
                  (max-gensym-id formals max)))
            (['call rator rands]
               (max-ast-id rator
                  (fold
                     (lambda (max exp) (max-ast-id exp max))
                     max rands)))
            (['value val] max)
            (['values vals]
               (fold (lambda (max exp) (max-ast-id exp max)) max vals))
            (['values-apply op fn]
               (max-ast-id op
                  (max-ast-id fn max)))
            (['ifeq a b then else]
               (max-ast-id a (max-ast-id b
                  (max-ast-id then (max-ast-id else max)))))
            (['brae fn else]
               (max-ast-id fn
                  (max-ast-id else max)))
            (else
               (runtime-error "gensym: max-ast-id: what is this: " exp))))


      (define (gensym exp)
         (let*((id (+ 1 (if (vector? exp) (max-ast-id exp 0) (max-gensym-id exp 0))))
               (digits (cons #\g (format id null))))
            (string->symbol (runes->string digits))))

      ;(gensym 1)
      ;(gensym '(1 2 3))
      ;(gensym '(g1 (g2 g9999) . g10000000000000))
   ))
