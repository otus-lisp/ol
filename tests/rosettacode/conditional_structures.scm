; http://www.rosettacode.org/wiki/Conditional_structures

; if-then, the simplest conditional primitive.
(if (= (* 2 2) 4) (print "if-then: equal"))
(if (= (* 2 2) 6) (print "if-then: non equal"))

; if-then-else, the full conditional 'if' primitive.
(if (= (* 2 2) 4) (print "if-then-else: equal") (print "if-then-else: non equal"))
(if (= (* 2 2) 6) (print "if-then-else: non equal") (print "if-then-else: i don't know"))

; unless, the opposite for 'if'.
(unless (= (* 2 2) 4) (print "unless: non equal"))
(unless (= (* 2 2) 6) (print "unless: i don't know"))
(unless (= (* 2 2) 4) (print "unless: non equal") (print "unless: equal"))
(unless (= (* 2 2) 6) (print "unless: i don't know") (print "unless: non equal"))

; case, the sequence of comparing values.
(case (* 2 2)
   (3
      (print "case: 3"))
   (4
      (print "case: 4"))
   ((5 6 7)
      (print "case: 5 or 6 or 7"))
   (else
      (print "case: i don't know")))

; cond, the sequnce of comparators.
(cond
   ((= (* 2 2) 4)
      (print "cond: equal"))
   ((= (* 2 2) 6)
      (print "cond: not equal"))
   (else
      (print "cond: i don't know")))

; tuple-case, smart tuple comparer with variables filling
(tuple-case (tuple 'selector 1 2 3)
   ((case1 x y)
      (print "tuple-case: case1 " x ", " y))
   ((selector x y z)
      (print "tuple-case: selector " x ", " y ", " z))
   (else
      (print "tuple-case: i don't know")))

; case-lambda, selecting the lambda based on arguments count.
(define smart (case-lambda
   ((x)
      (print x ", -, -"))
   ((x y)
      (print x ", " y ", -"))
   ((x y z)
      (print x ", " y ", " z))))
(smart 1)
(smart 1 2)
(smart 1 2 3)
