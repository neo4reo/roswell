(ros:include () "util")
(defpackage :roswell.util
  (:use :cl)
  (:import-from :ros :opt)
  (:export
   :uname :uname-m :homedir :config :impl :which :list% :config-env
   :parse-version-spec :download :expand :sh :chdir :system :module
   :core-extention :clone-github :opt :read-call :set-opt :copy-dir
   :roswell-installable-searcher))
(in-package :roswell.util)

(defun read-call (func &rest params)
  (ignore-errors (apply (let (*read-eval*) (read-from-string func)) params)))

(defun copy-dir (from to)
  (when (wild-pathname-p from)
    (error "wild card not supported"))
  (loop with path = (truename from)
        for l in (delete-if (lambda (x) (eql :absolute (first (pathname-directory (make-pathname :defaults x)))))
                            (mapcar (lambda(x) (enough-namestring (namestring x) path))
                                    (directory (merge-pathnames "**/*.*" path))))
        do (if (or (pathname-name l)
                   (pathname-type l))
               (ignore-errors
                (read-call "uiop:copy-file"
                           (merge-pathnames l path)
                           (ensure-directories-exist (merge-pathnames l to)))))))

(defun module (prefix name)
  (read-call "ql:register-local-projects")
  (let ((imp (format nil "roswell.~A.~A" prefix name)))
    (or
     (and (or (read-call "ql-dist:find-system" imp)
              (read-call "ql:where-is-system" imp))
          (read-call "ql:quickload" imp :silent t))
     (ros:include (format nil "~A-~A" prefix name)))
    (ignore-errors
     (let (*read-eval*) (read-from-string (format nil "~A::~A" imp name))))))

(defun set-opt (item val)
  (let ((found (assoc item (ros::ros-opts) :test 'equal)))
    (if found
        (setf (second found) val)
        (push (list item val) ros::*ros-opts*))))

(defun uname ()
  (ros:roswell '("roswell-internal-use" "uname") :string t))

(defun uname-m ()
  (ros:roswell '("roswell-internal-use" "uname" "-m") :string t))

(defun homedir ()
  (opt "homedir"))

(defun impl (imp)
  (ros:roswell `("roswell-internal-use" "impl" ,(or imp "")) :string t))

(defun which (cmd)
  (let ((result (ros:roswell `("roswell-internal-use" "which" ,cmd) :string t)))
    (unless (zerop (length result))
      result)))

(defun download (uri file &key proxy (verbose t))
  (declare (ignorable proxy))
  (ensure-directories-exist file)
  (ros:roswell `("roswell-internal-use" "download" ,uri ,file ,@(unless verbose '("1"))) :interactive nil))

(defun expand (archive dest &key verbose)
  #+win32
  (progn
    (ros:include "install+7zip")
    (unless (probe-file (read-call "roswell.install.7zip+::7za"))
      (ros:roswell '("install 7zip+"))))
  (ros:roswell `(,(if verbose "-v" "")"roswell-internal-use tar" "-xf" ,archive "-C" ,dest)
               (or #-win32 :interactive nil) nil))

(defun core-extention (&optional (impl (opt "impl")))
  (ros:roswell `("roswell-internal-use" "core-extention" ,impl) :string t))

(defun config (c)
  (ros:roswell `("config" "show" ,c) :string t))

(defun (setf config) (val item)
  (ros:roswell `("config" "set" ,item ,val) :string t)
  val)

(defun list% (&rest params)
  (string-right-trim #.(format nil "~A" #\Newline)
                     (ros:roswell `("list" ,@params) :string nil)))

(defun chdir (dir &optional (verbose t))
  (when verbose
    (format t "~&chdir ~A~%" dir))
  (funcall (intern (string :chdir) :uiop/os) dir))

(defun sh ()
  (or #+win32
      (unless (ros:getenv "MSYSCON")
        (format nil "~A" (#+sbcl sb-ext:native-namestring #-sbcl namestring
                          (merge-pathnames (format nil "impls/~A/~A/msys~A/usr/bin/bash" (uname-m) (uname)
                                                   #+x86-64 "64" #-x86-64 "32") (homedir)))))
      (which "bash")
      "sh"))

(defvar *version*
  `(:roswell ,(ros:version)
    :lisp ,(lisp-implementation-type)
    :version ,(lisp-implementation-version)))

(defun parse-version-spec (string)
  "Parse the given version specification string and returns a list of strings (LISP VERSION).
If it does not contain a version substring, VERSION becomes a null.
If it is a version string only (detected when it starts from digit-char), LISP becomes NIL.
Examples:
ccl-bin/1.11 -> (\"ccl-bin\" \"1.11\")
ccl-bin      -> (\"ccl-bin\" nil)
1.11         -> (nil \"1.11\")
"
  (let ((pos (position #\/ string)))
    (if pos
        `(,(subseq string 0 pos) ,(subseq string (1+ pos)))
        (if (digit-char-p (aref string 0))
            `(nil ,string)
            `(,string nil)))))

(defun checkoutdir ()
  (or (ignore-errors
       (let*((* (read-from-string "ql:*local-project-directories*")))
         (setf * (first (symbol-value *))
               * (merge-pathnames "../" *)
               * (truename *))))
      (homedir)))

(defun clone-github (owner name &key (alias (format nil "~A/~A" owner name)) (path "templates") branch (home (checkoutdir)))
  (format *error-output* "install from github ~A/~A~%" owner name)
  (if (which "git")
      (let ((dir (merge-pathnames (format nil "~A/~A/" path alias) home)))
        (setq branch (if branch (format nil "-b ~A" branch) ""))
        (if (funcall (intern (string :probe-file*) :uiop) dir)
            ()
            (funcall (intern (string :run-program) :uiop)
                     (format nil "git clone ~A https://github.com/~A/~A.git ~A"
                             branch
                             owner name
                             (namestring (ensure-directories-exist dir))))))
      (let* ((path/ (merge-pathnames (format nil "~A/~A.tgz" path alias) home))
             (dir (merge-pathnames ".expand/" (make-pathname :defaults path/ :name nil :type nil))))
        (funcall (intern (string :delete-directory-tree) :uiop) dir :if-does-not-exist :ignore :validate t)
        (setq branch (or branch "master"))
        (download (format nil "https://github.com/~A/archive/~A.tar.gz" alias branch)
                  path/)
        (expand path/ (ensure-directories-exist dir))
        (rename-file (first (directory (merge-pathnames "*/" dir)))
                     (merge-pathnames (format nil "~A/~A/" path alias) home))
        (delete-file path/)
        (funcall (intern (string :delete-directory-tree) :uiop) dir :if-does-not-exist :ignore :validate t)
        t)))

(defun config-env ()
  #+win32
  (let* ((w (opt "wargv0"))
         (a (opt "argv0"))
         (path (read-call "uiop:native-namestring"
                          (make-pathname :type nil :name nil :defaults (if (zerop (length w)) a w)))))
    (ros:setenv "MSYSTEM" #+x86-64 "MINGW64" #-x86-64 "MINGW32")
    (ros:setenv "MSYS2_PATH_TYPE" "inherit")
    (ros:setenv "PATH" (format nil "~A;~A"(subseq path 0 (1- (length path))) (ros:getenv "PATH")))))
