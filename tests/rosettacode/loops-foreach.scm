; http://rosettacode.org/wiki/Loops/Foreach#Ol

(for-each print '(1 3 4 2))
(print)
(for-each (lambda (a b c) (print a "-" b "/" c))
   '(1 2 3 4)
   '(5 6 7 8)
   '(a b x z))
