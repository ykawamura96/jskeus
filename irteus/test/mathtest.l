(require :unittest "lib/llib/unittest.l")

(init-unit-test)

(defun eps-matrix= (m1 m2 &optional (eps *epsilon*))
   (eps= (distance (array-entity m1) (array-entity m2)) 0.0 eps))

(defun eps-complex-matrix= (cm1 cm2 &optional (eps *epsilon*))
  (and
   (eps= (distance (array-entity (car cm1)) (array-entity (car cm2))) 0.0 eps)
   (eps= (distance (array-entity (cadr cm1)) (array-entity (cadr cm2))) 0.0 eps)))

(deftest mathtest
  (let (m1 m2 m3 m4 m5 m6 m7 cm8 inv-cm8 m9 r u s v val vec val-complex vec-complex)
    ;;
    ;; diagnoal, minor-matrix, atan2, outer-product-matrix, quaternion, matrix-log, pseudo-inverse, sr-inverse, manipulability, eigen decompose, sv/ql solve, lu-solve2, matrix-determinant, qr/ql-decompose, inverse-matrix-complex, eigen-decompose-complex
    ;;
    (assert (eps-matrix= (diagonal #f(1 2)) #2f((1 0) (0 2))) "check diagonal")

    (assert (eps-matrix= (minor-matrix #2f((1 2 3)(4 5 6)(7 8 9)) 2 3) #2f((1.0 2.0) (4.0 5.0))) "minor matrix")

    (assert (eps= (atan2 1 0) pi/2) "atan2 0 1")
    (assert (eps= (atan2 0 1)    0) "atan2 1 0")
    (assert (eps= (atan2 1 1) (/ pi 4)) "atan2 1 1")

    ;; outer-product-matrix
    (assert (outer-product-matrix #f(1 2 3)) #2f((0.0 -3.0 2.0) (3.0 0.0 -1.0) (-2.0 1.0 0.0)) "outer product matrix")

    ;; quaternion
    (assert (eps-matrix= (quaternion2matrix #f(7 9 5 1)) #2f((104.0 76.0 88.0) (104.0 -8.0 -116.0) (-52.0 136.0 -56.0))) "quaternion2matrix") ;;  the norm is not 1 warning is ok
    ;; http://www.wolframalpha.com/input/?i=quaternion++-1j%2B3i%2B4-3k
    (assert (eps-v= (scale (/ 1.0 0.169031) (matrix2quaternion #2f((0.428571 0.514286 -0.742857) (-0.857143 -0.028571 -0.514286) (-0.285714 0.857143 0.428571)))) #f(4 3 -1 -3)) "matrix2quaternion")

    (setq m1 (rotate-matrix (rotate-matrix (rotate-matrix (unit-matrix 3) 0.2 :x) 0.4 :y) 0.6 :z))
    (assert (eps-v= (matrix2quaternion m1) #f(0.925754 0.151891 0.159933 0.307131)) "matrix2quaternion")
    (assert (eps-matrix= (quaternion2matrix #f(0.925754 0.151891 0.159933 0.307131)) m1) "quaternion2matrix")
    (assert (eps-matrix= (quaternion2matrix (matrix2quaternion m1)) m1) "matrix <-> quaternion")

    ;; matrix log
    (assert (eps-matrix= (matrix-exponent (matrix-log m1)) m1) "matrix log/exponent")

    ;; pseudo-inverse
    (setq m2 #2f((1 1 1 1)(5 7 7 9))) ;; http://help.matheass.eu/en/Pseudoinverse.html
    (assert (eps-matrix= (m* m2 (pseudo-inverse m2)) (unit-matrix 2)) "psesudo-inverse")

    ;; sr inverse
    (assert (eps-matrix= (m* m1 (sr-inverse m1)) (scale-matrix 0.5 (unit-matrix 3))) "sr-inverse")
    (assert (not (eps-matrix= (m* m2 (sr-inverse m2)) (unit-matrix 2))) "sr-inverse")
    
    ;; matrix-determinant
    (assert (eps= (manipulability m1) 1.0) "manipulability")

    ;; eigen decompose
    ;; http://en.wikipedia.org/wiki/Eigendecomposition_of_a_matrix#Example
    (setq m3 #2f((1 0)( 1 3)))
    (setq val (car (eigen-decompose m3)) vec (cadr (eigen-decompose m3)))
    (assert (eps-matrix= (m* m3 vec) (m* vec (diagonal val))) "eigen-decompose")

    ;; 9.656790+06 is too large for 32bit machine
    (when (/= lisp::sizeof-* 4)
      (setq m3 #2f((9.656790e+06 -2.024883e+05 5.475222e+05 -73324.1) ;;Sent: Tuesday, June 27, 2006 9:56 PM Subject: Re: 特異値と固有値
		   (-2.024883e+05 9.210039e+06 -3.152789e+05 -1.061633e+05)
		   (5.475222e+05 -3.152789e+05 1.053183e+07 11188.9)
		   (-73324.1 -1.061633e+05 11188.9 1.115641e+07)))
      (setq val (car (eigen-decompose m3)) vec (cadr (eigen-decompose m3)))
      (assert (eps-matrix= (m* m3 vec) (m* vec (diagonal val))) "eigen-decompose large"))

    ;; sv-solve
    ;; sv-dcompose http://en.wikipedia.org/wiki/Singular_value_decomposition#Example
    (setq m4 #2f((1 0 0 0 2)(0 0 3 0 0)(0 0 0 0 0)(0 4 0 0 0)))
    (setq r (sv-decompose m4))
    (setq u (elt r 0) s (elt r 1) v (elt r 2))
    (assert (eps-matrix= m4 (m* (m* u (diagonal s)) (transpose v))) "sv-decompose")
    
    ;; memory error check?
    (dotimes (i 10000) (sv-decompose #2f((1 2 3) (4 5 6)(7 8 9))))
    (dotimes (i 10000) (ql-decompose #2f((1 2 3) (4 5 6)(7 8 9))))
    ;; lu-solve?

    ;; http://pythonhosted.org/ad/linalg.html
    ;; lu-decompose2
    (setq m5 #2f((1 2 1)(4 6 3)(9 8 2)))
    (assert (eps-v= (lu-solve2 m5 (lu-decompose2 m5) #f( 3 2 1)) #f(-7 11 -12)) "lu-solve2") ;; this changes m5
    (setq m5 #2f((1 2 1)(4 6 3)(9 8 2)))
    (assert (eps-v= (sv-solve m5 #f( 3 2 1)) #f(-7 11 -12)) "sv-solve")

    ;; matrix-determinant http://en.wikipedia.org/wiki/Determinant
    (assert (eps= (matrix-determinant #2f((-2  2 -3)(-1 1 3)(2 0 -1))) 18.0) "matrix-determinant")

    ;; qr-decompose (car) is real part of eigenvalue , qr-decompose (cadr) is imaginary part of eigenvalue
    (assert (eps-v= #f(3 1 2) (car (qr-decompose #2f((2 0 1)(0 2 0)(1 0 2))))) "qr-decompose")
    ;; ql-decompose
    (setq m6 #2f((2 0 1)(0 2 0)(1 0 2))) 
    (setq val (car (ql-decompose m6)) vec (cadr (ql-decompose m6)))
    (assert (eps-matrix= (m* m6 vec) (m* vec (diagonal val))) "ql-decompose")

    ;; pseudo-inverse2
    (setq m2 #2f((1 1 1 1)(5 7 7 9))) ;; http://help.matheass.eu/en/Pseudoinverse.html
    (assert (pseudo-inverse2 m2) "psesudo-inverse2 (might be svdcmp failing)")
    (assert (eps-matrix= (m* m2 (pseudo-inverse2 m2)) (unit-matrix 2)) "psesudo-inverse2")

    ;; this is the case where svdcmp failed to converge
    (setq m7 #2f((1.0 0.0 0.0 0.0 0.0 0.0) (0.0 1.0 0.0 0.0 0.0 0.0) (0.0 0.0 1.0 0.0 0.0 0.0) (0.0 -0.0647909045219421 -0.1271851658821106 1.0 0.0 0.0) (0.0647909045219421 0.0 0.0192958638072014 0.0 1.0 0.0) (0.1271851658821106 -0.0192958638072014 0.0 0.0 0.0 1.0)))
    (assert (pseudo-inverse2 m7) "psesudo-inverse2 (might be svdcmp failing)")
    (assert (eps-matrix= (m* m7 (pseudo-inverse2 m7)) (unit-matrix 6)) "psesudo-inverse2")

    ;; inverse matrix of complex matrix
    (setq cm8 (list #2f((1 2 3) (5 6 7) (9 4 -5)) #2f((-3 1 0) (0 -2 0) (0 0 0.1)))) ;; cm8 is complex matrix (list A B) = A + B*j  (j is imaginary unit)
    (setq inv-cm8 (inverse-matrix-complex cm8)) ;; inv(cm8)
    (assert (eps-complex-matrix=
             (m*-complex cm8 inv-cm8) ;; cm8 * inv(cm8)
             (list (unit-matrix 3) (make-matrix 3 3)) ;; E
             ) "inverse-matrix-complex")

    ;; eigen decompose with complex number
    (setq m9 #2f((1 2 3 4) (5 6 7 8) (9 4 -5 3) (-1 0 3 -5))) ;; this matrix has complex number eigenvalue
    (setq val-complex (car (eigen-decompose-complex m9))) ;; Lambda
    (setq vec-complex (cadr (eigen-decompose-complex m9))) ;; V
    (assert (eps-complex-matrix=
             (m*-complex (list m9 (make-matrix 4 4)) vec-complex) ;; m9 * V
             (m*-complex vec-complex (mapcar #'(lambda (x) (diagonal x)) val-complex)) ;; V * Lambda
             ) "eigen-decompose-complex")
    ))

(eval-when (load eval)
  (run-all-tests)
  (exit))
