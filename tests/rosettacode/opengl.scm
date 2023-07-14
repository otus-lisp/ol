; http://www.rosettacode.org/wiki/OpenGL
(import (lib gl))
(gl:set-window-title "Rosettacode OpenGL example")

(import (OpenGL 1.0))

(glShadeModel GL_SMOOTH)
(glClearColor 0.3 0.3 0.3 1)
(glMatrixMode GL_PROJECTION)
(glLoadIdentity)
(glOrtho -30.0 30.0 -30.0 30.0 -30.0 30.0)

(gl:set-renderer (lambda (mouse)
   (glMatrixMode GL_MODELVIEW)
   (glLoadIdentity)
   (glTranslatef -15.0 -15.0 0.0)
 
   (glBegin GL_TRIANGLES)
      (glColor3f 1.0 0.0 0.0)
      (glVertex2f 0.0 0.0)
      (glColor3f 0.0 1.0 0.0)
      (glVertex2f 30.0 0.0)
      (glColor3f 0.0 0.0 1.0)
      (glVertex2f 0.0 30.0)
   (glEnd)
))
