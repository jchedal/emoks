;;; core-lib.el --- Core module that defines utility functions and macros -*- lexical-binding: t -*-
;;; Commentary:
;; Defines functions and macros used throughout the configuration
;;; Code:

(require 'cl-lib)
(use-package dash)
(use-package dash-functional)

(defmacro load! (&rest modules)
  "Load the MODULES."
  `(igneous--load-modules ',modules))

(defmacro with-feature! (feature &rest body)
  "Execute BODY if FEATURE is activated."
  (declare (indent 1))
  `(when (igneous--feature-activated-p (igneous--current-category) (igneous--current-module) ,feature)
     ,@body))

(defmacro with-os! (os &rest body)
  "Execute BODY if current os is OS."
  (declare (indent 1))
  `(when (if (consp ',os) (memq system-type ',os) (eq system-type ',os))
     ,@body))

(defun igneous--features (category module)
  "Return the features given a CATEGORY and MODULE by looking in `igneous--modules'."
  (->> igneous--modules
       (--filter (and (-> it car (eq category)) (-> it cadr (eq module))))
       cddar))

(defun igneous--feature-activated-p (category module feature)
  "Return nil if the FEATURE is not activated in the right CATEGORY and MODULE, t otherwise."
  (memq feature (igneous--features category module)))

(defun igneous--modules (category)
  "Return the modules given a CATEGORY by looking in `igneous--modules'."
  (->> igneous--modules
       (--filter (eq (car it) category))
       (-map #'cadr)))

(defun igneous--module-activated-p (category module)
  "Return nil if the MODULE is not activated in the right CATEGORY, t otherwise."
  (memq module (igneous--modules category)))

(defun igneous--current-module ()
  "Return the current module."
  (when (string-prefix-p igneous-modules-dir load-file-name)
    (-> load-file-name f-split last car intern)))

(defun igneous--current-category ()
  "Return the current category."
  (when (string-prefix-p igneous-modules-dir load-file-name)
    (cl-flet ((add-prefix (string prefix) (concat prefix string)))
      (-> load-file-name f-split (last 2) car (add-prefix ":") intern))))

(defun igneous--hierarchical-cons-to-pairs (predicate list default)
  "Return a list of pairs based on LIST where the left element is the last element which satisfies PREDICATE."
  (cond ((null list) nil)
        ((funcall predicate (car list))
         (igneous--hierarchical-cons-to-pairs predicate (cdr list)
                                              (car list)))
        ((consp (car list))
         (cons `(,default . ,(car list))
               (igneous--hierarchical-cons-to-pairs predicate (cdr list) default)))
        (t (cons `(,default . (,(car list)))
                 (igneous--hierarchical-cons-to-pairs predicate (cdr list) default)))))

(defun igneous--load-modules (modules)
  "Load the MODULES, internals of `load!'."
  (setq igneous--modules (igneous--hierarchical-cons-to-pairs 'keywordp modules :.))
  (mapcar #'igneous--load-pair igneous--modules))

(defun igneous--load-pair (pair)
  "Convert a PAIR (:category . '(module features?)) to a string \"category/module\"."
  (pcase-let ((`(,category . ,module) pair))
    (-> category
        symbol-name
        (substring 1)
        (concat "/" (symbol-name (car module)))
        igneous--load-module)))

(defun igneous--load-module (module-name)
  "Load MODULE-NAME by looking in `igneous-modules-dir'."
  (interactive "FEnter path to module starting from module directory: ")
  (load (expand-file-name module-name igneous-modules-dir)))

(provide 'core-lib)
;;; core-lib.el ends here