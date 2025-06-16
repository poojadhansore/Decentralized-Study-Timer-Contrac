
;; Decentralized Study Timer Contract
;; Users can log their daily study time on-chain

(define-map study-sessions
  { user: principal, day: uint }
  { minutes: uint })

;; Function 1: Log study session for a specific day
(define-public (log-study (day uint) (minutes uint))
  (begin
    (map-set study-sessions { user: tx-sender, day: day }
             { minutes: minutes })
    (ok true)))

;; Function 2: Get study session by user and day
(define-read-only (get-study (user principal) (day uint))
  (ok (map-get? study-sessions { user: user, day: day })))
