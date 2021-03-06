(in-package #:cstab)
(named-readtables:in-readtable rutilsx-readtable)

(declaim (optimize (speed 3) (safety 1)))
(declaim (inline ub32 hash8 fnv-1a-ub8 sxhash-ub8))

(deftype octet () '(unsigned-byte 8))
(deftype octet-array () '(simple-array u8))
(deftype quad () '(unsigned-byte 32))

(defparameter +golden-ratio+ #x9e3779b9)
(defparameter +jenkins-seed+ #xcafebabe)

(defun hash8 (hash)
  (declare (type quad hash))
  (ldb (byte 8 0) (logxor (ash hash -8) hash)))

(defun ub32 (x)
  (ldb (byte 32 0) x))


;;; Jenkins hash

(defmacro mix1 (a b c shift)
  `(progn
     (:= ,a (ub32 (- ,a ,b ,c)))
     (:= ,a (logxor ,a (ub32 (ash ,c ,shift))))))

(defmacro mix (a b c)
  `(progn (mix1 ,a ,b ,c -13)
          (mix1 ,b ,c ,a 8)
          (mix1 ,c ,a ,b -13)
          (mix1 ,a ,b ,c -12)
          (mix1 ,b ,c ,a 16)
          (mix1 ,c ,a ,b -5)
          (mix1 ,a ,b ,c -3)
          (mix1 ,b ,c ,a 10)
          (mix1 ,c ,a ,b -15)))

(declaim (ftype (function ((simple-array octet) &optional quad) quad)
                jenkins-hash))
(defun jenkins-hash (bytes &optional (initval +jenkins-seed+))
  (let ((a +golden-ratio+)
        (b +golden-ratio+)
        (c initval)
        (len (length bytes)))
    (declare (type quad a b c len))
    (loop :for k :from 0 :below (- len 11) :by 12 :do
      (:= a (ub32 (+ a (aref bytes k)
                     (ub32 (ash (aref bytes (+ k 1)) 8))
                     (ub32 (ash (aref bytes (+ k 2)) 16))
                     (ub32 (ash (aref bytes (+ k 3)) 24)))))
      (:= b (ub32 (+ b (aref bytes (+ k 4))
                     (ub32 (ash (aref bytes (+ k 5)) 8))
                     (ub32 (ash (aref bytes (+ k 6)) 16))
                     (ub32 (ash (aref bytes (+ k 7)) 24)))))
      (:= c (ub32 (+ c (aref bytes (+ k 8))
                     (ub32 (ash (aref bytes (+ k 9)) 8))
                     (ub32 (ash (aref bytes (+ k 10)) 16))
                     (ub32 (ash (aref bytes (+ k 11)) 24)))))
      (mix a b c)
      :finally
      (:= c (ub32 (+ c len)))
      (tagbody (case (- len k)
                 (11 (go :k11))
                 (10 (go :k10))
                 (9 (go :k9))
                 (8 (go :k8))
                 (7 (go :k7))
                 (6 (go :k6))
                 (5 (go :k5))
                 (4 (go :k4))
                 (3 (go :k3))
                 (2 (go :k2))
                 (1 (go :k1))
                 (0 (go :k0)))
       :k11 (:= c (ub32 (+ c (ash (aref bytes (+ k 10)) 24))))
       :k10 (:= c (ub32 (+ c (ash (aref bytes (+ k 9)) 16))))
       :k9  (:= c (ub32 (+ c (ash (aref bytes (+ k 8)) 8))))
       :k8  (:= b (ub32 (+ b (ash (aref bytes (+ k 7)) 24))))
       :k7  (:= b (ub32 (+ b (ash (aref bytes (+ k 6)) 16))))
       :k6  (:= b (ub32 (+ b (ash (aref bytes (+ k 5)) 8))))
       :k5  (:= b (ub32 (+ b (aref bytes (+ k 4)))))
       :k4  (:= a (ub32 (+ a (ash (aref bytes (+ k 3)) 24))))
       :k3  (:= a (ub32 (+ a (ash (aref bytes (+ k 2)) 16))))
       :k2  (:= a (ub32 (+ a (ash (aref bytes (+ k 1)) 8))))
       :k1  (:= a (ub32 (+ a (aref bytes k))))
       :k0  (mix a b c)))
    (values a b c)))

(declaim (ftype (function ((simple-array octet) quad quad) quad)
                jenkins-hash2))
(defun jenkins-hash2 (x seed mod)
  (with ((_ b c (jenkins-hash x seed)))
    (values (mod b mod)
            (mod c mod))))


;;; FNV-1a

(defun fnv-1a (bytes &key (fnv-prime 16777619) (offset-basis 2166136261))
  (let ((hash offset-basis))
    (declare (type quad hash fnv-prime offset-basis)
             (type (simple-array octet) bytes))
    (dovec (byte bytes)
      (declare (type octet byte))
      (:= hash (logxor hash byte))
      (:= hash (ub32 (* hash fnv-prime))))
    hash))

(defun fnv-1a-ub8 (bytes)
  (hash8 (fnv-1a bytes)))
