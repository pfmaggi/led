
(define-library (led eval)
   (import
      (owl base)
      (led log)
      (led buffer)
      (only (led subprocess) start-repl)
      (led parse)
      (owl parse)
      (led env)
      (owl readline)
      )
   
   (export
      led-eval   ;; buff env exp -> buff' env' | #f env' (with error message)
      led-eval-runes
      led-repl   ;; maybe move elsewhere later
      
      push-undo
      pop-undo)

   (begin      

      (define (led-eval-position buff env exp)
         ;(print "evaling position " exp)
         (if (number? exp)
            exp
            (begin
               (log "unknown position " exp)
               #f)))

      (define (push-undo env delta)
         (-> env
            (put 'redo null) ;; destroy future of alternative past
            (put 'undo (cons delta (get env 'undo null)))))

      (define (pop-undo env)
         (let ((stack (get env 'undo null)))
            (if (null? stack)
               (values env #false)
               (values
                  (-> env
                     (put 'undo (cdr stack))
                     (put 'redo (cons (car stack) (get env 'redo null))))
                  (car stack)))))

      (define (pop-redo env)
         (let ((stack (get env 'redo null)))
            (if (null? stack)
               (values env #false)
               (values
                  (-> env
                     (put 'redo (cdr stack))
                     (put 'undo (cons (car stack) (get env 'undo null))))
                  (car stack)))))

      (define (led-eval buff env exp)
         (log "led-eval " exp)
         (tuple-case exp
            ((write-buffer target)
               (lets ((path (or target (get env 'path)))
                      (fd (and path (open-output-file path))))
                  (log "Writing buffer to " path)
                  (if fd
                     (let ((data (buffer->bytes buff)))
                        (if (write-bytes fd data)
                           (values buff
                              (set-status-text
                                 (put env 'path path)
                                 (str "Wrote " (length data) "b to " path ".")))
                           (values #f
                              (set-status-text env (str "Failed to write to " path ".")))))
                     (values #f (set-status-text env "Failed to open file for writing")))))
            ((new-buffer path)
               (mail 'ui (tuple 'open path))
               (values buff env))
            ((append text)
               (lets
                  ((buff (seek-delta buff (buffer-selection-length buff)))
                   (buff (buffer-unselect buff)))
                  (led-eval buff env (tuple 'insert text))))
            ((select-line n)
               (values
                  (select-line buff n)
                  env))
            ((subprocess call)
               (let ((info (start-repl call)))
                  (log " => call " call)
                  (log " => subprocess " info)
                  (if info
                     (values buff 
                        (set-status-text 
                           (put env 'subprocess info)
                           (str "Started " info)))
                     (values buff 
                        (set-status-text env "no")))))
            ((extend-selection movement)
               (lets ((buffp envp (led-eval buff env movement)))
                  (if buffp
                     (values
                        (merge-selections buff buffp)
                        envp)
                     (values #f #f))))
            ((replace new)
               (lets ((delta (tuple (buffer-pos buff) (get-selection buff) new)))
                  (values
                     (apply-delta buff delta)
                     (push-undo env delta))))
            ((delete)
               (led-eval buff env (tuple 'replace null)))
            ((undo)
               (lets ((env delta (pop-undo env)))
                  (if delta
                     (values (unapply-delta buff delta) env)
                     (values buff
                        (set-status-text env "nothing to undo")))))
            ((redo)
               (lets ((env delta (pop-redo env)))
                  (if delta
                     (values (apply-delta buff delta) env)
                     (values buff
                        (set-status-text env "nothing to redo")))))
            ((print)
               (let ((data (get-selection buff)))
                  (print (runes->string data))
                  (values buff env)))
            (else
               (log (list 'wat-eval exp))
               (values #f #f))))

      ;;; Line-based operation

      (define (led-eval-runes buff env s)
         (let ((exp (parse-runes s)))
            (log "eval " s " -> " exp)
            (if exp
               (lets ((buffp envp (led-eval buff env exp)))
                  (if buffp
                     (values buffp envp)
                     (begin
                        (set-status-text env "no")
                        (values buff env))))
               (values buff 
                  (set-status-text env "syntax error")))))

      (define (led-repl buff env)
         (display "> ")
         (lfold
            (λ (buff-env exp)
               (lets ((buff env buff-env)
                      (buff env (led-eval buff env exp)))
                  (if buff
                     (begin
                        ;(print (buffer->string buff))
                        ;(print-buffer buff)
                        (display "> ")
                        (cons buff env))
                     (begin
                        (print "?")
                        buff-env))))
            (cons buff env)
            (byte-stream->exp-stream
               (port->readline-byte-stream stdin)
               get-command
               led-syntax-error-handler)))

))

