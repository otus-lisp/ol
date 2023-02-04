;;;
;;; Converting S-exps to a more compact and checked AST
;;;

(define-library (lang ast)

   (export call? var? value-of sexp->ast mkcall mklambda mkvar mkval)

   (import
      (scheme base)
      (srfi 1)

      (owl list-extra)
      (owl math)
      (lang env))

   (begin
      (define (ok exp env) ['ok exp env])
      (define (fail reason) ['fail reason])
      (define-syntax lets (syntax-rules () ((lets . stuff) (let* . stuff)))) ; TEMP

      (define (call? thing) (eq? (ref thing 1) 'call))
      (define (var? thing) (eq? (ref thing 1) 'var))
      (define (value-of node) (ref node 2))

      (define (mkval val)
         ['value val])

      (define (mklambda formals body)
         ['lambda-var #true formals body])

      (define (mkcall rator rands)
         ['call rator rands])

      ;;;; cps adds a cont + system
      (define (mkprim op args)
         ['prim op args])

      (define (mkvar sym)
         ['var sym])

      ;; formals-sexp → (sym ..)|#false fixed-arity?
      (define (check-formals lst)
         (let loop ((lst lst) (out null))
            (cond
               ((null? lst)
                  (values (reverse out) #true))
               ((symbol? lst) ;; variable arity
                  (if (has? out lst) ;; reappearence
                     (values #f #f)
                     (values (reverse (cons lst out)) #false)))
               ((symbol? (car lst))
                  (if (has? out (car lst))
                     (values #f #f)
                     (loop (cdr lst) (cons (car lst) out))))
               (else
                  (values #f #f)))))

      (define (fixed-formals-ok? sexp)
         (lets ((formals fixed? (check-formals sexp)))
            (and formals fixed?)))

      (define (translate-direct-call exp env fail translate)
         (case (lookup env (car exp))
            (['special thing]
               (case thing
                  ('quote
                     (if (eq? (length exp) 2)
                        (mkval (cadr exp))
                        (list "Strange quote: " exp)))
                  ('lambda
                     (let ((len (length exp)))
                        (cond
                           ((eq? len 3)
                              (lets
                                 ((formals (cadr exp))
                                  (body (caddr exp))
                                  (formals fixed?
                                    (check-formals formals)))
                                 (cond
                                    ((not formals) ;; non-symbols, duplicate variables, etc
                                       (fail (list "Bad lambda: " exp)))
                                    (else
                                       ['lambda-var fixed? formals
                                          (translate body (env-bind env formals) fail)]))))
                           ((> len 3)
                              ;; recurse via translate
                              (let
                                 ((formals (cadr exp))
                                  (body (cddr exp)))
                                 (translate
                                    (list 'lambda formals
                                       (cons 'begin body)) env fail)))
                           (else
                              (fail (list "Bad lambda: " exp))))))
                  ('let-eval ;;; (let-eval formals definitions body)
                     (if (eq? (length exp) 4)
                        (let
                           ((formals (lref exp 1))
                            (values (lref exp 2))
                            (body (lref exp 3)))
                           (if
                              (and
                                 (list? values)
                                 (fixed-formals-ok? formals)
                                 (eq? (length formals) (length values)))
                              (let ((env (env-bind env formals)))
                                 ['let-eval formals
                                    (map
                                       (lambda (x) (translate x env fail))
                                       values)
                                    (translate body env fail)])
                              (fail (list "Bad let-eval: " exp))))
                        (fail (list "Bad let-eval: " exp))))
                  ('ifeq ;;; (ifeq a b then else)
                     (if (eq? (length exp) 5)
                        (let ((a (second exp))
                              (b (third exp))
                              (then (fourth exp))
                              (else (fifth exp)))
                           ['ifeq
                              (translate a env fail)
                              (translate b env fail)
                              (translate then env fail)
                              (translate else env fail)])
                        (fail (list "Bad ifeq " exp))))
                  ('brae ; (brae (lambda-ok) (lambda-else))
                     (if (eq? (length exp) 3)
                        ['brae
                           (translate (second exp) env fail)
                           (translate (third exp) env fail)]
                        (fail (list "Bad brae: " exp))))

                  ('values
                     ['values
                        (map (lambda (arg) (translate arg env fail)) (cdr exp))])
                  ('values-apply
                     ['values-apply
                        (translate (lref exp 1) env fail)
                        (translate (lref exp 2) env fail)])
                  ;; FIXME pattern
                  (else
                     (fail
                        (list
                           "Unknown special operator in ast conversion: "
                           exp)))))
            (['bound]
               (mkcall (mkvar (car exp))
                  (map
                     (lambda (x) (translate x env fail))
                     (cdr exp))))
            ;; both now handled by apply-env
            ;((undefined)
            ;  (fail (list "i do not know this function" exp)))
            ; left here to handle primops temporarily
            (['defined value]
               (mkcall value
                  (map (lambda (x) (translate x env fail)) (cdr exp))))
            (else is err
               ; could be useful for (eval (list + 1 2) env)
               ; so just warn for now
               (fail
                  (list
                     "Unknown value type in ast conversion: "
                     (list 'name (car exp) 'value err)))
               ;(mkval exp)
               )))

      (define (translate exp env fail)
         (cond
            ((null? exp) (mkval exp))
            ((list? exp)
               (if (symbol? (car exp))
                  (translate-direct-call exp env fail translate)
                  (mkcall
                     (translate (car exp) env fail)
                     (map
                        (lambda (x)
                           (translate x env fail))
                        (cdr exp)))))
            ((symbol? exp)
               (case (lookup env exp)
                  (['bound]
                     (mkvar exp))
                  ;; should be already handled in apply-env
                  (['defined value]
                     value)
                  (['special thing]
                     (fail
                        (list "a special thing being used as an argument: " exp)))
                  (['undefined]
                     (fail (list "what are '" exp "'?")))
                  (else is err
                     (fail
                        (list "Strange value in ast conversion: "
                           err)))))
            (else (mkval exp))))

      ; -> #(ok exp' env) | #(fail reason)

      (define (sexp->ast exp env)
         (call/cc (lambda (drop)
            (ok (translate exp env (lambda (reason) (drop (fail reason))))
                env))))


))