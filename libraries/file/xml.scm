(define-library (file xml)
(import
   (otus lisp)
   (only (scheme misc) string->number)
   (owl parse))

(export
   xml-parser
   xml-parse-file

   read-xml
   read-xml-file

   read-xml-port   ; same as read-xml
   read-xml-string ; same as read-xml
   read-xml-stream ; same as read-xml

   xml-get-root-element
   xml-get-attributes
   xml-get-name
   xml-get-attribute
   xml-get-value

   xml-get-subtags
   xml-get-subtag

   xml-print

   xml-get-int-attribute

   ; let's try new xml interface:
   xml:root

   xml:attributes
   xml:name
   xml:value

   xml:attribute

   ;xml->string ; todo
)

; parsed xml is:
;   #('xml #(attributes) body)
; where body:
;   #('tag #(attributes) '(children))
; where child:
;   vector if tag or string if value

; legend: #[] is vector
;         #() is ff (dictionary) with symbols as keys

(begin
   ; special symbols decoding
   ;(define @< (string->regex "r/&lt;/<"))


   ; utils:
   (define (between? lo x hi) ; fast version of (<= lo x hi)), where x is rune
      (and (or (less? lo x) (eq? lo x))
         (or (less? x hi) (eq? x hi))))

   ; xml standard: "any Unicode character, excluding the surrogate blocks, FFFE, and FFFF."
   (define (character? n) (or
      (between? #\a n #\z)
      (between? #\0 n #\9)
      (between? #\A n #\Z)
      (eq? n #\-) (eq? n #\:)))
      ;(between? #x7F n #xD7FF)
      ;(between? #xE000 n #xFFFD)
      ;(between? #x10000 n #x10FFFF)))

   (define (whitespace? x)
      (has? '(#\tab #\space #\newline #\return) x))

   (define skip-whitespaces
      (get-any-of (get-greedy* (get-rune-if whitespace?))))

   (define get-attribute
      (let-parses (
            (name (get-greedy+ (get-rune-if character?)))
            (= (get-imm #\=))
            (* (get-imm #\"))
            (value (get-greedy* (get-rune-if (lambda (x) (not (eq? x #\"))))))
            (* (get-imm #\"))
            (* skip-whitespaces))
         (cons
            (string->symbol (runes->string name))
            (runes->string value))))


   ; well, either the raw text or the set of subtags
   ; пока не будем смешивать вместе текст и теги - либо то либо другое
   (define (get-tag)
      (get-either
         (get-greedy*
            ; parse tag with attributes
            (let-parse* (
                  (< (imm #\<))
                  (name (greedy+ (get-rune-if character?)))
                  (* skip-whitespaces)
                  (attributes (get-greedy* get-attribute))
                  (body (get-either
                     (get-word "/>" #null)
                     (let-parses (
                           (* (get-imm #\>))
                           (* skip-whitespaces)
                           (body (get-tag))
                           (* (get-word "</" #t)) ; </tag>
                           (* (get-word (runes->string name) #t))
                           (* (get-imm #\>)))
                        body)))
                  (* skip-whitespaces))
               (vector
                  (string->symbol (runes->string name))
                  (pairs->ff attributes)
                  body)))
         (let-parse* (
               (body (get-greedy* (get-rune-if (lambda (x) (not (eq? x #\<)))))))
            (if body (runes->string body)))))

   (define xml-parser
      (let-parse* (
            (? (word "<?xml " #t)) ;<?xml version="1.0" encoding="UTF-8"?>
            (? skip-whitespaces)
            (attributes (get-greedy* get-attribute))
            (* (get-word "?>" #true))

            (* skip-whitespaces)
            (body (get-tag)))
         ['xml (pairs->ff attributes) body]))

   (define (xml-parse-file filename)
      (let ((file (open-input-file filename)))
         (if file
            (let ((o (parse xml-parser (port->bytestream file) filename "xml parse error" #false)))
               (if o o
                  (close-port file)))))) ; no automatic port closing on error

   (define (xml-get-root-element xml)
      (car (ref xml 3)))

   (define (xml-get-name root)
      (ref root 1))
   (define (xml-get-attributes root)
      (ref root 2))
   (define (xml-get-value root)
      (ref root 3))

   (define (xml-get-attribute root name default-value)
      (get (xml-get-attributes root) name default-value))

   (define (xml-get-subtags root name)
      (filter (lambda (tag) (eq? (xml-get-name tag) name)) (xml-get-value root)))

   (define (xml-get-subtag root name)
      (let ((subtags (xml-get-subtags root name)))
         (unless (null? subtags)
            (car subtags))))


   (define (xml-get-int-attribute root name default-value)
      (let ((value (xml-get-attribute root name #false)))
         (if value (string->number value 10) default-value)))

   (define xml:root xml-get-root-element)

   (define xml:attributes xml-get-attributes)
   (define xml:name xml-get-name)
   (define xml:value xml-get-value)

   (define xml:attribute xml-get-attribute)

   ; printing the xml:
   (define (xml-print xml)
      ; header
      (display "<?xml")
      (ff-fold (lambda (? key value)
            (for-each display (list " " key "=\"" value "\"")))
         #f (xml-get-attributes xml))
      (display "?>\n")
      ; tags
      (let loop ((root (xml-get-root-element xml)) (indent ""))
         (display indent)
         (display "<")
         (display (xml-get-name root))
         (ff-fold (lambda (? key value)
               (for-each display (list " " key "=\"" value "\"")))
            #f (xml-get-attributes root))

         (if (null? (xml-get-value root))
            (display "/>\n")
            (let ((value (xml-get-value root)))
               (display ">")
               (if (string? value)
                  (display value)
                  (begin
                     (display "\n")
                     (for-each (lambda (child)
                           (loop child (string-append "   " indent)))
                        value)
                     (display indent)))
               (display "</")
               (display (xml-get-name root))
               (display ">\n")))))

   (define (read-xml-stream stream)
      (when stream
         (define xml (try-parse xml-parser stream #f))
         (if xml (car xml))))

   (define (read-xml-port port)
      (when port
         (read-xml-stream (force (port->bytestream port)))))

   (define (read-xml-string str)
      (when str
         (read-xml-stream (str-iter-bytes str))))

   (define read-xml (case-lambda
      (() (read-xml-port stdin))
      ((source) (cond
         ((port? source) (read-xml-port source))
         ((string? source) (read-xml-string source))
         ((pair? source) (read-xml-stream source))))))

   (define (read-xml-file filename)
      (read-xml (if (equal? filename "-")
                     stdin
                     (open-input-file filename)))) ; note: no need to close port

))
