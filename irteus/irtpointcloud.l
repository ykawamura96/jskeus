;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; $Id: irtgl.l 816 2012-06-10 07:56:40Z kyouhei $
;;;
;;; Copyright (c) 1987- JSK, The University of Tokyo.  All Rights Reserved.
;;;
;;; This software is a collection of EusLisp code for robot applications,
;;; which has been developed by the JSK Laboratory for the IRT project.
;;; For more information on EusLisp and its application to the robotics,
;;; please refer to the following papers.
;;;
;;; Toshihiro Matsui
;;; Multithread object-oriented language euslisp for parallel and
;;;  asynchronous programming in robotics
;;; Workshop on Concurrent Object-based Systems,
;;;  IEEE 6th Symposium on Parallel and Distributed Processing, 1994
;;;
;;; Permission to use this software for educational, research
;;; and non-profit purposes, without fee, and without a written
;;; agreement is hereby granted to all researchers working on
;;; the IRT project at the University of Tokyo, provided that the
;;; above copyright notice remains intact.  
;;;


;;; pointcloud class

(in-package "USER")

(defclass pointcloud
  :super cascaded-coords
  :slots (parray carray narray curvature
          pcolor psize awidth asize
          box height width view-coords
          drawnormalmode transparent tcarray))

(defmethod pointcloud
  (:init (&rest args
                &key ((:points mat)) ((:colors cary)) ((:normals nary))
                     ((:curvatures curv))
                     ((:height ht)) ((:width wd))
                     (point-color (float-vector 0 1 0))
                     (point-size 2.0) (fill)
                     (arrow-width 2.0) (arrow-size 0.0))
    ;; matrix was not be copied
    (cond
     ((and mat (listp mat))
      (send self :points mat))
     (mat
      (setq parray mat)))
    (cond
     ((and cary (listp cary))
      (send self :colors cary))
     (cary
      (setq carray cary))
     (t
      (setq pcolor point-color)))
    (cond
     ((and nary (listp narray))
      (send self :normals nary))
     (nary
      (setq narray nary)))
    (cond
     ((and nary (listp curv))
      (send self :curvatures curv))
     (nary
      (setq curvature curv)))

    (setq psize point-size
          awidth arrow-width
          asize arrow-size
          view-coords (make-coords)
          drawnormalmode :normal)

    (cond
     ((and ht wd)
      (send self :size-change wd ht))
     (t
      (send self :size-change (if parray (array-dimension parray 0)))))

    (when fill
      (let ((w (send self :width))
            (h (send self :height)))
        (when (and w h)
          (setq pcolor nil)
          (setq parray (make-matrix (* w h) 3))
          (setq carray (make-matrix (* w h) 3))
          )))
    (send-super* :init args)
    self)
  (:reset-box () (if (= (send self :size) 0)
                     (make-bounding-box (list #f(0 0 0) #f(1000 1000 1000)) 0.0)
                   (make-bounding-box (send self :point-list) 0.0)))
  (:box () (unless box (setq box (send self :reset-box))) box)
  (:vertices () (list (send (send self :box) :maxpoint) (send (send self :box) :minpoint)))
  (:size () (if parray (array-dimension parray 0) 0))
  (:width () width)
  (:height () height)
  (:size-change
   (&optional wd ht)
   (cond
    ((and wd ht)
     (setq width wd
           height ht))
    (wd
     (setq width wd
           height 1))
    (ht
     (setq height ht
           width 1))
    (t
     (if parray
         (setq width (array-dimension parray 0)
               height 1)
       (setq width 0
             height 0)))
    ))
  (:view-coords (&optional vc) (if vc (setq view-coords vc)) view-coords)
  (:points (&optional pts wd ht) ;; copy from pts
   (when pts
     (send self :size-change wd ht)
     (cond
      ((listp pts)
       (let ((m (make-matrix (length pts) 3))
             (cntr 0))
         (dolist (p pts)
           ;;(setf (matrix-row m cntr) p)
           (c-matrix-row m cntr p t)
           (incf cntr))
         (setq parray m)))
      ((matrixp pts)
       (let ((m (make-matrix (array-dimension pts 0) 3)))
         (sys::vector-replace (array-entity m) (array-entity pts))
         (setq parray m)))))
   parray)
  (:colors (&optional cls) ;; copy from cls
   (when cls
     (cond
      ((listp cls)
       (setq pcolor nil)
       (let ((m (make-matrix (length cls) 3))
             (cntr 0))
         (dolist (p cls)
           ;;(setf (matrix-row m cntr) p)
           (c-matrix-row m cntr p t)
           (incf cntr))
         (setq carray m)))
      ((matrixp cls)
       (setq pcolor nil)
       (let ((m (make-matrix (array-dimension cls 0) 3)))
         (sys::vector-replace (array-entity m) (array-entity cls))
         (setq carray m)))))
   carray)
  (:normals (&optional nmls) ;; copy from nmls
   (when nmls
     (cond
      ((listp nmls)
       (let ((m (make-matrix (length nmls) 3))
             (cntr 0))
         (dolist (p nmls)
           ;;(setf (matrix-row m cntr) p)
           (c-matrix-row m cntr p t)
           (incf cntr))
         (setq narray m)))
      ((matrixp nmls)
       (let ((m (make-matrix (array-dimension nmls 0) 3)))
         (sys::vector-replace (array-entity m) (array-entity nmls))
         (setq narray m)))))
   narray)
  (:curvatures (&optional curv)
   (when curv
     (cond
      ((listp curv)
       (let ((vec (instantiate float-vector (length curv)))
             (cntr 0))
         (dolist (p curv)
           (setf (elt curv cntr) p)
           (incf cntr))
         (setq curvature vec)))
      ((vectorp curv)
       (let ((vec (instantiate float-vector (length curv))))
         (sys::vector-replace vec curv)
         (setq curvature vec)))))
   curvature)
  (:point-list ()
   (let (lst)
     (dotimes (i (send self :size))
       ;;(push (matrix-row parray i) lst)
       (push (c-matrix-row parray i) lst)
       )
     (reverse lst)))
  (:color-list ()
   (if carray
       (let (lst)
         (dotimes (i (array-dimension carray 0))
           ;;(push (matrix-row carray i) lst)
           (push (c-matrix-row carray i) lst)
           )
         (reverse lst))))
  (:normal-list ()
   (if narray
       (let (lst)
         (dotimes (i (array-dimension narray 0))
           ;;(push (matrix-row narray i) lst)
           (push (c-matrix-row narray i) lst)
           )
         (reverse lst))))
  (:curvature-list ()
   (if curvature
       (let (lst)
         (dotimes (i (length curvature))
           (push (elt curvature i) lst))
         (reverse lst))))
  (:centroid ()
   (let ((ret (float-vector 0 0 0)))
     (vector-array-mean parray ret)
     ret))
  (:point-color (&optional pc) (if pc (setq pcolor pc)) pcolor)
  (:point-size (&optional ps) (if ps (setq psize ps)) psize)
  (:axis-length (&optioanl al) (if al (setq asize al)) asize)
  (:axis-width (&optional aw) (if aw (setq awidth aw)) awidth)
  (:clear-color () (warn ";; this method has not been implemented !!!"))
  (:clear-normal () (warn ";; this method has not been implemented !!!"))
  (:append () (warn ";; this method has not been implemented !!!"))
  (:append-list () (warn ";; this method has not been implemented !!!"))
  (:nfilter (&rest args) (send* self :filter args)) ;; compatibility to 3dpointcloud
  (:filter (&rest args &key create &allow-other-keys)
   (let ((indices (send* self :filtered-indices args)))
     (send self :filter-with-indices indices :create create)))
  (:filter-with-indices
   (idx-lst &key (create) (negative))
   (let* ((size (send self :size))
          new-mat new-col new-nom new-cvt
          (p (float-vector 0 0 0))
          (c (if carray (float-vector 0 0 0)))
          (n (if narray (float-vector 0 0 0)))
          cv (cntr 0))
     (when negative
       (let (tmp)
         (dotimes (i size) (push (- size i 1) tmp))
         (setq idx-lst (set-difference tmp idx-lst))
         ))
     (setq new-mat (make-matrix (length idx-lst) 3)
           new-col (if carray (make-matrix (length idx-lst) 3))
           new-nom (if narray (make-matrix (length idx-lst) 3))
           new-cvt (if curvature (instantiate float-vector (length idx-lst))))
     (cond
      ((listp idx-lst)
       (dolist (i idx-lst)
         #|
         (setq p (matrix-row parray i))
         (if carray (setq c (matrix-row carray i)))
         (if narray (setq n (matrix-row narray i)))
         (setf (matrix-row new-mat cntr) p)
         (if carray (setf (matrix-row new-col cntr) c))
         (if narray (setf (matrix-row new-nom cntr) n))
         |#
         (c-matrix-row parray i p)
         (c-matrix-row new-mat cntr p t)
         (when carray
           (c-matrix-row carray i c)
           (c-matrix-row new-col cntr c t))
         (when narray
           (c-matrix-row narray i n)
           (c-matrix-row new-nom cntr n t))
         (when curvature
           (setf (elt new-cvt i) (elt curvature i)))
         (incf cntr)))
      (t ;; vector
       (let (i)
         (dotimes (idx (length idx-lst))
           (setq i (elt idx-lst idx))
           #|
           (setq p (matrix-row parray i))
           (if carray (setq c (matrix-row carray i)))
           (if narray (setq n (matrix-row narray i)))
           (setf (matrix-row new-mat cntr) p)
           (if carray (setf (matrix-row new-col cntr) c))
           (if narray (setf (matrix-row new-nom cntr) n))
           |#
           (c-matrix-row parray i p)
           (c-matrix-row new-mat cntr p t)
           (when carray
             (c-matrix-row carray i c)
             (c-matrix-row new-col cntr c t))
           (when narray
             (c-matrix-row narray i n)
             (c-matrix-row new-nom cntr n t))
           (when curvature
             (setf (elt new-cvt i) (elt curvature i)))
           (incf cntr)))))
     (if create
         (let ((ret (instance pointcloud :init
                              :points new-mat
                              :colors new-col
                              :normals new-nom
                              :curvatures new-cvt)))
           (setq (ret . view-coords) (send view-coords :copy-worldcoords))
           (send ret :transform (send self :worldcoords))
           ret)
       (progn
         (setq parray new-mat)
         (if new-col (setq carray new-col))
         (if new-nom (setq narray new-nom))
         (if new-cvt (setq curvature new-cvt))
         self)
       )))
  (:filtered-indices
   (&key key ckey nkey pckey pnkey pcnkey negative &allow-other-keys)
   (let* (ret-lst
          (points-num (send self :size))
          (p (instantiate float-vector 3))
          (c (if carray (instantiate float-vector 3)))
          (n (if narray (instantiate float-vector 3))))
     (dotimes (i points-num)
       (c-matrix-row parray i p)
       (if c (c-matrix-row carray i c))
       (if n (c-matrix-row narray i n))

       (if (and (or (null key) (funcall key p))
                (or (null ckey) (or (null c) (funcall ckey c)))
                (or (null nkey) (or (null n) (funcall nkey n)))
                (or (null pckey) (or (null c) (funcall pckey p c)))
                (or (null pnkey) (or (null n) (funcall pnkey p n)))
                (or (null pcnkey) (or (null c) (null n) (funcall pcnkey p c n))))
           (unless negative (push i ret-lst))
         (if negative (push i ret-lst))))
     (nreverse ret-lst)
     ))
  (:viewangle-inlier
   (&key (min-z 0.0) (hangle 44.0) (vangle 35.0))
   (let ((hlim (tan (deg2rad (/ hangle 2.0))))
         (vlim (tan (deg2rad (/ vangle 2.0))))
         (pos (float-vector 0 0 0))
         (size (send self :size))
         (mat parray)
         ret)
     (dotimes (i size)
       (c-matrix-row mat i pos)
       (if (and (> (elt pos 2) min-z)
                (< (abs (/ (elt pos 0) (elt pos 2))) hlim)
                (< (abs (/ (elt pos 1) (elt pos 2))) vlim))
           (push i ret)))
     (nreverse ret)))
  (:image-position-inlier
   (&key (ipkey) (height 144) (width 176)
         (cy (/ (float (- height 1)) 2))
         (cx (/ (float (- width 1)) 2))
         negative)
   ;; size check ???
   (let (lst)
     (dotimes (y height)
       (dotimes (x width)
         (if (and ipkey
                  (funcall ipkey x y))
             (unless negative (push (+ (* y width) x) lst))
           (if negative (push (+ (* y width) x) lst)))))
     (nreverse lst)))
  (:image-circle-filter
   (dist &key (height 144) (width 176)
         (cy (/ (float (- height 1)) 2))
         (cx (/ (float (- width 1)) 2))
         create negative)
   (send self :filter-with-indices
         (send self :image-position-inlier
               :ipkey #'(lambda (x y)
                          (< (norm (float-vector (- x cx) (- y cy))) dist))
               :height height :width width :negative negative)
         :create create))
  (:step-inlier (step offx offy)
   (let (ret ptr)
     (do ((j offy (+ j step)))
         ((>= j height))
       (setq ptr (* width j))
       (do ((i offx (+ i step)))
           ((>= i width))
         (push (+ i ptr) ret)))
     (nreverse ret)
     ))
  (:step
   (step &key (fixsize) (create))
   (let* ((offx (floor (/ (mod (1- width) step) 2.0)))
          (offy (floor (/ (mod (1- height) step) 2.0)))
          (nw (/ (1+ (- width offx)) step))
          (nh (/ (1+ (- height offy)) step)))
     (let ((step-idx (send self :step-inlier step offx offy)))
       (cond
        (fixsize
         ;; not implimented
         )
        (t
         (let ((ret (send self :filter-with-indices step-idx :create create)))
           (send ret :size)
           (send ret :size-change nw nh)
           ret)))
       )))
  ;;(:remove-outlier ())
  (:copy-from (pc)
   (send self :points (send pc :points))
   (send self :colors (send pc :colors))
   (send self :normals (send pc :normals))
   (send self :reset-coords)
   (send self :transform (send pc :worldcoords))
   (setq view-coords (send (pc . view-coords) :copy-worldcoords))
   (send self :worldcoords)
   self)
  (:transform-points
   (coords &key (create))
   (let ((ret (if create (instance pointcloud :init) self)))
     (if create (send ret :copy-from self))
     (send (ret . view-coords) :transform
           (send coords :worldcoords) :world)
     ;; transform pts
     (let ((mat (send ret :points)))
       (c-coords-transform-vector
        (send coords :worldpos)
        (send coords :worldrot)
        mat mat))
     (when (send ret :normals)
       ;; rotate normals
       (let ((mat (send ret :normals)))
         (c-coords-transform-vector
          (float-vector 0 0 0)
          (send coords :worldrot)
          mat mat)))
     ret))
  (:convert-to-world (&key (create))
   (prog1
       (send self :transform-points (send self :worldcoords) :create create)
     (unless create
       (send self :reset-coords)
       (send self :worldcoords))))
  ;; (:add-normal ())
  (:drawnormalmode (&optional mode)
   (case mode
     (:reset (setq drawnormalmode nil))
     (t (setq drawnormalmode mode)))
   drawnormalmode)
  (:transparent (&optional trs)
   (setq transparent trs)
   (when (and trs carray)
     (let ((size (send self :size)))
       (setq tcarray (make-matrix size 4))
       (dotimes (i size)
         (setf (matrix-row tcarray i)
               (concatenate float-vector (matrix-row carray i) (list trs))))))
   trs)
  (:draw (vwer)
   (when transparent
     (gl::glDepthMask gl::GL_FALSE)
     (gl::glEnable gl::GL_BLEND)
     (gl::glBlendFunc gl::GL_SRC_ALPHA gl::GL_ONE_MINUS_SRC_ALPHA))

   (gl::glPushAttrib gl::GL_ALL_ATTRIB_BITS)
   (if vwer (send vwer :viewsurface :makecurrent))
   (gl::glDisable gl::GL_LIGHTING)

   (gl::glpushmatrix)
   (gl::glmultmatrixf (array-entity (transpose (send worldcoords :4x4) gl::*temp-matrix*)))
    ;; draw coords
   (when (> asize 0.1)
     (gl::glLineWidth (float awidth))
     (gl::glBegin gl::GL_LINES)
     (gl::glColor3fv (float-vector 1 0 0))
     (gl::glVertex3fv (float-vector 0 0 0))
     (gl::glVertex3fv (float-vector asize 0 0))
     (gl::glColor3fv (float-vector 0 1 0))
     (gl::glVertex3fv (float-vector 0 0 0))
     (gl::glVertex3fv (float-vector 0 asize 0))
     (gl::glColor3fv (float-vector 0 0 1))
     (gl::glVertex3fv (float-vector 0 0 0))
     (gl::glVertex3fv (float-vector 0 0 asize))
     (gl::glEnd))

   ;; draw features
   (gl::glPointSize (float psize))

   (when (/= (send self :size) 0)
     ;; check carray
     (let ((tmp-color carray))
       (cond
        ((vectorp pcolor) (setq tmp-color nil) (gl::glColor3fv pcolor))
        ((member pcolor (list :rainbow :rainbow-x :rainbow-y :rainbow-z))
         (let (idx)
           (case pcolor
             ((:rainbow :rainbow-z) (setq idx 2))
             (:rainbow-x (setq idx 0))
             (:rainbow-y (setq idx 1)))
           (setq tmp-color (copy-matrix parray))
           (let ((carray-entity (array-entity tmp-color))
                 (v (float-vector 0 0 0))
                 min range)
             (setq min (elt (send (send self :box) :minpoint) idx)
                   range (- (elt (send (send self :box) :maxpoint) idx) min))
             (dotimes (i (array-dimension tmp-color 0))
               (replace carray-entity
                        (normalize-vector
                         (his2rgb
                          (* -280 (/ (- (aref parray i idx) min) range))
                          1.0 1.0 v) v) :start1 (* i 3)))))))

       (gl::glEnableClientState gl::GL_VERTEX_ARRAY)
       (if tmp-color (gl::glEnableClientState gl::GL_COLOR_ARRAY))
       #-:x86_64
       (if tmp-color
           (gl::glColorPointer (if transparent 4 3)
                               gl::GL_FLOAT 0 (array-entity (if transparent tcarray tmp-color))))
       #+:x86_64
       (if tmp-color
           (gl::glColorPointer (if transparent 4 3)
                               gl::GL_DOUBLE 0 (array-entity (if transparent tcarray tmp-color))))
       #-:x86_64
       (gl::glVertexPointer 3 gl::GL_FLOAT 0 (array-entity parray))
       #+:x86_64
       (gl::glVertexPointer 3 gl::GL_DOUBLE 0 (array-entity parray))
       (gl::glDrawArrays gl::GL_POINTS 0 (array-dimension parray 0))
       (gl::glDisableClientState gl::GL_VERTEX_ARRAY)
       (if tmp-color (gl::glDisableClientState gl::GL_COLOR_ARRAY))

       ;; draw normal
       (when (and narray drawnormalmode)
         (let ((tmp (float-vector 0 0 0))
               (p (float-vector 0 0 0))
               (n (float-vector 0 0 0))
               (c (float-vector 0 0 0)))
           (gl::glBegin gl::GL_LINES)
           (unless tmp-color
             (setq c pcolor))
           (dotimes (i (array-dimension narray 0))
             (c-matrix-row narray i n)
             (cond
              ((< (norm n) 0.1)
               (gl::glColor3fv #f(1 1 1))
               (dolist (o (list #f(0 0 -1) #f(0 0 1)
                                #f(0 -1 0) #f(0 1 0)
                                #f(-1 0 0) #f(1 0 0)))
                 #|(gl::glVertex3fv (matrix-row parray i))
                 (gl::glVertex3fv (v+ (matrix-row parray i) o tmp))|#
                 (c-matrix-row parray i p)
                 (gl::glVertex3fv p)
                 (gl::glVertex3fv (v+ p o p))
                 ))
              (t
               ;;(setq c (if tmp-color (matrix-row tmp-color i) pcolor))
               (if tmp-color (c-matrix-row tmp-color i c))
               (case
                   drawnormalmode
                 (:normal
                  (if (= (elt c 0) (elt c 1) (elt c  2))
                      (gl::glColor3fv c)
                    (gl::glColor3fv #f(0 0 1))))
                 (:normal-mono
                  (gl::glColor3f #f(0.8 0.8 0.8)))
                 (t
                  (gl::glColor3fv c)))
               #|
               (gl::glVertex3fv (matrix-row parray i))
               (gl::glVertex3fv (v+ (matrix-row parray i)
               (scale 10.0 (matrix-row narray i) tmp) tmp))
               |#
               (c-matrix-row parray i p)
               ;;(c-matrix-row narray i n)
               (gl::glVertex3fv p)
               (gl::glVertex3fv (v+ p (scale 10.0 n n) p))
               )))
           (gl::glEnd)))
       ))

   (gl::glpopmatrix)
   (gl::glEnable gl::GL_LIGHTING)
   (gl::glPopAttrib)
   (when transparent
     (gl::glDepthMask gl::GL_TRUE)
     (gl::glDisable gl::GL_BLEND)))
  )
(in-package "GEOMETRY")

(provide :irtpointcloud "$Id: $")
;;
;; test
;;
#|
(defun pointcloud-data ()
  (setq m (make-matrix 1000 3))
  (setq c (make-matrix 1000 3))
  (dotimes (i 1000)
    (setf (matrix-row m i) (scale 1000 (random-vector)))
    (setf (matrix-row c i)  (v+ (random-vector) #f(0.5 0.5 0.5))))
  (instance pointcloud :init :points m :colors c))
|#