; already loaded when booting.

(define-library (lang macro)

   ; remove make-transformer when it is no longer referred
   (export macro-expand match make-transformer)

   (import
      (scheme base)
      (scheme srfi-1)
      (owl list)
      (owl list-extra)
      (owl math)
      (owl io)
      (owl sort)
      (lang gensym)
      (lang env))

   (begin
      ;;; Misc

      (define (ok exp env) ['ok exp env])
      (define (fail reason) ['fail reason])
      (define-syntax lets (syntax-rules () ((lets . stuff) (let* . stuff)))) ; TEMP

      (define symbols-of

         (define (walk exp found)
            (cond
               ((pair? exp)
                  (walk (cdr exp)
                     (walk (car exp) found)))
               ((and (symbol? exp) (not (has? found exp)))
                  (cons exp found))
               (else found)))

         (lambda (exp)
            (walk exp null)))


      ;;;
      ;;; Basic pattern matching for matching the rule pattern against sexp
      ;;;

      (define (? x) #true)

      (define (match pattern exp)

         (define (match-pattern pattern exp vals)
            (cond
               ((not vals) #false)
               ((pair? pattern)
                  (if (pair? exp)
                     (match-pattern (car pattern) (car exp)
                        (match-pattern (cdr pattern) (cdr exp) vals))
                     #false))
               ((eq? pattern exp) vals)
               ((eq? pattern '_) vals)
               ((function? pattern)
                  (if (pattern exp) (cons exp vals) #false))
               (else #false)))

         (match-pattern pattern exp null))


      ;;;
      ;;; Matching and rewriting based on rewrite rules
      ;;;

      ; fixme, there are ffs now

      ; store nulls to variables in exp
      (define (init-variables exp literals dict)
         (fold
            (λ (dict key) (cons (cons key null) dict))
            dict
            (diff (symbols-of exp) literals)))

      ;; fixme: we have ffs now
      (define (push dict key val)
         (cond
            ((null? dict)
               (runtime-error "push: key not in dict: " key))
            ((eq? (caar dict) key)
               (cons
                  (append (car dict) (list val))
                  (cdr dict)))
            (else
               (cons (car dict)
                  (push (cdr dict) key val)))))

      (define (match-pattern pattern literals form fail)
         (let loop
            ((pattern pattern) (form form) (collect? #false)
               (fail fail) (dictionary null))
            (cond
               ((symbol? pattern)
                  (cond
                     ((eq? pattern '_) ;; wildcard - match anything, leave no binding
                        dictionary)
                     ((has? literals pattern)
                        (if (eq? pattern form) dictionary (fail pattern)))
                     (collect?
                        ;;; append to dictionary
                        (push dictionary pattern form))
                     (else
                        (let ((binding (getq dictionary pattern)))
                           (if binding
                              (if (equal? (cadr binding) form)
                                 dictionary
                                 (fail pattern))
                              (cons (list pattern form) dictionary))))))
               ((null? pattern)
                  (if (null? form) dictionary (fail pattern)))
               ((pair? pattern)
                  (cond
                     ((and (pair? (cdr pattern)) (eq? (cadr pattern) '...))
                        (let ((dictionary
                                 (init-variables (car pattern)
                                    literals  dictionary)))
                           ; each time a form is matched
                           ;   resume matching with a fail cont returning to
                           ;   process more
                           (let next
                              ((prev-dict dictionary)
                               (old-form form)
                               (new-dict dictionary)
                               (form form))
                              (call/cc
                                 (lambda (ret)
                                 (if (and new-dict (pair? form))
                                    (loop (cddr pattern) form #false
                                       (lambda (argh)
                                          (ret
                                             (next new-dict form
                                                (call/cc
                                                   (lambda (ret)
                                                      (loop (car pattern) (car form)
                                                         #true (lambda (x) (ret #false))
                                                         new-dict)))
                                                (cdr form))))
                                       new-dict)
                                 ; no more matches
                                 (loop (cddr pattern)
                                    (if new-dict form old-form)
                                    #false
                                    fail
                                    (if new-dict new-dict prev-dict))))))))
                     ((pair? form)
                        (loop (cdr pattern) (cdr form) collect? fail
                           (loop (car pattern) (car form) collect? fail
                              dictionary)))
                     (else (fail form))))
               ((equal? pattern form)
                  dictionary)
               (else (fail form)))))

      (define (try-pattern pattern literals form)
         (call/cc
            (lambda (ret)
               (match-pattern pattern literals form
                  (lambda (argh) (ret #false))))))

      ;; given dictionary resulting from pattern matching, decide how many times an ellipsis
      ;; rewrite should be done. owl uses minimum repetition of length more than one, so that
      ;; single matches can be used along with ellipsis matches.

      (define o (λ (f g) (λ (x) (f (g x)))))
      (define (repetition-length dict)
         (let loop ((opts (sort < (map (o length cdr) dict))) (best 0))
            (cond
               ((null? opts)
                  ;; 0 if ellipsis with empty match, or 1 due to ellipsis of lenght 1 or just normal valid bindings
                  best)
               ((eq? 1 (car opts))
                  ;; longer repetitions may follow
                  (loop (cdr opts) 1))
               (else
                  ;; repetition of length 0 or n>1
                  (car opts)))))

      ;; pop all bindings of length > 1
      (define (pop-ellipsis dict)
         (map
            (λ (p) (let ((vals (cdr p))) (if (null? (cdr vals)) p (cons (car p) (cdr vals)))))
            dict))

      (define (rewrite dictionary form)
         (let loop ((form form))
            (cond
               ((symbol? form)
                  (let ((binding (getq dictionary form)))
                     (if (and binding (pair? (cdr binding)))
                        (cadr binding)
                        form)))
               ((pair? form)
                  (if (and (pair? (cdr form)) (eq? (cadr form) '...))
                     (lets
                        ((syms (symbols-of (car form)))
                         (dict (keep (λ (node) (has? syms (car node))) dictionary))
                         (len (repetition-length dict)))
                        (let rep-loop ((dict dict) (n len))
                           (if (eq? n 0)
                              (loop (cddr form))
                              (cons
                                 (rewrite dict (car form))
                                 (rep-loop (pop-ellipsis dict) (- n 1))))))
                     (cons
                        (loop (car form))
                        (loop (cdr form)))))
               (else form))))


      ;;; Intermission

      ; exp env free -> status exp' free'

      (define toplevel-syntax-definition?
         (let
            ((pattern
               `(quote syntax-operation add #false (,symbol? ,list? ,list? ,list?))))
            ;; -> keyword literals patterns templates
            (lambda (exp)
               (match pattern exp))))

      (define toplevel-macro-definition?
         (let 
            ((pattern
               `(quote macro-operation eval #false (,symbol? ,function?))))
            ;; -> name handler
            (lambda (exp)
               (match pattern exp))))

      ; fold w/ 2 state variables
      (define (fold2 op s1 s2 lst)
         (if (null? lst)
            (values s1 s2)
            (lets ((s1 s2 (op s1 s2 (car lst))))
               (fold2 op s1 s2 (cdr lst)))))

      (define (add-fresh-bindings names free dict)
         (fold2
            (λ (free dict name)
               (values (gensym free) (cons (list name free) dict)))
            free dict names))

      (define (make-transformer literals rules)
         (λ (form free)
            (some
               (λ (rule)
                  ;; rule = (pattern gensyms template)
                  (let ((dictionary (try-pattern (car rule) literals form)))
                     (if dictionary
                        (let*((free dictionary
                                 (add-fresh-bindings (cadr rule) free dictionary))
                              (new (rewrite dictionary (caddr rule))))
                           [new free]))))
               rules)))

      ; add fresh symbol list -> ((pattern fresh template) ...)

      (define (make-pattern-list literals patterns templates unbound?)
         (map
            (λ (pattern template)
               (lets
                  ((pattern-symbols (symbols-of pattern))
                   (template-symbols (symbols-of template))
                   (fresh-symbols
                     (keep
                        (lambda (x) (and (unbound? x) (not (has? literals x))))
                        (diff template-symbols pattern-symbols))))
                  (list pattern fresh-symbols template)))
            patterns templates))


      ;;;
      ;;; Macro expansion in a given env
      ;;;

      ; expand all macros top to bottom
      ; exp env free -> #(exp' free')

      (define (expand exp env free abort)

         ; (print "expand: " exp)

         (define (expand-list exps env free) ; todo: handle 'env' changes
            (if (null? exps)
               (values null free)
               (lets
                  ((this free (expand (car exps) env free abort))
                   (tail free (expand-list (cdr exps) env free)))
                  (values (cons this tail) free))))

         (cond
            ((null? exp)
               (values exp free))
            ((list? exp)
               (cond
                  ((symbol? (car exp))
                     (case (lookup env (car exp))
                        (['special thing]
                           (case thing
                              ('quote (values exp free))

                              ('lambda
                                 (if (or (null? (cdr exp)) (null? (cddr exp))) ;; todo: use matcher instead
                                    (abort (list "Bad lambda: " exp))
                                    (lets
                                       ((formals (cadr exp))
                                        (body-exps (cddr exp))
                                        (body
                                          (if (and (pair? body-exps) (null? (cdr body-exps)))
                                             (car body-exps)
                                             (cons 'begin body-exps)))
                                        (body free
                                          (expand body (env-bind env formals) free abort)))
                                       (values (list 'lambda formals body) free))))
                              ('setq
                                 (lets
                                    ((value free
                                       (expand (caddr exp) env free abort)))
                                    (values
                                       (list 'setq (cadr exp) value)
                                       free)))
                              ('let-eval
                                 (let*((formals (second exp))    ; lref 1
                                       (definitions (third exp)) ; lref 2
                                       (body (fourth exp))       ; lref 3
                                       (env (env-bind env formals))
                                       (definitions free
                                          (expand-list definitions env free))
                                       (body free
                                          (expand body env free abort)))
                                    (values
                                       (list 'let-eval formals definitions body)
                                       free)))
                              ('ifeq
                                 (expand-list exp env free))
                              ('brae
                                 (if (or (null? (cdr exp)) (null? (cddr exp)))
                                    (abort (list "Bad brae: " exp))
                                    (lets
                                       ((first free (expand (cadr exp)  env free abort))
                                        (rest  free (expand (caddr exp) env free abort)))
                                       (values (list 'brae first rest) free))))

                              ('values
                                 (expand-list exp env free))
                              ('values-apply
                                 (expand-list exp env free))

                              (else
                                 (abort
                                    (list "expand: unknown special form: " exp)))))
                        (['bound]          (expand-list exp env free))
                        (['defined value]  (expand-list exp env free))
                        (['undefined]
                           ;; can be a literal
                           (values exp free))
                        (['syntax transformer]
                           (let ((result (transformer exp free)))
                              (if result
                                 (expand (ref result 1) env (ref result 2) abort)
                                 (abort exp))))
                        (['macro transformer]
                           (let ((result (transformer exp env)))
                              (if result
                                 (expand (ref result 1) (ref result 2) free abort)
                                 (abort exp))))
                        (else is node
                           ; usually bad module exports, since those are not checked atm
                           (abort (list "expand: rator maps to unknown value " (car exp))))))
                  (else
                     (expand-list exp env free))))
            ((symbol? exp)
               (case (lookup env exp)
                  (['syntax transformer]
                     (abort (list "Macro being used as a value: " exp)))
                  (['macro transformer]
                     (abort (list "Macro being used as a value: " exp)))
                  (['undefined]
                     ;; this can still be a literal used by a macro
                     (values exp free))
                  (else
                     (values exp free))))
            (else
               (values exp free))))

      ; maybe extend the env if a macro is being defined

      (define (post-macro-expand exp env fail)
         (cond
            ((toplevel-syntax-definition? exp)
               (lets
                  ((rules (lref exp 4))
                   (keyword (lref rules 0))
                   (literals (lref rules 1))
                   (patterns (lref rules 2))
                   (templates (lref rules 3))
                   (rules
                     (make-pattern-list literals patterns templates
                        (lambda (sym)
                           (not (env-get-raw env sym #false)))))
                   (transformer
                     (make-transformer (cons keyword literals) rules)))
                  (let ((env (env-set-syntax env keyword transformer)))
                     (ok (list 'quote keyword) env))))
            ((toplevel-macro-definition? exp)
               (define body (lref exp 4))
               (define name (car body))
               (define func (cadr body))
               (let ((env (env-set-macro env name func)))
                  (ok (list 'quote name) env)))
            (else
               (ok exp env))))

      ;; bug: exported macros do not preserve bindinds

      (define (macro-expand exp env)
         (let*/cc exit
            ((abort (lambda (why) (exit (fail why))))
             (free (gensym exp))
             (exp free (expand exp env free abort)))
            (post-macro-expand exp env abort)))


))
