(ros:include "util-install-quicklisp")
(defpackage :roswell.install.clisp
  (:use :cl :roswell.install :roswell.util :roswell.locations))
(in-package :roswell.install.clisp)

(defun clisp-get-version ()
  (let ((file (merge-pathnames "tmp/clisp.html" (homedir))))
    (format *error-output* "Checking version to install....~%")
    (unless (and (probe-file file)
                 (< (get-universal-time) (+ (* 60 60) (file-write-date file))))
      (download (clisp-version-uri) file))
    (loop for link in (plump:get-elements-by-tag-name (plump:parse file) "a")
          for href = (plump:get-attribute link "href") for len = (1- (length href))
          when (and (eql (aref href len) #\/)
                    (not (eql (aref href 0) #\/))
                    (not (find #\: href))
                    (not (equal "latest/" href)))
            collect (subseq href 0 len))))

(defun clisp-argv-parse (argv)
  (let ((pos (position "--as" (getf argv :argv) :test 'equal)))
    (set-opt "as" (or (and pos (ignore-errors (nth (1+ pos) (getf argv :argv)))
                           (format nil "~A-~A"
                                   (getf argv :version)
                                   (nth (1+ pos) (getf argv :argv))))
                      (getf argv :version))))
  (set-opt "prefix" (merge-pathnames (format nil "impls/~A/~A/~A/~A/" (uname-m) (uname) (getf argv :target) (opt "as")) (homedir)))
  (set-opt "src" (merge-pathnames (format nil "src/~A-~A/" (getf argv :target) (getf argv :version)) (homedir)))
  (cons t argv))

(defun clisp-download (argv)
  (set-opt "download.uri" (format nil "~@{~A~}" (clisp-uri)
                                  (getf argv :version) "/clisp-"  (getf argv :version) ".tar.bz2"))
  (set-opt "download.archive" (let ((pos (position #\/ (opt "download.uri") :from-end t)))
                                (when pos
                                  (merge-pathnames (format nil "archives/~A" (subseq (opt "download.uri") (1+ pos))) (homedir)))))
  `((,(opt "download.archive") ,(opt "download.uri"))))

(defun clisp-lib (argv)
  (when (and (find :linux *features*)
             (not (or (find :arm *features*))))
    (ros:roswell '("install ffcall+") :interactive nil))
  (ros:roswell '("install sigsegv+") :interactive nil)
  (cons t argv))

(defun clisp-expand (argv)
  (format t "~%Extracting archive: ~A~%" (opt "download.archive"))
  (expand (opt "download.archive")
          (merge-pathnames "src/" (homedir)))
  (cons t argv))

(defun clisp-patch (argv)
  #+darwin
  (let ((file (merge-pathnames "tmp/clisp.patch" (homedir)))
        (uri (clisp-patch1-uri)))
    (format t "~&Downloading patch: ~A~%" uri)
    (download uri file)
    (chdir (opt "src"))
    (format t "~%Applying patch:~%")
    (uiop/run-program:run-program (format nil "git apply ~A" file) :output t))
  (cons t argv))

(defun clisp-config (argv)
  (format t "~&configure~%")
  (with-open-file (out (ensure-directories-exist
                        (merge-pathnames (format nil "impls/log/~A-~A/config.log"
                                                 (getf argv :target) (opt "as"))
                                         (homedir)))
                       :direction :output :if-exists :append :if-does-not-exist :create)
    (format out "~&--~&~A~%" (date))
    (let* ((src (opt "src"))
           (cmd (format nil "./configure --with-libsigsegv-prefix=~A ~A '--prefix=~A'"
                        (merge-pathnames (format nil "lib/~A/~A/~A/~A" (uname-m) (uname) "sigsegv" "2.10") (homedir))
                        (or #+linux(format nil "--with-libffcall-prefix=~A"
                                           (merge-pathnames (format nil "lib/~A/~A/~A/~A" (uname-m) (uname) "ffcall" "1.10") (homedir)))
                            "")
                        (opt "prefix")))
           (*standard-output* (make-broadcast-stream out #+sbcl(make-instance 'count-line-stream))))
      (chdir src)
      (uiop/run-program:run-program cmd :output t :ignore-error-status t)))
  (cons t argv))

(defun clisp-make (argv)
  (format t "~&make~%")
  (with-open-file (out (ensure-directories-exist
                        (merge-pathnames (format nil "impls/log/~A-~A/make.log"
                                                 (getf argv :target) (opt "as"))
                                         (homedir)))
                       :direction :output :if-exists :append :if-does-not-exist :create)
    (format out "~&--~&~A~%" (date))
    (let* ((src (namestring (namestring (merge-pathnames "src/" (opt "src")))))
           ;; Prevent user-defined multiprocessing etc. via MAKEFLAGS,
           ;; which causes build failure in clisp Makefile
           (cmd (format nil "ulimit -s 16384 && MAKEFLAGS=\"\" make"))
           (*standard-output* (make-broadcast-stream out #+sbcl(make-instance 'count-line-stream))))
      (chdir src)
      (uiop/run-program:run-program cmd :output t :ignore-error-status t)))
  (cons t argv))

(defun clisp-install (argv)
  (let* ((impl-path (opt "prefix"))
         (src (namestring (merge-pathnames "src/" (opt "src"))))
         (log-path (merge-pathnames (format nil "impls/log/~A-~A/install.log" (getf argv :target) (opt "as")) (homedir))))
    (format t "~&Installing ~A/~A..." (getf argv :target) (opt "as"))
    (format t "~&prefix: ~s~%" impl-path)
    (ensure-directories-exist impl-path)
    (ensure-directories-exist log-path)
    (chdir src)
    (with-open-file (out log-path :direction :output :if-exists :append :if-does-not-exist :create)
      (format out "~&--~&~A~%" (date))
      (let ((*standard-output* (make-broadcast-stream
                                out #+sbcl(make-instance 'count-line-stream))))
        ;; Prevent user-defined multiprocessing etc. via MAKEFLAGS,
        ;; which causes build failure in clisp Makefile
        (uiop/run-program:run-program "MAKEFLAGS=\"\" make install" :output t)))
    (format *error-output* "done.~%"))
  (cons t argv))

(defun clisp-clean (argv)
  (format t "~&Cleaning~%")
  (let ((src (namestring (merge-pathnames "src/" (opt "src")))))
    (chdir src)
    (let* ((out (make-broadcast-stream))
           (*standard-output* (make-broadcast-stream
                               out #+sbcl(make-instance 'count-line-stream))))
      (uiop/run-program:run-program
       ;; Prevent user-defined multiprocessing etc. via MAKEFLAGS,
       ;; which causes build failure in clisp Makefile
       (list (sh) "-lc" (format nil "cd ~S;MAKEFLAGS=\"\" make clean" src)) :output t))
    (format t "done.~%"))
  (cons t argv))

(defun clisp-help (argv)
  (format t "no options for clisp~%")
  (cons t argv))

(defun clisp (type)
  (case type
    (:help '(clisp-help))
    (:install `(,(decide-version 'clisp-get-version)
                clisp-argv-parse
                start
                ,(decide-download 'clisp-download)
                clisp-lib
                clisp-expand
                clisp-patch
                clisp-config
                clisp-make
                clisp-install
                clisp-clean
                setup))
    (:list 'clisp-get-version)))
