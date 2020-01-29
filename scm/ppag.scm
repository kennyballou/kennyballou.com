#!/usr/bin/env sh
exec guile -e '(@ (ppag) main)' -s "${0}" "${@}"
!#
(define-module (ppag))

(export main)

(use-modules (ice-9 match))
(use-modules (ice-9 pretty-print))
(use-modules (ice-9 rdelim))

(define (read-file filename)
  "Read the entire contents of the provided file

Reads the file line by line, accumulating the result into a list.  Stops when
reaching the EOF marker.  `cons' will construct the list in reverse, reverse at
the end.

We assume the file provided exists and is readable."
  (define (iter fh acc)
    (let ((line (read-line fh)))
      (if (eof-object? line)
          acc
          (iter fh (cons line acc)))))
  (let ((fh (open-input-file filename)))
    (reverse (iter fh '()))))

(define (json-encode-line line)
  "JSON encode the provided line."
  (string-join (append '("\"") (map json-encode-char (string->list line)) '("\"")) ""))

(define (json-encode-char char)
  "JSON encode character

We need to take special care around quotes and backslack characters."
  (cond ((eq? char #\") "\"")
        ((eq? char #\\) "\\")
        (else
         (list->string (list char)))))

(define (json-encode-file filename)
  "JSON encode the file, line by line"
  (map json-encode-line (read-file filename)))

(define (main args)
  (match args
    ((_ input-file)
     (display (string-join (json-encode-file input-file) ",\n"))
     (newline))
    (_ (error "Unrecognized usage."))))
