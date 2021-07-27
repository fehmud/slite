(pkg:define-package :deadbeef/impl
    (:use #:cl)
  (:export
   #:*cache-dir*
   #:register-external
   #:prepare-externals))

(defvar *externals* nil)

(defvar *cache-dir* nil)

(defvar *whitespaces* '(#\Space #\Newline #\Backspace #\Tab
                        #\Linefeed #\Page #\Return #\Rubout))

(defun trim (value)
  (string-trim *whitespaces* value))

(defun register-external (repo commit)
  (pushnew (cons repo commit)
           *externals*
           :test #'equal))

(defun run-program-with-errors (cmd)
  (multiple-value-bind (out err ret)
      (uiop:run-program cmd
                        :output 'string
                        :ignore-error-status t
                        :error-output 'string)
    (unless (eql 0 ret)
      (error "Bash command `~a` failed: ~%stdout: ~a~%~% stderr:~%~A~%"
             cmd
             out err))
    (trim out)))

(defun prepare-git-repo (repo commit cache-dir)
  (let ((git-dir (path:catdir cache-dir ".git/")))
   (cond
     ((path:-d git-dir)
      (run-program-with-errors (list
                                "git" "--work-tree" (namestring cache-dir)
                                "--git-dir" (namestring git-dir)
                                "fetch"
                                repo)))
     (t
      (run-program-with-errors (list
                                "git" "clone"
                                repo
                                (namestring  cache-dir)))))

    ;; checkout the right commit
    (run-program-with-errors (list
                              "git" "--work-tree" (namestring cache-dir)
                              "--git-dir" (namestring git-dir)
                              "checkout"
                              commit))))

(defun name-from-repo-name (repo-name)
  (let ((pos (position #\/ repo-name :from-end t)))
    (subseq repo-name (+ 1 pos))))

(defun prepare-externals (cache-dir)
  (setf *cache-dir* cache-dir)
  (loop for (repo . commit) in *externals*
        do
           (let* ((name (name-from-repo-name repo))
                  (cache-dir (path:catdir *cache-dir* (format nil "~a/" name))))
             (pushnew cache-dir
                      asdf:*central-registry*
                      :test 'equal)
             (prepare-git-repo repo commit cache-dir))))
