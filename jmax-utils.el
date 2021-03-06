;;; jmax-utils.el --- Utility functions in jmax

;;; Commentary:
;; 

;;; Code:


(defun kill-all-buffers ()
  "Kill all buffers. leave one frame open."
  (interactive)
  (mapc 'kill-buffer (buffer-list))
  (delete-other-windows))


(defun kill-other-buffers ()
    "Kill all other buffers but this one. leave one frame open."
    (interactive)
    (mapc 'kill-buffer 
          (delq (current-buffer) (buffer-list)))
    (delete-other-windows))


(defun jeldoc (library)
  "Generate an org buffer containing the requires, variables and functions defined in LIBRARY.
LIBRARY must be loaded before running this function."
  
  (interactive "sLibrary to build doc for: ")
  
  (let* ((lib-file (locate-library library))
	 ;; these are the things defined in the library
	 (elements (cdr
		    (assoc
		     (locate-library library)
		     load-history)))
	 ;; variables
	 (vars (-filter 'symbolp elements))
	 ;; things the library requires
	 (requires
	  (mapcar 'cdr
		  (-filter (lambda (x)
			     (and (consp x)
				  (eq 'require (car x))))
			   elements)))
	 ;; functions defined in the library
	 (funcs (mapcar
		 'cdr
		 (-filter (lambda (x)
			    (and (consp x)
				 (eq 'defun (car x))))
			  elements))))
    
    (switch-to-buffer "*org-doc*")
    (erase-buffer)
    (insert (format "#+TITLE: Documentation for %s
#+OPTIONS: toc:nil
\\maketitle
\\tableofcontents

%s

" library  (cond
	    ;; regular lisp file
	    ((string= "el" (file-name-extension lib-file))
	     (format "Source code: [[file:%s][%s]]" lib-file library))
	    ;; compiled file. these are not easy to read so we try plain el file
	    ((and (string= "elc" (file-name-extension lib-file))
		  (file-exists-p
		   (concat (file-name-sans-extension lib-file) ".el")))
	     (format "Source code: [[file:%s][%s]]"
		     (concat (file-name-sans-extension lib-file) ".el")
		     library))
	    ;; catch anything we cannot figure out
	    (t
	     (format "Source code: file:%s" lib-file)))))


    (insert "* Requires\n")
    ;; insert link to generate a jeldoc buffer for each require
    (dolist (req requires)
      (insert (format "- [[elisp:(jeldoc \"%s\")][%s]]\n" req req)))
	    
    (insert "* Variables\n")
    (dolist (var (sort vars 'string-lessp))
      (insert (format "** %s
Documentation: %s

Value:
%S\n\n"
		      var
		      (documentation-property var 'variable-documentation)
		      (symbol-value var)
		      )))

    (insert "* Functions\n\n")
    
    (dolist (func (sort funcs 'string-lessp))
      (insert (format "** %s %s
Documentation: %s

Code:
#+BEGIN_SRC emacs-lisp
%s
#+END_SRC

"
		      func
		      (or (help-function-arglist func) "")
		      (documentation func)
		      ;; code defining the function
		      (save-window-excursion
			;; we do not have c-source, so check if func
			;; is defined in a c file here.
			(if
			    (string= "c"
				     (file-name-extension
				      (find-lisp-object-file-name
				       func
				       (symbol-function func))))
			    (symbol-function func)
			  ;;else
			  (condition-case nil
			      (let ((bp (find-function-noselect func t)))
				(set-buffer (car bp))
				(goto-char (cdr bp))
				(when (sexp-at-point)
				  (mark-sexp)
				  (buffer-substring (point) (mark))))
			    (error func))
			    )))))
    (org-mode)

    ;; replace `' with links to describe function or variable, unless
    ;; they are in a code block, then leave them alone.
    (goto-char (point-min))
    (while (re-search-forward "`\\([^' ]*\\)'" nil t)
      (let ((result (match-string 1))
	    (bg (match-beginning 1))
	    (end (match-end 1)))
	;; checking for code block changes match data, so
	;; we save it here.
	(unless (save-match-data
		  (eq 'src-block (car (org-element-at-point))))
	  (cond
	   ;; known function
	   ((fboundp (intern result))
	    (setf (buffer-substring bg end)
		  (format "[[elisp:(describe-function '%s)][%s]]"
			  result result)))
	   ;; known variable
	   ((boundp (intern result))
	    (setf (buffer-substring bg end)
		  (format "[[elisp:(describe-variable '%s)][%s]]"
			  result result)))
	   ;; unknown quoted thing, just return it back
	   (t
	    result)))))
    ;; finally jump to Requires section
    (org-open-link-from-string "[[*Requires]]")))

(provide 'jmax-utils)

;;; jmax-utils.el ends here
